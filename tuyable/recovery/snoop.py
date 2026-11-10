# /// script
# dependencies = ["bleak", "cryptography"]
# ///
"""Extract localKey/secKey from an Android btsnoop_hci.log of a Smart Life (re-)pairing.

usage: snoop.py btsnoop_hci.log | snoop.py selftest
"""
import hashlib, json, re, struct, sys
from collections import defaultdict
sys.path.insert(0, __import__("os").path.dirname(__file__))
from bulb import read_varint, unframe


def att_packets(path):
    """Yield (direction, att_opcode, att_handle, value) from btsnoop H4 log; reassembles L2CAP."""
    data = open(path, "rb").read()
    assert data[:8] == b"btsnoop\0", "not a btsnoop file"
    pos, partial = 16, {}
    while pos + 24 <= len(data):
        _, incl, flags, _, _ = struct.unpack(">IIIIq", data[pos:pos + 24])
        rec, pos = data[pos + 24:pos + 24 + incl], pos + 24 + incl
        if not rec or rec[0] != 0x02:  # H4 ACL only
            continue
        hdr, _ = struct.unpack("<HH", rec[1:5])
        conn, pb, body, d = hdr & 0xFFF, (hdr >> 12) & 3, rec[5:], "rx" if flags & 1 else "tx"
        if pb == 1:  # continuation
            if (conn, d) not in partial:
                continue
            partial[(conn, d)][1] += body
        else:
            partial[(conn, d)] = [struct.unpack("<H", body[:2])[0], body]
        need, buf = partial[(conn, d)]
        if len(buf) - 4 < need:
            continue
        del partial[(conn, d)]
        cid, att = struct.unpack("<H", buf[2:4])[0], buf[4:4 + need]
        if cid == 4 and att and att[0] in (0x12, 0x52, 0x1B, 0x1D):
            yield d, att[0], struct.unpack("<H", att[1:3])[0], att[3:]


def envelopes(path):
    """Reassemble Tuya transport fragments per (direction, handle)."""
    state = defaultdict(lambda: [b"", 0])
    for d, _, handle, v in att_packets(path):
        try:
            idx, p = read_varint(v, 0)
            st = state[(d, handle)]
            if idx == 0:
                st[1], p = read_varint(v, p)
                st[0], p = b"", p + 1
            st[0] += v[p:]
            if st[1] and len(st[0]) == st[1]:
                yield d, st[0]
                st[:] = [b"", 0]
        except IndexError:
            pass


def extract(path):
    envs = list(envelopes(path))
    print(f"{len(envs)} Tuya frames, modes: {sorted({e[0] for _, e in envs})}")
    nonces = []
    for d, e in envs:
        if e[0] == 0:
            try:
                _, _, op, p = unframe(e, {})
                if op == 0 and d == "rx" and len(p) >= 12:
                    nonces.append(p[6:12])
            except Exception:
                pass
    found = None
    for nonce in nonces:
        key = hashlib.md5(bytes(16) + nonce).digest()
        for d, e in envs:
            if e[0] != 12:
                continue
            try:
                _, _, op, p = unframe(e, {12: key})
            except Exception:
                continue
            m = re.search(rb"\{.*\}", p)
            if op == 27 and m:
                found = json.loads(m.group())
    if not found:
        sys.exit(f"No activation found ({len(nonces)} plaintext nonces). Snoop log mode must be 'Enabled', not 'Filtered'.")
    return found


def selftest():
    import os, tempfile
    from bulb import frame
    nonce = os.urandom(6)
    info = bytes([4, 8, 4, 8, 0, 0]) + nonce + bytes(84)
    act = json.dumps({"devId": "x" * 22, "localKey": "L" * 16, "secKey": "S" * 16}).encode()
    act = b"\x00" + bytes([len(act)]) + b"\x20" + act
    out = b"btsnoop\0" + struct.pack(">II", 1, 1002)

    def rec(direction, att):
        l2 = struct.pack("<HH", len(att), 4) + att
        first, rest = l2[:27], l2[27:]  # force ACL fragmentation
        recs = [(0x2001, first)] + [(0x1001, rest)] if rest else [(0x2001, first)]
        return b"".join(struct.pack(">IIIIq", 5 + len(b), 5 + len(b), direction, 0, 0)
                        + b"\x02" + struct.pack("<HH", h, len(b)) + b for h, b in recs)

    for p in frame(1, 1, 0, info, 0, None):
        out += rec(1, b"\x1b\x10\x00" + p)
    for p in frame(3, 0, 27, act, 12, hashlib.md5(bytes(16) + nonce).digest()):
        out += rec(0, b"\x52\x0e\x00" + p)
    f = tempfile.NamedTemporaryFile(delete=False, suffix=".log")
    f.write(out); f.close()
    assert extract(f.name)["secKey"] == "S" * 16
    print("selftest ok")


if __name__ == "__main__":
    if sys.argv[1:] == ["selftest"]:
        selftest()
    else:
        r = extract(sys.argv[1])
        print("devId", r.get("devId"), "| localKey/secKey lengths:", len(r.get("localKey", "")), len(r.get("secKey", "")))
        from pathlib import Path
        cfg = Path.home() / ".config/tuyable/devices.json"
        devs = json.loads(cfg.read_text())
        devs[0].update(local_key=r["localKey"], sec_key=r["secKey"], id=r.get("devId", devs[0]["id"]))
        cfg.write_text(json.dumps(devs, indent=2))
        print(f"Saved keys to {cfg}")
