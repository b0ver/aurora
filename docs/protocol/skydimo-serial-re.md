# SkyDimo macOS — USB-Serial Wire Protocol (Reverse-Engineering Report)

**Goal:** document the USB-serial protocol the SkyDimo macOS app uses to drive its LED
controller, sufficient to re-implement a compatible driver in Swift.

**Scope of analysis (read-only):**
- `SkyDimo.app/Contents/MacOS/Skydimo` — main executable, Mach-O x86_64. **All serial logic lives here.**
- `SkyDimo.app/Contents/libs/libLibSkydimo.dylib` — x86_64; this is the **media-capture core** (FFmpeg / OpenCV / AVFoundation). It contains **no** serial code. Despite the task framing, the controller code is statically linked into the main exe, not this dylib.
- `SkyDimo.app/Contents/Resources/controler_config/*.json` — per-model LED maps + master `SKController.json`.

**Toolchain found:** Qt 5.15.11. The serial port uses **QtSerialPort** (`QtSerialPort.framework` linked by the main exe). Device hot-plug detection uses **IOKit** directly (`IOServiceMatching`, `IOServiceAddMatchingNotification`).

**Leftover debug build paths** confirm source filenames:
`/Users/apple/dev/wangyuhuai/SkyDimo/Skydimo/Skydimo/controllers/SKController.cpp`,
`.../SKControllerEnumerator.cpp`, `.../AbsRGBController.cpp`, `.../DeviceManager.cpp`.

---

## 1. Summary of Findings

| # | Item | Finding | Confidence |
|---|------|---------|------------|
| 1 | Transport | USB CDC serial via QtSerialPort over a `/dev/cu.*` BSD device | **High** |
| 2 | Port discovery | IOKit matches **all** `IOSerialBSDClient` nodes; reads `IODialinDevice` for the `/dev/cu.*` path. No VID/PID filter at IOKit level. | **High** |
| 3 | Candidate filter | Internal "CH340" device set (`scanCH340Devices`, "Total CH340 Devices:") — port-name based pre-filter | **Medium** |
| 4 | Real device ID | **Handshake**: app writes ASCII `Moni-A`; a genuine controller replies with an ASCII string whose **upper-case form starts with `"SK"`** (`PRODUCT_PREFIX = "SK"`). The reply is the model ID, e.g. `SK0124`. | **High** |
| 5 | Baud rate | **115200** (`0x1C200`), **8 data bits, No parity** (1 stop implied). Single baud in the whole binary. | **High** |
| 6 | Open mode | `QIODevice::ReadWrite` (`open(3)`) | **High** |
| 7 | Pixel frame magic | **`Ada`** (`0x41 0x61... ` → `'A','d','a'` = `0x41 0x64 0x61`), Adalight-derived | **High** |
| 8 | Length field | After `Ada`: a literal `0x00`, then **count-high byte**, then **count-low byte** (big-endian 16-bit LED count, preceded by a zero pad byte). `count` = number of LEDs. | **High** |
| 9 | Adalight checksum | **NOT present.** Standard Adalight uses `checksum = hi XOR lo XOR 0x55`; SkyDimo omits it and inserts a leading `0x00` instead. | **High** |
| 10 | Payload | `count × 3` raw bytes, one RGB triple per LED, appended directly after the header. | **High** |
| 11 | Channel order | Per-LED **R, G, B** (pass-through; no GRB/BRG swizzle in the host code). Spatial LED order is remapped via the per-model `ledMap` JSON. | **Medium-High** |
| 12 | Trailing checksum/CRC | **None** after the payload. | **High** |
| 13 | Brightness | Applied **host-side** (each channel `× brightnessFloat`, then gamma). **No** brightness command is sent to the device. | **High** |
| 14 | Mode / effect commands | None over serial. Effects are computed on the host; only `Ada` pixel frames + the `Moni-A` probe are sent. | **Medium-High** |
| 15 | Device → host messages | Numeric/ASCII lines. A reply equal to the probe-expected string is treated as a **physical button press** (`onDevCmd1`, "Received click signal"). | **Medium** |
| 16 | Firmware/version string | None observed in app↔device traffic. | **Low/Unknown** |

