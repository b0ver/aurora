# Compatibility

## Developed & tested on

Aurora was built and verified end-to-end on:

| | |
|---|---|
| **Controller** | **SK0127** (Skydimo 27″ monitor light strip, 3-sided) |
| **LEDs** | **65** (left 17 · top 31 · right 17) |
| **Bridge / port** | CH340 USB-serial, `/dev/cu.usbserial-*`, 115200 8N1 |
| **Channel order** | **RGB** (confirmed with a red/green/blue test) |
| **macOS** | 14+ (Sonoma), Apple Silicon |

**What was tested on it:** auto-detection + `Moni-A` → `SK0127` handshake and LED
count · the four modes driving the strip (Circadian, Screen Sync, Music Sync,
Scene) · gamma-corrected warm tones · the installation-direction setup · the
continuous render loop (no blanking/flicker) · auto-reconnect on a busy/replugged
port.

> Everything else below is **expected to work** based on the same auto-detect
> path and shared geometry, but has **not** been verified on physical hardware.
> Reports (good or bad) for other models are very welcome — open an issue.

## How Aurora decides what's compatible

On launch Aurora scans the USB-serial ports, sends the `Moni-A` handshake, and
reads back the controller's model id (`SK####`). If that model is in its
built-in `ControllerCatalog`, Aurora knows the LED count and layout and starts
driving it. **You don't pick a model** — it's detected automatically. The app
window shows what was found: `Device: SK0127 · 65 LEDs · /dev/cu.usbserial-…`.

Colors currently assume **RGB** channel order (confirmed on SK0127). A model with
GRB LEDs would show swapped colors — that's a one-line fix once reported (see
[TROUBLESHOOTING](TROUBLESHOOTING.md)).

## Model matrix

Legend: ✅ verified · 🟢 expected to work (auto-detected, supported geometry) ·
🟡 recognized but unverified / not a screen strip.

### Monitor light strips — 3-sided (⊓, the common kit)

| Controller | Size | LEDs | Aurora |
|---|---|---|---|
| SK0121 | 21″ | 51 | 🟢 |
| SK0124 | 24″ | 54 | 🟢 |
| **SK0127** | **27″** | **65** | ✅ **tested** |
| SK0132 | 32″ | 77 | 🟢 |
| SK0134 | 34″ ultrawide | 71 | 🟢 |
| SK0149 | 49″ ultrawide | 107 | 🟢 |

### Monitor light strips — 4-sided (▢, includes the bottom edge)

| Controller | Size | LEDs | Aurora |
|---|---|---|---|
| SK0L21 | 21″ | 76 | 🟢 |
| SK0L24 | 24″ | 80 | 🟢 |
| SK0L27 | 27″ | 96 | 🟢 |
| SK0L32 | 32″ | 114 | 🟢 |
| SK0L34 | 34″ | 112 | 🟢 |

### "A" series strips

| Controller | Size | LEDs | Aurora |
|---|---|---|---|
| SKA124 | 24″ | 70 | 🟢 |
| SKA127 | 27″ | 81 | 🟢 |
| SKA132 | 32″ | 95 | 🟢 |
| SKA134 | 34″ | 95 | 🟢 |

### Other devices (bars, large strips, modules)

Recognized by the catalog and will light up, but these aren't standard
screen-edge strips — screen-sync geometry and channel order are **unverified**,
and some have no meaningful "screen" mapping. Circadian / Music / Scene still
make sense on most of them.

| Controller | LEDs | Notes |
|---|---|---|
| SK0201 / SK0202 / SK0204 | 40 / 60 / 50 | 2-segment (e.g. desk bars) — 🟡 |
| SK0301 | 16 | small bar — 🟡 |
| SK0410 | 290 | long single strip — 🟡 |
| SK0801 / SK0802 | 2 / 18 | small / accessory — 🟡 |
| SK0901 / SK0E01 / SK0H01 / SK0I01 | 14 / 16 / 2 / 32 | accessories — 🟡 |
| SK0F01 | 58 | single strip — 🟡 |
| SK0J01 / SK0J02 / SK0K01 | 120 / 114 / 120 | large single strips — 🟡 |
| SK0N03 | 253 | large strip — 🟡 |

> Sizes are inferred from the controller id (the last two digits ≈ screen
> inches) and the per-side LED counts; treat them as a guide, not a spec sheet.

## Not compatible / out of scope

- **Newer or rebadged controllers** not in the catalog — Aurora won't recognize
  the handshake reply and won't drive them. Please report the model id.
- **Non-Skydimo / OEM-clone** controllers with a different protocol.
- **Windows-only** Skydimo products — Aurora is macOS-only.
- The official app's WiFi/cloud or third-party-brand (ASUS/Corsair/…) integrations
  are out of scope; Aurora targets the direct USB-serial Skydimo strips.

If your strip works (or doesn't), a quick note with the model id from the app's
device line helps the matrix above — thank you!
