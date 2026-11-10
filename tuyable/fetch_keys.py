# /// script
# dependencies = ["tuya-device-sharing-sdk", "cryptography", "qrcode"]
# ///
"""One-time: log in via Smart Life QR, dump BLE credentials to ~/.config/tuyable/devices.json."""
import json, os, sys, time
from pathlib import Path
import qrcode
from tuya_sharing import LoginControl, Manager

# Public client id/schema used by Home Assistant's Tuya integration.
CLIENT_ID, SCHEMA = "HA_3y9q4ak7g4ephrvke", "haauthorize"
OUT = Path.home() / ".config/tuyable/devices.json"

TOKEN = OUT.parent / "token.json"
user_code = sys.argv[1] if len(sys.argv) > 1 else input("Smart Life user code: ").strip()
login = LoginControl()
r = login.qr_code(CLIENT_ID, SCHEMA, user_code)
if not r.get("success"):
    sys.exit(f"QR request failed: {r}")
token = r["result"]["qrcode"]

qr = qrcode.QRCode(border=1)
qr.add_data(f"tuyaSmart--qrLogin?token={token}")
qr.print_ascii(invert=True)
print("Scan with Smart Life app (+ → scan icon), then confirm login. Waiting...")

for _ in range(120):
    ok, info = login.login_result(token, CLIENT_ID, user_code)
    if ok:
        break
    time.sleep(2)
else:
    sys.exit(f"Timed out waiting for scan: {info}")

TOKEN.parent.mkdir(parents=True, exist_ok=True)
TOKEN.write_text(json.dumps({"user_code": user_code, **info}))
os.chmod(TOKEN, 0o600)
m = Manager(CLIENT_ID, user_code, info["terminal_id"], info["endpoint"], info)
m.update_device_cache()
devices = [
    {
        "name": d.name, "id": d.id, "uuid": d.uuid, "local_key": d.local_key,
        "category": d.category, "product_id": d.product_id, "product_name": d.product_name,
        "status": d.status,
        "dps": {str(k): v["status_code"] for k, v in (d.local_strategy or {}).items()},
        "raw": {k: v for k, v in vars(d).items() if k not in ("function", "status_range", "local_strategy", "status")},
    }
    for d in m.device_map.values()
]
OUT.parent.mkdir(parents=True, exist_ok=True)
OUT.write_text(json.dumps(devices, indent=2))
os.chmod(OUT, 0o600)
for d in devices:
    print(f"{d['name']}: category={d['category']} uuid={d['uuid']} dps={d['dps']}")
print(f"Saved {len(devices)} device(s) to {OUT}")