---

## 2. Serial Port Selection

### 2.1 Enumeration (IOKit) — `MacSerialPortMonitor::start()`
```
IOServiceMatching("IOSerialBSDClient")
IONotificationPortCreate(kIOMasterPortDefault)
CFRunLoopAddSource(... kCFRunLoopDefaultMode)
IOServiceAddMatchingNotification("IOServiceMatched", ..., onDeviceAdded)
```
On each matched node, `onDeviceAddedImpl` calls
`IORegistryEntrySearchCFProperty(..., "IOService", ...)` and reads the **`IODialinDevice`**
property to obtain the `/dev/cu.*` path. **No USB Vendor/Product ID dictionary is used** —
the IOKit match is generic for any serial-BSD device. Filtering happens later (steps below).

### 2.2 "CH340" candidate set — `SKControllerEnumerator::scanCH340Devices()`
Maintains an internal `QHash<QString,...>` of candidate port names and logs
`"Total CH340 Devices: <n>"`. For each candidate it schedules `makeController()` after a
`500 ms` (`0x1F4`) delay. The CH340 naming strongly implies the hardware uses a **WCH CH340
USB-UART bridge** (USB VID `0x1A86`), and that the host pre-selects ports whose name matches
the CH340 driver's `/dev/cu.wchusbserial*` pattern — but the **exact name-match string was not
located as a literal** in the disassembly, so treat the VID/PID/name-pattern as inferred.

> ⚠️ **No literal `0x1A86`, `CH340`-as-USB-string, `cu.wchusbserial`, `SLAB`, or VID/PID hex
> constant was found in the binary.** The "CH340" label is a class/method name only. The
> authoritative device test is the `Moni-A` handshake, not a VID/PID.

### 2.3 Authoritative device verification — `SKControllerEnumerator::makeController()`
1. `SKSerialPort::init(QSerialPortInfo)` opens the port at 115200 8N1 (Section 3).
2. Connect `QSerialPort::readyRead → onDevCmdArrival`.
3. Start a `5000 ms` (`0x1388`) verification `QTimer` (timeout = reject).
4. **Write the probe `"Moni-A"`** to the port (`SKSerialPort::write`).
5. In the readyRead handler (a `makeController` lambda):
   - `rawData = port.readAll()`
   - `rawData.toUpper().startsWith(QByteArray("SK"))`  ← **PRODUCT_PREFIX = `"SK"`**
   - If true → device accepted; the reply (e.g. `SK0124`) is the **model ID** used to load
     `controler_config/SKController.json → SK0124 → { nbLeds, ledMap, brightness }`.

Debug strings confirming this path:
`"Product prefix: "`, `"rawData.toUpper().startsWith(QByteArray(PRODUCT_PREFIX): "`,
`"Upper case raw data : "`, and the literal `"SK"`.

**Net effect:** a re-implementation should open each `/dev/cu.*` candidate (preferably ones
that look like a CH340/WCH bridge), send `Moni-A`, and accept the port if the reply (upper-cased)
starts with `SK`. The first 6 ASCII chars of the reply are the model ID.

---

## 3. Baud / Line Settings — `SKSerialPort::init()`

```asm
QSerialPort::setPort(info)
mov  esi, 0x1C200           ; 115200
QSerialPort::setBaudRate(115200, AllDirections)
mov  esi, 8
QSerialPort::setDataBits(Data8)
xor  esi, esi
QSerialPort::setParity(NoParity)            ; 0
QSerialPort::open(ReadWrite)                ; mode = 3
```

| Setting | Value |
|---------|-------|
| Baud | **115200** |
| Data bits | **8** |
| Parity | **None** |
| Stop bits | Default (1) — not explicitly set |
| Flow control | Default (None) — not explicitly set |
| Open mode | ReadWrite |

On open failure it logs `"[SerialPort]: Failed to open the serial port ..."` and clears buffers.

---

## 4. Pixel Frame Format

