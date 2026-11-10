# /// script
# dependencies = ["bleak", "cryptography"]
# ///
"""Local Tuya BLE (FD50, protocol 4.x) bulb control. No cloud, no app.

usage: bulb on|off|status|probe
       bulb white BRIGHT% [TEMP%]     (TEMP: 0=warm, 100=cool)
       bulb color RRGGBB [BRIGHT%]
"""
import asyncio, colorsys, hashlib, json, os, struct, sys
from pathlib import Path
from bleak import BleakClient, BleakScanner
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes

SERVICE = "0000fd50-0000-1000-8000-00805f9b34fb"
WRITE = "00000001-0000-1001-8001-00805f9b07d0"
NOTIFY = "00000002-0000-1001-8001-00805f9b07d0"
CONFIG = Path.home() / ".config/tuyable/devices.json"
DEBUG = bool(os.environ.get("BULB_DEBUG"))
OP_INFO, OP_PAIR, OP_STATUS, OP_DPS, OP_REPORT = 0x00, 0x01, 0x03, 0x27, 0x8006
BOOL, VALUE, STRING, ENUM = 1, 2, 3, 4


def crc16(data):
    crc = 0xFFFF
    for b in data:
        crc ^= b
        for _ in range(8):
            crc = (crc >> 1) ^ (0xA001 if crc & 1 else 0)
    return crc


def varint(n):
    out = bytearray()
    while True:
        out.append((n & 0x7F) | (0x80 if n > 0x7F else 0))
        n >>= 7
        if not n:
            return bytes(out)


def read_varint(data, pos):
    n = shift = 0
    while True:
        b = data[pos]; pos += 1
        n |= (b & 0x7F) << shift; shift += 7
        if not b & 0x80:
            return n, pos


def aes(data, key, iv, encrypt):
    c = Cipher(algorithms.AES(key), modes.CBC(iv))
    op = c.encryptor() if encrypt else c.decryptor()
    return op.update(data) + op.finalize()


def frame(serial, ack, opcode, payload, mode, key):
    """Encode one application message into 20-byte GATT fragments."""
    body = struct.pack(">IIHH", serial, ack, opcode, len(payload)) + payload
    body += struct.pack(">H", crc16(body))
    if mode == 0:
        env = b"\0" + body
    else:
        body += bytes(-len(body) % 16)
        iv = os.urandom(16)
        env = bytes([mode]) + iv + aes(body, key, iv, True)
    packets, off = [], 0
    while off < len(env):
        head = varint(len(packets))
        if not packets:
            head += varint(len(env)) + bytes([0x20 | ((serial - 1) & 15)])
        take = 20 - len(head)
        packets.append(head + env[off:off + take])
        off += take
    return packets


def unframe(env, keys):
    """Decode an envelope -> (serial, ack, opcode, payload)."""
    mode = env[0]
    body = env[1:] if mode == 0 else aes(env[17:], keys[mode], env[1:17], False)
    serial, ack, opcode, n = struct.unpack(">IIHH", body[:12])
    if crc16(body[:12 + n]) != int.from_bytes(body[12 + n:14 + n], "big"):
        raise ValueError(f"CRC mismatch (mode {mode}) — wrong local_key?")
    return serial, ack, opcode, body[12:12 + n]


def parse_dps(payload):
    """V4 report: 0, seq:u32, type, flag, then records id:u8 type:u8 len:u16 data."""
    out, pos = {}, 7
    while pos + 4 <= len(payload):
        dp, kind, n = payload[pos], payload[pos + 1], int.from_bytes(payload[pos + 2:pos + 4], "big")
        raw = payload[pos + 4:pos + 4 + n]; pos += 4 + n
        out[dp] = (bool(raw[0]) if kind == BOOL else raw.decode() if kind == STRING
                   else int.from_bytes(raw, "big", signed=True) if kind in (VALUE, ENUM) else raw.hex())
    return out


