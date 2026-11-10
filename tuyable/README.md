# tuyable — local BLE control for a Tuya/Glamax bulb

App-free, cloud-free control of a Tuya BLE bulb (service `0xFD50`, protocol 4.8)
whose WiFi firmware is broken. Talks the encrypted Tuya BLE session directly.

## Daily use

```sh
uv run bulb.py on
uv run bulb.py off
uv run bulb.py white 60 20     # brightness %, temp % (0=warm 100=cool)
uv run bulb.py color ff8800 80 # hex RGB, brightness %
uv run bulb.py status
```

Credentials live in `~/.config/tuyable/devices.json` (chmod 600, **never** in this
repo). Each device entry needs `local_key` + `sec_key` (16 chars each), `uuid`, `id`.

## Protocol (what bulb.py implements)

- GATT: write `…0001-…07d0`, notify `…0002-…07d0`. 20-byte fragments, varint-indexed.
- App frame: `serial:u32 ack:u32 opcode:u16 len:u16 payload crc16/modbus`, AES-CBC,
  `mode:u8 + iv:16 + ciphertext`.
- Handshake: device-info (opcode 0) under **mode 14** = `md5(localKey+secKey)`.
  Reply carries a 6-byte nonce at `payload[6:12]`.
- Session: **mode 15** = `md5(localKey+secKey+nonce)` for all DP writes/reports.
  This firmware needs **no PAIR** (opcode 1 drops the link).
- DP writes: opcode `0x27`, payload `00 seq:u32 {id:u8 type:u8 len:u16 data}…`.
  DPs: 20 power(bool) 21 mode(enum 0=white 1=color) 22 bright(10..1000)
  23 temp(0..1000) 24 colour(HSV ascii-hex).

`uv run bulb.py selftest` checks CRC, framing round-trip, colour + report parsing.

## Key recovery (when the local_key rotates, i.e. after any re-pair)

`local_key` + `sec_key` only exist on the Tuya cloud / in the Smart Life app.
This firmware pairs with ECDH, so the keys are **not** sniffable from BLE.

**Cloud fetch (gets local_key + uuid, NOT sec_key):**
```sh
uv run fetch_keys.py <smartlife-user-code>   # scan QR in Smart Life
```

**sec_key** requires reading it out of the Smart Life app on a **rooted** phone
(see `recovery/`): run frida-server as root, open the device-list MMKV store, read
the device bean. The keys sit in `s_home_data_devlist…` →
`{localKey, secKey, uuid}`. Steps:
1. `adb push frida-server /data/local/tmp/ && su -c /data/local/tmp/frida-server -D`
2. `frida -U -p $(pidof com.tuya.smartlife) -l recovery/dump2.js` — but point it at
   store `preferences_global_key<uid>` key `s_home_data_devlist<uid>` and read the
   bean's `localKey`/`secKey` fields. (`recovery/hook.js` dumps MMKV reads live.)
3. Write both into `~/.config/tuyable/devices.json`.

`recovery/snoop.py` decodes an Android btsnoop HCI log — only useful on older
non-ECDH firmware that pairs with `md5(zeros+nonce)`; kept for reference.
