#!/usr/bin/env python3
"""Blink the desk lamp to show what Claude Code is doing, then put it back how it was.

usage: lamp-signal.py ask|done|error     (run from Claude Code hooks)
       lamp-signal.py selftest

Does nothing if the lamp is off (you're away or asleep) or unreachable, or for headless
`claude -p` runs. Overlapping signals from several sessions queue up. LAMP_URL overrides the server (the tuyable app on the Pi).
"""
import fcntl, json, os, sys, time, urllib.request

URL = os.environ.get("LAMP_URL", "http://192.168.1.20:8080")
SIGNALS = {"ask": (35, 3), "done": (120, 2), "error": (0, 3)}  # hue, blinks: amber, green, red
ON_S, OFF_S = 0.4, 0.3  # seconds in the colour, seconds back to normal; tune if the bulb lags


def api(path, body=None):
    req = urllib.request.Request(URL + path, body and json.dumps(body).encode(),
                                 {"content-type": "application/json"})
    with urllib.request.urlopen(req, timeout=3) as r:
        return json.load(r)


def restore_body(s):
    if s["color"]:
        return {"mode": "color", "h": s["h"], "s": s["s"], "v": s["v"]}
    return {"mode": "white", "b": s["white"], "t": s["temp"]}


def blink(kind):
    if os.environ.get("CLAUDE_CODE_ENTRYPOINT", "").startswith("sdk"):
        return  # headless `claude -p` jobs (e.g. Hermes' mac_claude.sh) shouldn't flash the room
    hue, times = SIGNALS[kind]
    lock = open("/tmp/claude-lamp-signal.lock", "w")
    fcntl.flock(lock, fcntl.LOCK_EX)  # queue behind another session's blink rather than drop it
    try:
        s = api("/api/state")
    except Exception:
        return
    if not s["on"] or s["error"]:
        return
    back = restore_body(s)
    try:
        for _ in range(times):
            api("/api/set", {"mode": "color", "h": hue, "s": 100, "v": 100})
            time.sleep(ON_S)
            api("/api/set", back)
            time.sleep(OFF_S)
    except Exception:
        try:
            api("/api/set", back)  # never leave it stuck on a signal colour
        except Exception:
            pass


def selftest():
    white = {"on": True, "color": False, "white": 43, "temp": 37, "h": 32, "s": 100, "v": 45}
    assert restore_body(white) == {"mode": "white", "b": 43, "t": 37}
    assert restore_body({**white, "color": True}) == {"mode": "color", "h": 32, "s": 100, "v": 45}
    print("selftest ok")


if __name__ == "__main__":
    arg = sys.argv[1] if len(sys.argv) > 1 else ""
    selftest() if arg == "selftest" else blink(arg) if arg in SIGNALS else sys.exit(__doc__)
