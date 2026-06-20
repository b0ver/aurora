# Aurora

Ambient lighting for macOS — drive Skydimo-compatible USB LED controllers with
**screen sync**, **music sync**, and a flagship **circadian rhythm** mode, all
switchable from the **menu bar**.

Aurora is an independent, native macOS reimplementation inspired by the Skydimo
desktop app, built for people who want a faster, cleaner, menu-bar-first
experience and modes the original lacks (notably f.lux-style circadian lighting).

> Status: **early development (M0 — foundation)**. See [docs/ROADMAP.md](docs/ROADMAP.md).

## Why Aurora

The original Skydimo app does screen/music sync well but:
- has no **mode switching from the menu bar** — you must open the full window;
- has **no circadian mode** (cool light by day, warm + dim as it gets dark).

Aurora fixes both and puts UX/UI first.

## Modes

| Mode | What it does | Status |
|---|---|---|
| 🌅 Circadian | Color temperature follows your local sun cycle (f.lux-style) | In progress (first slice) |
| 🖥️ Screen Sync | Mirrors screen-edge colors to the LEDs | Planned |
| 🎵 Music Sync | FFT spectrum of system/mic audio drives the LEDs | Planned |
| 🎨 Static / Scenes | Single color, gradients, saved presets | Planned |

## Tech stack

- **Swift 6 / SwiftUI**, native macOS (`MenuBarExtra` for the tray switcher).
- **ScreenCaptureKit** (screen), **AVAudioEngine + vDSP** (audio FFT).
- **USB-serial** transport to the LED controller (`/dev/cu.*`), compatible with
  Skydimo controllers — see [docs/protocol/](docs/protocol/).
- Built with **Swift Package Manager** (no full Xcode required for dev). See
  [ADR-0002](docs/adr/0002-build-system-spm.md).

## Build

Requires the Swift toolchain (Command Line Tools is enough for dev builds).

```bash
swift build                 # compile all modules
swift run AuroraChecks      # run the logic check harness (see ADR-0002)
swift run AuroraApp         # run (dev)
./Scripts/package_app.sh    # produce dist/Aurora.app (menu-bar agent bundle)
```

## Repository layout

```
Aurora/
├── docs/                 # PRD, architecture, ADRs, protocol RE, UX
│   ├── PRD.md
│   ├── ARCHITECTURE.md
│   ├── ROADMAP.md
│   ├── adr/              # architecture decision records
│   ├── protocol/         # Skydimo serial protocol reverse-engineering
│   └── reference/        # extracted controller LED-map configs
├── Sources/              # Swift modules (see ARCHITECTURE.md)
├── Tests/                # unit tests
├── Scripts/              # build/packaging scripts
└── SkyDimo.app/          # original vendor app (git-ignored reference only)
```

## Contributing / workflow

Trunk-based-ish: `main` is releasable, work happens on `feat/*` branches merged
via PR. See [docs/ROADMAP.md](docs/ROADMAP.md) for the milestone plan.

## License & legal

Independent interoperability project for hardware the user owns. Not affiliated
with or endorsed by Skydimo. Vendor binary under `SkyDimo.app/` is included
locally as a reference only and is **not** committed to the repository.