The frame is assembled in two pieces:

- **Header** is (re)built whenever the layout changes, in `SKController::onLayoutChanged()`,
  and cached at controller object offset `+0x148` (a `QByteArray`).
- **Payload** is appended in `SKController::write(const QVector<SD_RGB>&)` and the whole buffer
  is emitted via `SKController::writeToPort(QByteArray)` (a Qt signal) → `SKSerialPort::write` →
  `QSerialPort::write`.

### 4.1 Header construction — `onLayoutChanged()`
```asm
QByteArray::clear()
QByteArray::append("Ada")          ; 0x41 0x64 0x61
QByteArray::append((char)0)        ; 0x00   (literal zero; xor esi,esi)
QByteArray::append( *(int8*)(this+0x79) )   ; LED-count byte 1 (bits 8..15) = HIGH
QByteArray::append( *(int8*)(this+0x78) )   ; LED-count byte 0 (bits 0..7)  = LOW
```
Object offset `+0x78` holds the LED count as a 32-bit int (set by
`AbsRGBController::setLayout(count, ...)`, store `mov [rbx+0x78], count`). So:

- `byte[0x79]` = `(count >> 8) & 0xFF`  → **high byte**
- `byte[0x78]` = `count & 0xFF`        → **low byte**

**Header (5 bytes):** `41 64 61 00 HH LL` — wait, that is 6 bytes. Precisely:

```
offset  value            meaning
0       0x41 'A'         magic
1       0x64 'd'         magic
2       0x61 'a'         magic
3       0x00             constant pad (always zero)
4       HH = count>>8    LED count, high byte
5       LL = count&0xFF  LED count, low byte
```
Total header = **6 bytes**. (Classic Adalight is 6 bytes too: `Ada hi lo chk`. SkyDimo keeps
the 6-byte shape but replaces the *first* extra byte with a constant `0x00` and the *checksum*
byte is gone — the byte after `Ada` is `0x00`, then hi, then lo.)

> Interpretation note: the three bytes after `Ada` are `00 HH LL`. This can equivalently be read
> as a **24-bit big-endian LED count** (top byte forced to 0). For any real strip count (< 65536)
> the practical encoding is: `Ada`, `0x00`, `count_hi`, `count_lo`.

### 4.2 Payload — `SKController::write()`
```asm
n   = *(int*)(vector+4)            ; number of SD_RGB entries
len = n*3                          ; leal (rax,rax,2)
QByteArray::append(vectorData, len)   ; raw n*3 bytes appended after the cached header
... (pad/truncate so payload length == count*3) ...
writeToPort(buffer)                ; emit -> SKSerialPort::write -> QSerialPort::write
```
- Each LED = **3 bytes**. `SD_RGB` is a 3-byte struct; bytes are emitted in struct order **R,G,B**.
- The code also reconciles the appended length against `count*3` (insert/trim), guaranteeing the
  payload is exactly `count*3` bytes regardless of the incoming vector length.
- **No checksum/CRC/terminator** is appended after the payload.

If the cached header is empty/invalid the write is aborted with
`"Invalid header, Abort write."` (so the header MUST be present before pixels are sent — i.e.
`setLayout`/`onLayoutChanged` must run first).

### 4.3 Byte-by-byte diagram (N LEDs)
```
+------+------+------+------+------+------+----- ... -----+
| 0x41 | 0x64 | 0x61 | 0x00 |  HH  |  LL  |  R0 G0 B0 R1 G1 B1 ... R(N-1) G(N-1) B(N-1) |
+------+------+------+------+------+------+----- ... -----+
  'A'    'd'    'a'   pad   N>>8  N&0xFF        N*3 payload bytes, RGB order
|<--------------- 6-byte header --------------->|<------- 3*N bytes -------->|
Total on-wire length = 6 + 3*N bytes. No trailing checksum.
```

### 4.4 Concrete example
**All-red, N = 54 LEDs** (model `SK0124`, `nbLeds = 54`, `0x36`):
```
header : 41 64 61 00 00 36
pixel  : FF 00 00   (×54)
frame  : 41 64 61 00 00 36 FF 00 00 FF 00 00 ... (54 triples) ...
bytes  : 6 + 162 = 168 total
```

