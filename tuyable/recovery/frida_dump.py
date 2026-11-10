# /// script
# dependencies = ["frida"]
# ///
import frida, sys, time

seen = set()
def on_message(msg, _):
    if msg["type"] != "send":
        print("ERR", msg); return
    p = msg["payload"]
    if p.get("tag") == "ready":
        print("hook ready — now send an on/off from the Smart Life app", flush=True); return
    key = p["hex"]
    if key in seen:
        return
    seen.add(key)
    print(f"[{p['tag']}] len={p['len']} {p['txt']}", flush=True)
    print(f"    hex={p['hex']}", flush=True)
    if p["len"] in (38, 32):  # localKey(16)+secKey(16)[+srand(6)]
        b = bytes.fromhex(p["hex"])
        print(f"    >>> localKey={b[:16].decode()}  secKey={b[16:32].decode()}", flush=True)

dev = frida.get_usb_device()
pid = 7226
session = dev.attach(pid)
script = session.create_script(open("/tmp/tuyable/hook.js").read())
script.on("message", on_message)
script.load()
print("attached to com.tuya.smartlife, waiting for crypto...", flush=True)
sys.stdin.read()  # keep alive