class Bulb:
    def __init__(self, cred=None):
        self.cred, self.serial, self.dp_seq = cred, 1, 1
        self.keys, self.state = {}, {}
        self.buf, self.want, self.inbox = b"", 0, asyncio.Queue()
        if cred:
            self._lk = cred["local_key"].encode()
            self._sk = cred["sec_key"].encode()
            self.keys[14] = hashlib.md5(self._lk + self._sk).digest()  # md5(localKey+secKey)

    async def __aenter__(self):
        dev = await BleakScanner.find_device_by_filter(
            lambda d, ad: SERVICE in ad.service_uuids, timeout=15)
        if not dev:
            sys.exit("Bulb not found. Powered on? Phone app closed?")
        self.client = BleakClient(dev, timeout=20)
        await self.client.connect()
        await self.client.start_notify(NOTIFY, self._notify)
        return self

    async def __aexit__(self, *_):
        await self.client.disconnect()

    def _notify(self, _, data):
        data = bytes(data)
        if DEBUG:
            print(f"  raw <- {data.hex()}", file=sys.stderr)
        idx, pos = read_varint(data, 0)
        if idx == 0:
            self.want, pos = read_varint(data, pos)
            self.buf, pos = b"", pos + 1
        self.buf += data[pos:]
        if len(self.buf) >= self.want:
            self.inbox.put_nowait(self.buf)

    async def send(self, opcode, payload, mode, ack=0):
        serial = self.serial; self.serial += 1
        for p in frame(serial, ack, opcode, payload, mode, self.keys.get(mode)):
            await self.client.write_gatt_char(WRITE, p, response=True)
        return serial

    async def request(self, opcode, payload, mode, timeout=10):
        """Send and wait for the matching response, servicing reports meanwhile."""
        serial = await self.send(opcode, payload, mode)
        async with asyncio.timeout(timeout):
            while True:
                env = await self.inbox.get()
                s, ack, op, p = unframe(env, self.keys)
                if DEBUG:
                    print(f"  <- mode={env[0]} serial={s} ack={ack} op={op:#06x} {p.hex()}", file=sys.stderr)
                if op == OP_REPORT and ack == 0:
                    self.state.update(parse_dps(p))
                    if not p[5] & 0x80:
                        await self.send(OP_REPORT, p[:7] + b"\0", 15, ack=s)
                elif ack == serial:
                    return p

    async def connect(self):
        # device-info under mode 14 = md5(lk+sk); reply carries the 6-byte nonce
        info = await self.request(OP_INFO, b"\x00\x14", 14)
        nonce = info[6:12]
        self.keys[15] = hashlib.md5(self._lk + self._sk + nonce).digest()
        # no PAIR: this firmware drops the link on opcode-1; mode-15 session is implicit

    async def refresh(self):
        await self.request(OP_STATUS, b"", 15)
        await asyncio.sleep(0.5)  # reports trail the ack
        while not self.inbox.empty():
            s, ack, op, p = unframe(self.inbox.get_nowait(), self.keys)
            if op == OP_REPORT:
                self.state.update(parse_dps(p))

    async def set(self, *dps):
        """dps: (id, type, value). Order matters: data before mode."""
        payload = b"\0" + struct.pack(">I", self.dp_seq); self.dp_seq += 1
        for dp, kind, v in dps:
            raw = (bytes([v]) if kind in (BOOL, ENUM) else struct.pack(">i", v) if kind == VALUE else v.encode())
            payload += struct.pack(">BBH", dp, kind, len(raw)) + raw
        r = await self.request(OP_DPS, payload, 15)
        if r[-1] != 0:
            sys.exit(f"Bulb rejected command (status {r[-1]})")


def load_cred():
    try:
        devs = json.loads(CONFIG.read_text())
    except FileNotFoundError:
        sys.exit(f"No credentials at {CONFIG}. Run fetch_keys.py first.")
    # ponytail: picks the single light; add a name arg when there's a second bulb
    lights = [d for d in devs if d["category"] == "dj"] or devs
    return lights[0]


def pct(s, lo=0, hi=1000):
    return lo + round(max(0, min(100, int(s))) * (hi - lo) / 100)


def color_str(hexrgb, v):
    r, g, b = (int(hexrgb.lstrip("#")[i:i + 2], 16) / 255 for i in (0, 2, 4))
    h, s, _ = colorsys.rgb_to_hsv(r, g, b)
    return f"{round(h * 360):04x}{round(s * 1000):04x}{v:04x}"


async def main(argv):
    cmd, args = (argv[0] if argv else "status"), argv[1:]
    if cmd == "probe":  # unauthenticated: proves transport works before keys exist
        async with Bulb() as b:
            p = await b.request(OP_INFO, b"\x00\x14", 0)
            print(f"protocol {p[2]}.{p[3]}, bound={bool(p[5])}, fw {'.'.join(map(str, p[46:49]))}")
        return
    async with Bulb(load_cred()) as b:
        await b.connect()
        if cmd in ("on", "off"):
            await b.set((20, BOOL, cmd == "on"))
        elif cmd == "white":
            dps = [(22, VALUE, pct(args[0], 10))]
            if len(args) > 1:
                dps.append((23, VALUE, pct(args[1])))
            await b.set(*dps, (21, ENUM, 0), (20, BOOL, True))
        elif cmd == "color":
            v = pct(args[1], 10) if len(args) > 1 else 1000
            await b.set((24, STRING, color_str(args[0], v)), (21, ENUM, 1), (20, BOOL, True))
        elif cmd != "status":
            sys.exit(__doc__)
        await b.refresh()
        print(json.dumps(b.state))


def selftest():
    assert crc16(b"123456789") == 0x4B37  # CRC-16/MODBUS check value
    assert read_varint(varint(300), 0) == (300, 2)
    key = bytes(range(16))
    pkts = frame(7, 0, OP_DPS, b"hello world, this spans fragments", 5, key)
    assert all(len(p) <= 20 for p in pkts) and len(pkts) > 1
    env, pos = b"", 0
    for i, p in enumerate(pkts):
        _, pos = read_varint(p, 0)
        if i == 0:
            _, pos = read_varint(p, pos); pos += 1
        env += p[pos:]
    assert unframe(env, {5: key}) == (7, 0, OP_DPS, b"hello world, this spans fragments")
    assert color_str("ff0000", 1000) == "000003e803e8"
    rep = b"\0" + struct.pack(">I", 5) + b"\0\0" + bytes([20, 1, 0, 1, 1, 22, 2, 0, 4]) + struct.pack(">i", 500)
    assert parse_dps(rep) == {20: True, 22: 500}
    print("selftest ok")


if __name__ == "__main__":
    selftest() if sys.argv[1:] == ["selftest"] else asyncio.run(main(sys.argv[1:]))