**All-green, N = 51 (`SK0121`):** header `41 64 61 00 00 33`, then `00 FF 00 × 51`.
**N = 290 (`SK0410`):** `290 = 0x0122` → header `41 64 61 00 01 22`, then `870` payload bytes.

> Brightness/gamma are already baked into the R/G/B bytes by `internalUpdate()` before `write()`;
> a re-implementation that wants raw colors should pre-scale channels itself (`ch * brightness`,
> then the app's gamma curve — see §5.3).

---

## 5. Init / Handshake / Brightness / Mode

### 5.1 Handshake (device discovery & verification)
| Step | Direction | Bytes / Meaning |
|------|-----------|-----------------|
| Probe | host → device | ASCII `Moni-A` (`4D 6F 6E 69 2D 41`), no terminator observed |
| Reply | device → host | ASCII model string; **`toUpper().startsWith("SK")`** ⇒ valid. First chars = model ID, e.g. `SK0124` |
| Timeout | — | 5000 ms verification `QTimer`; expiry ⇒ port rejected |

There is **no separate "open/init" command** beyond opening the port and sending `Moni-A`.

### 5.2 Pixel updates
Only `Ada` frames (Section 4). Sent on every effect tick / color change.

### 5.3 Brightness & gamma (host-side; **not** a wire command)
In `AbsRGBController::internalUpdate()`:
- read source R,G,B (`movzbl (rax+rsi)`, `+1`, `+2`)
- multiply each by the brightness float at object `+0x8C` (`mulss`)
- apply a gamma curve (`pow`/division constants at `+0x90`, `+0xD8`) and clamp
- store back R,G,B in order, then `write()` the resulting vector.

Default brightness in `SKController.json` is `0.8` for most models (`1.0` for a few, e.g. SK0301).
**No brightness opcode is ever written to the port.**

### 5.4 Mode / effect commands
None on the wire. All effects (flowing, mood-shadow, color-map, music, etc.) are rendered on the
host into the RGB vector. The device is a "dumb" Adalight-style pixel sink.

### 5.5 Device → host (input events)
`SKSerialPort::onDevCmdArrival()` reads `readAll()`, logs it, parses it (`toInt(base=10)` and
`fromHex`). If the bytes match the expected verification string it emits `deviceCommand1` →
`SKController::onDevCmd1()` ("Received click signal from ...") — i.e. a **physical button press**
on the controller. Unrecognized data → "Received a unknown data". This is **input only**; it does
not affect the outbound pixel protocol.

---

## 6. Open Questions — REQUIRE the physical device to confirm

These cannot be settled from the binary alone. Run them against the real controller.

1. **CHANNEL ORDER (RGB vs GRB) — most important to verify.**
   The host code is pass-through R,G,B, but the firmware/LED type (WS2812 is GRB internally)
   could swap. **Experiment:** after handshake, send a frame that lights LED #0 pure **red**
   (`Ada 00 00 01 FF 00 00`). If the strip shows **green**, the order is GRB and you must swap.
   Repeat with `00 FF 00` and `00 00 FF`. *(Also test via the official app set to solid red and
   snoop — see #6.)*

2. **EXACT LENGTH-FIELD SEMANTICS.** Confirm the device expects `Ada 00 HH LL` and that `HH:LL`
   = LED count (not count−1, not byte-length). **Experiment:** send a frame with `count=2`
   (`Ada 00 00 02` + 6 color bytes) and verify exactly 2 LEDs light. Try off-by-one counts to see
   if the firmware is strict.

3. **HANDSHAKE FRAMING.** Does `Moni-A` need a terminator (`\n`, `\r\n`)? What is the **exact**
   reply (full bytes, length, line ending)? Is the reply only the model (`SK0124`) or
   model+suffix? **Experiment:** `screen /dev/cu.XXXX 115200`, type `Moni-A`, capture the raw reply
   with a hex-capable terminal (e.g. `cat -v` / `pyserial` logging).

4. **DEVICE PATH / VID-PID.** Confirm the bridge chip and `/dev/cu.*` name. **Experiment:**
   `ioreg -p IOUSB -l -w0 | grep -iE "idVendor|idProduct|USB Product Name"` and
   `ls /dev/cu.*` with the controller plugged/unplugged. Expected: a CH340 (`idVendor 0x1A86`)
   showing as `/dev/cu.wchusbserial*`, but **verify** — it may be CP210x/FTDI.

5. **FRAME RATE / FLOW CONTROL / ACK.** Does the device ACK pixel frames, or is it fire-and-forget?
   At what max FPS does it drop frames at 115200? (168 bytes @ 115200 8N1 ≈ 14.6 ms ⇒ ~68 fps ceiling
   for 54 LEDs; longer strips are slower.) **Experiment:** stream frames at increasing rates and
   watch for tearing/no-update; check whether anything is read back after a pixel frame.

6. **GROUND-TRUTH SNIFF.** Run the **official app** while sniffing the port to validate every field
   above end-to-end. **Experiment (macOS):**
   - `sudo dtrace`-based serial trace, **or** a software loopback: create a PTY proxy
     (`socat -x -v PTY,link=/dev/cu.fake,raw PTY,link=/dev/cu.real,raw`) so the app talks to one end
     and you log the bytes — *(socat tap is the cleanest way to capture the live `Ada` frames and
     the handshake reply with timestamps)*.
   - Set the app to **solid red**, capture one frame, and confirm header `41 64 61 00 HH LL` and the
     `FF 00 00` (or `00 FF 00`) repetition to resolve #1 and #2 simultaneously.

7. **MULTI-LINE / `ledMap` ORDERING.** The per-model JSON `ledMap` reorders pixels spatially
   (the `lines` array splits the strip into runs). Confirm whether the firmware expects pixels in
   physical chain order (so the host applies `ledMap`) — verify by lighting a single mapped index
   and checking which physical LED responds.

8. **GAMMA CURVE.** If you want output to match the official app exactly, reproduce the gamma
   constants at object `+0x90`/`+0xD8`. Their numeric values weren't extracted here; capture
   app output for a known input color and fit the curve, or pull the float constants from
   `__const` at those offsets.

---

## 7. Raw Evidence Appendix

### 7.1 Key symbols (main exe, `nm`)
```
SKController::write(QVector<SD_RGB> const&)
SKController::writeToPort(QByteArray)
SKController::onLayoutChanged()           ; builds the "Ada" header
SKController::onDevCmd1()                 ; physical button event
SKSerialPort::init(QSerialPortInfo const&)
SKSerialPort::write(QByteArray)
SKSerialPort::onDevCmdArrival()
SKSerialPort::deviceCommand1()
SKControllerEnumerator::scanCH340Devices()
SKControllerEnumerator::makeController(QString)   ; sends "Moni-A", checks "SK"
SKControllerEnumerator::readCtlDefaultCfg(SKController*)
MacSerialPortMonitor::start()             ; IOKit IOSerialBSDClient matching
AbsRGBController::setLayout(int,int,int,int,int)  ; stores count at +0x78
AbsRGBController::internalUpdate()        ; brightness*gamma, RGB pass-through
AbsRGBController::setBrightness(float)
```

### 7.2 Header builder — `SKController::onLayoutChanged` (disasm)
```
leaq  "Ada"(%rip), %rsi   ; QByteArray::append(const char*)  -> 'A' 'd' 'a'
xorl  %esi, %esi          ; QByteArray::append((char)0)      -> 0x00
movsbl 0x79(%rbx), %esi   ; QByteArray::append(count_hi)
movsbl 0x78(%rbx), %esi   ; QByteArray::append(count_lo)
```

### 7.3 Baud — `SKSerialPort::init` (disasm)
```
movl $0x1c200, %esi       ; 115200
call QSerialPort::setBaudRate
movl $0x8, %esi           ; Data8
call QSerialPort::setDataBits
xorl %esi,%esi            ; NoParity
call QSerialPort::setParity
movl $0x3, %esi           ; open(ReadWrite)
call *0x68(%rax)
```

### 7.4 Payload sizing — `SKController::write` (disasm)
```
movl 0x4(%rax), %eax      ; n = vector.size
leal (%rax,%rax,2), %edx  ; n*3
call QByteArray::append(ptr, n*3)
...
call SKController::writeToPort(QByteArray)
```
Abort path: literal `"Invalid header, Abort write."` when header empty.

### 7.5 Device verification — `makeController` lambda (disasm + strings)
```
"Moni-A"                  ; probe written to port
"Product prefix: "        ; log
"SK"                      ; PRODUCT_PREFIX literal
QByteArray::toUpper_helper
QByteArray::startsWith    ; rawData.toUpper().startsWith("SK")
QTimer::setInterval(0x1388)   ; 5000 ms verify timeout
QTimer::setInterval(0x1F4)    ; 500 ms scan delay (scanCH340Devices)
```

### 7.6 IOKit enumeration — `MacSerialPortMonitor::start` (disasm + strings)
```
"IOSerialBSDClient"       -> IOServiceMatching
"IOServiceMatched"        -> IOServiceAddMatchingNotification
"IODialinDevice"          -> /dev/cu.* path
"IOService"               -> IORegistryEntrySearchCFProperty
kIOMasterPortDefault, IONotificationPortCreate, CFRunLoopAddSource
```

### 7.7 Config cross-reference — `controler_config/SKController.json`
Model ID → LED count (the value that becomes the header `HH:LL` and the `count*3` payload size):
```
SK0121=51  SK0124=54  SK0127=65  SK0132=77  SK0134=71  SK0149=107
SK0201=40  SK0202=60  SK0204=50  SK0301=16  SK0410=290 SK0901=14
SK0L21=76  SK0L24=80  SK0L27=96  SK0L32=114 SK0L34=112  (default brightness 0.8)
```
Per-model files (`SK0124.json`, ...) contain `ledMap` (len = `key_num` = nbLeds), `screenWidth/Height`,
`key_music`, `key_space`. The enumerator also references a family-config format
`"controler_config/%1Controller.json"` (e.g. `SKAController.json`) keyed by model prefix.

### 7.8 Notable strings (verbatim)
```
Ada
Invalid header, Abort write.
Moni-A
Total CH340 Devices:
Product prefix:
rawData.toUpper().startsWith(QByteArray(PRODUCT_PREFIX):
Upper case raw data :
*****Received some data from
======================Received click signal from
======================Received a unknown data ======================
[SerialPort]: Failed to open the serial port
IOSerialBSDClient / IODialinDevice / IOServiceMatched / IOService
```

---

## 8. Minimal Swift re-implementation recipe (derived)

1. Enumerate `/dev/cu.*` (prefer `cu.wchusbserial*` / CH340-like names — but verify, §6.4).
2. Open at **115200, 8N1, no flow control**, ReadWrite.
3. Write ASCII `Moni-A`. Read reply (allow up to ~5 s). Accept if `reply.uppercased().hasPrefix("SK")`.
   Take the model ID from the reply (e.g. `SK0124`) and look up `nbLeds` + `ledMap` from
   `controler_config/SKController.json` / `<model>.json`.
4. To push colors for `N` LEDs:
   - `header = [0x41,0x64,0x61, 0x00, UInt8(N >> 8), UInt8(N & 0xFF)]`
   - `payload = for each LED: [R,G,B]` (apply your own brightness/gamma first; **verify RGB vs GRB on
     hardware — §6.1**; apply `ledMap` reordering if you adopt the app's spatial mapping)
   - `port.write(header + payload)` — no checksum, no terminator.
5. Optionally read the port for button events (a returned line matching the device's ID string).

**Confidence that this drives the LEDs:** High for framing/baud/handshake; the single
hardware-blocking unknown is **RGB vs GRB channel order** (§6.1), which one red-frame test resolves.
