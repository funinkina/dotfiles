# Bulb control — handover

Everything needed to use the Glamax/Tuya bulb locally, and the full story of how
its Bluetooth protocol was reverse-engineered. Companion to `README.md` (quick
reference) and `recovery/` (the extraction scripts).

---

## 1. What this is

A **Glamax Bulb TW+RGB** (a white-labelled Tuya RGBWW bulb). Its WiFi firmware is
buggy — it refuses to join any new WiFi network — so the usual LAN/cloud control
is dead. The only live channel is **Bluetooth LE**, and the vendor app for that is
miserable. So we talk to the bulb's BLE protocol directly.

Result: `bulb.py` controls it from any machine with Bluetooth (Mac proven; the
`hermes` Pi set up as an always-on bridge).

| Fact | Value |
| --- | --- |
| Model | Glamax Bulb TW+RGB (Tuya OEM) |
| BLE name / MAC | `TUYA_` / `<bulb-mac>` |
| BLE service | `0000fd50-0000-1000-8000-00805f9b34fb` |
| GATT write / notify | `…0001-…07d0` / `…0002-…07d0` |
| Tuya protocol | 4.8 (FD50, AES + mode-15 session) |
| device id / uuid | `<device-id>` / `<uuid>` |
| product id | `<product-id>` |

---

## 2. How to use

Needs `uv` (handles the inline `bleak`/`cryptography` deps automatically).

```sh
cd ~/dotfiles/tuyable
uv run bulb.py on
uv run bulb.py off
uv run bulb.py status                # prints current datapoints as JSON
uv run bulb.py white 60 20           # brightness 60%, temp 20% (0=warm, 100=cool)
uv run bulb.py color ff8800 80       # hex RGB, brightness 80%
uv run bulb.py probe                 # no keys needed; just checks the BLE transport
uv run bulb.py selftest              # offline: CRC, framing, colour + report parsing
```

Set `BULB_DEBUG=1` to dump raw frames to stderr.

**From the Pi** (`hermes`), same tool, uv installed user-local:

```sh
ssh hermes '~/.local/bin/uv run -q ~/tuyable/bulb.py on'
```

### Credentials

Live in `~/.config/tuyable/devices.json`, chmod 600, **never committed**. One entry
needs `local_key` + `sec_key` (16 ASCII chars each), `uuid`, `id`. Same file on the
Mac and the Pi.

> ⚠️ Only **one** BLE central can hold the bulb at a time. If `bulb.py` says "Bulb
> not found", something else owns the link — usually the Smart Life app on a phone.
> Force-close it (`adb shell am force-stop com.tuya.smartlife`) or turn the phone's
> Bluetooth off. A single wall-switch power cycle also frees it (do **not** cycle
> 3× fast — that triggers pairing/reset mode and rotates the keys).

---

## 3. How it was reverse-engineered

### 3.1 Identify the device
A BLE scan showed `TUYA_` advertising service `0xFD50` with Tuya manufacturer id
`0x07D0`. Connecting revealed the newer FD50 GATT layout (`…07d0` characteristics),
i.e. **Tuya BLE protocol 4.x** — already documented by the open-source
`ha_tuya_ble` / `ShonP40/Tuya-BLE` projects and a near-identical bulb in
`samueljseay/bardi-ble-controller`. So the transport didn't need inventing, just
porting.

### 3.2 The transport (this is what `bulb.py` speaks)
- **GATT fragments:** writes are ≤20-byte packets. First fragment =
  `varint(index=0) · varint(total_len) · version_byte(0x20|seq) · data`; the rest
  are `varint(index) · data`. Notifications reassemble the same way.
- **Application frame:** big-endian `serial:u32 · ack:u32 · opcode:u16 · len:u16 ·
  payload · crc16/modbus:u16`, then zero-padded to 16 bytes and AES-CBC encrypted.
  Envelope on the wire = `mode:u8 · iv:16 · ciphertext`.
- **Opcodes:** `0x00` device-info, `0x27` datapoint write, `0x8006` datapoint
  report (device→us). `mode` selects which AES key.

### 3.3 The wall: you need two secret keys, and they're not sniffable
All real traffic is AES-encrypted under keys derived from the bulb's `local_key`
**and** `sec_key` — two independent 16-char secrets that live only in the Tuya
cloud / the Smart Life app.

Dead ends, in order:
1. **Cloud fetch** (`fetch_keys.py`, Smart Life QR login — the same API Home
   Assistant uses) yields `local_key` + `uuid`, but **not** `sec_key`.
2. **Sniffing the BLE pairing** (Android HCI snoop log, decoded by
   `recovery/snoop.py`) fails: this firmware pairs with an **ECDH** handshake
   (wire modes 16→11→12→15). The shared secret is derived from an ephemeral key
   pair whose private half never goes over the air, so `sec_key` is physically
   absent from the capture.
