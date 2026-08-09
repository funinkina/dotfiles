#!/usr/bin/env python3
"""Event-driven privacy monitor.

Subscribes to the PipeWire registry (pw-dump -m, push events — no polling)
and emits a JSON line whenever camera / microphone usage changes:
{"mic": bool, "cam": bool}
(Screencasts are detected via niri IPC in NiriService, not here.)

Classification (state == "running" only):
  Stream/Input/Audio            -> microphone capture
  Video/Source with v4l2 props  -> camera device streaming
"""
import json
import subprocess
import sys

DEBUG = "--debug" in sys.argv


def dbg(*a):
    if DEBUG:
        print(*a, file=sys.stderr, flush=True)

nodes = {}  # id -> {"mc": media.class, "state": str, "blob": lowercased props}


def status():
    mic = cam = False
    for n in nodes.values():
        if n["state"] != "running":
            continue
        if n["mc"] == "Stream/Input/Audio":
            mic = True
        elif n["mc"] == "Video/Source" and (
                "v4l2" in n["blob"] or "libcamera" in n["blob"]):
            cam = True
    return {"mic": mic, "cam": cam}


def handle(o):
    oid = o.get("id")
    if oid is None:
        return
    if o.get("info") is None:
        nodes.pop(oid, None)
        return
    if o.get("type") != "PipeWire:Interface:Node":
        return
    # Updates are partial (change-mask): merge, don't replace
    info = o["info"]
    entry = nodes.setdefault(oid, {"mc": "", "state": "", "blob": ""})
    if "state" in info:
        entry["state"] = info["state"]
    props = info.get("props")
    if props:
        entry["mc"] = props.get("media.class", entry["mc"])
        entry["blob"] = json.dumps(props).lower()


# stdbuf: pw-dump block-buffers when piped, which would delay events
proc = subprocess.Popen(["stdbuf", "-oL", "pw-dump", "-m"],
                        stdout=subprocess.PIPE, text=True)
buf = ""
prev = None
for line in proc.stdout:
    buf += line
    # Chunks are pretty-printed arrays; the top-level close is "]" at col 0.
    # Only attempt a parse there — parsing per line is O(n^2).
    if line.rstrip() != "]":
        continue
    try:
        arr = json.loads(buf)
    except ValueError:
        continue
    buf = ""
    dbg("chunk:", len(arr), "objects")
    for o in arr:
        handle(o)
        if DEBUG and isinstance(o, dict) and o.get("type", "").endswith("Node") and o.get("info"):
            e = nodes.get(o.get("id"))
            if e and ("Input" in e["mc"] or e["state"] == "running"):
                dbg("  node", o.get("id"), e["mc"], e["state"])
    cur = status()
    if cur != prev:
        print(json.dumps(cur), flush=True)
        prev = cur