3. **Legacy localKey-only session** (mode 4/5 = `md5(local_key[:6]+nonce)`, which
   many older Tuya bulbs still accept): this bulb refuses it — every query comes
   back as a strict mode-15 frame we can't read without `sec_key`.

### 3.4 The win: pull the keys from the app on a rooted phone
`sec_key` exists in the Smart Life app (it decrypts the bulb's traffic to control
it). On a **rooted** phone:
1. Run `frida-server` as root; attach to `com.tuya.smartlife`.
2. The app stores its encrypted key-value data in a renamed MMKV
   (`com.thingclips.smart.mmkv.MMKV`). Its files are AES-encrypted at rest, but
   `MMKV.mmkvWithID(id)` returns the **already-decrypted live singleton**, so
   reading it through Frida bypasses the encryption entirely.
3. The device list is in store `preferences_global_key<uid>`, key
   `s_home_data_devlist<uid>` — a JSON array of device beans. The bean for our
   `devId` contains `localKey` and `secKey` in the clear.
   (`recovery/dump2.js` + `recovery/hook.js` are the Frida scripts; the general
   pattern is: open the store, `allKeys()`, `decodeString()` each.)
4. Write both keys into `~/.config/tuyable/devices.json`.

### 3.5 The handshake (what finally controlled the bulb)
Once both keys are known:
1. Connect, subscribe to notifications, **wait ~1 s** (this firmware drops traffic
   sent too early), and use **write-without-response**.
2. Send **device-info** (opcode 0, payload `00 14`) under **mode 14** key =
   `md5(local_key + sec_key)`. The reply decrypts cleanly — this is the proof both
   keys are correct — and carries a 6-byte **nonce** at `payload[6:12]`.
3. Derive the **mode-15 session key** = `md5(local_key + sec_key + nonce)`.
4. Send datapoint writes (opcode `0x27`) under mode 15. **No PAIR step** — opcode 1
   makes this firmware drop the link; the mode-15 session is implicit.
5. The bulb pushes mode-15 reports (opcode `0x8006`) which carry current state and
   must be acked back.

### 3.6 Datapoint (DP) map
| DP | Name | Type | Meaning |
| --- | --- | --- | --- |
| 20 | switch_led | bool | power |
| 21 | work_mode | enum | 0=white, 1=colour, 2=scene |
| 22 | bright_value_v2 | value | brightness 10–1000 |
| 23 | temp_value_v2 | value | colour temp 0–1000 (0=warm) |
| 24 | colour_data_v2 | string | HSV as `HHHHSSSSVVVV` ascii-hex (H 0–360, S/V 0–1000) |
| 25 | scene_data_v2 | string | scene definition |
| 26 | countdown_1 | value | countdown seconds |
| 33 | power_memory | raw | power-on state memory |
| 34 | do_not_disturb | bool | — |

---

## 4. When control breaks: re-fetching keys

`local_key` **rotates every time the bulb is re-paired** in any app. `sec_key`
rotates with it. If `bulb.py` suddenly can't decrypt (CRC errors / pairing
rejected), the keys are stale. To refresh:

1. `uv run fetch_keys.py <smartlife-user-code>` — scan the QR in Smart Life. This
   refreshes `local_key` + `uuid`.
2. Re-extract `sec_key` from the app on the rooted phone (§3.4).
3. Both into `~/.config/tuyable/devices.json`.

(Find the user code in Smart Life → Me → Settings → Account and Security → User
Code.)

---

## 5. Status of the Google Home bridge (unfinished)

Goal: expose the bulb to Google Home. Google Home can't speak BLE, so the plan is
an always-on bridge on the `hermes` Pi (Pi 4, built-in BLE) that holds the BLE
session and presents the bulb as a **Matter** light (added to Google Home locally,
no subscription).

Done so far:
- Pi confirmed **in Bluetooth range** of the bulb (`bluetoothctl` sees
  `<bulb-mac> TUYA_`).
- `bulb.py` + `uv` + credentials installed on the Pi; `selftest` passes there.

Not done:
- Confirm the Pi can **drive** the bulb (an on/off round-trip over BLE).
- Pick the Matter stack: **circuitmatter** (one lean Python service, no Home
  Assistant) vs **Home Assistant + Matter export**. Note: Google Home commissioning
  of Matter usually needs a Google/Nest hub on the LAN — verify that exists before
  committing, else fall back to Nabu Casa (paid) or a Hue-bridge emulation.
- Make the Pi Bluetooth bring-up persistent (`sudo rfkill unblock bluetooth` +
  `AutoEnable=true` in `/etc/bluetooth/main.conf`).

---

## 6. Loose end (security)

The public repo `funinkina/havells-music-sync` still contains a Tuya **API secret**
(`tinytuya.json`) and device **local keys** (`devices.json`). Rotate the Tuya
project secret, re-pair to rotate device keys, and scrub git history
(`git filter-repo`). A plain delete leaves them in history.
