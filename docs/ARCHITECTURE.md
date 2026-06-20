# Aurora — Architecture

## 1. Overview

Aurora is a native macOS app. A small **engine** runs a render loop: the active
**mode** produces a frame of per-LED colors, the engine post-processes
(brightness/gamma/smoothing), and pushes it to a **controller** (on-screen
simulation and/or the physical USB-serial strip). SwiftUI provides the menu-bar
switcher and windows.

```
            ┌──────────────────────────── AuroraApp (SwiftUI) ───────────────────────────┐
            │  MenuBarExtra (mode switcher) · Main window · Onboarding · LED preview view  │
            └───────────────▲───────────────────────────────────────────────▲─────────────┘
                            │ observes state / sends commands               │ renders preview
            ┌───────────────┴───────────────── AuroraEngine ─────────────────┴─────────────┐
            │  ModeManager (active mode) · RenderLoop (timer) · FramePipeline               │
            │  brightness · gamma · temporal smoothing · master on/off/pause               │
            └───▲──────────────▲──────────────────▲───────────────────────────▲────────────┘
                │ ModeSource    │ ModeSource       │ ModeSource                │ FrameSink
        ┌───────┴──────┐ ┌──────┴───────┐ ┌────────┴────────┐         ┌────────┴─────────┐
        │AuroraCircadian│ │ AuroraCapture│ │   AuroraAudio   │         │   AuroraDevice    │
        │ sun→Kelvin→RGB│ │ ScreenKit→   │ │ AVAudio+vDSP    │         │ LEDController:     │
        │               │ │ edge zones   │ │ FFT→bands       │         │  Simulated | Serial│
        └───────┬───────┘ └──────┬───────┘ └────────┬────────┘         └────────┬─────────┘
                └────────────────┴──────────── AuroraCore ─────────────────────┘
                       RGB · color math · Kelvin · LEDLayout · Mode types
```

## 2. Modules (SwiftPM targets)

| Target | Kind | Responsibility | Key deps |
|---|---|---|---|
| `AuroraCore` | library | Pure domain: `RGB`, color/Kelvin math, `LEDLayout` (+ loader for vendor `controller_config` JSON), `Mode` enum, `ModeSource`/`FrameSink` protocols. No UI, fully testable. | Foundation |
| `AuroraDevice` | library | `LEDController` protocol; `SimulatedLEDController`; `SerialLEDController` (termios + packet builder); port enumeration. | AuroraCore |
| `AuroraCircadian` | library | Solar position, color-temperature schedule, Kelvin→RGB; emits frames as a `ModeSource`. | AuroraCore |
| `AuroraCapture` | library *(M3)* | ScreenCaptureKit capture → edge-zone sampling → per-LED colors. | AuroraCore, ScreenCaptureKit |
| `AuroraAudio` | library *(M4)* | Audio capture (loopback/mic) → vDSP FFT → bands → per-LED. | AuroraCore, AVFoundation, Accelerate |
| `AuroraEngine` | library | `ModeManager`, `RenderLoop`, `FramePipeline` (brightness/gamma/smoothing), orchestrates sources → sinks. | all libs above |
| `AuroraApp` | executable | SwiftUI: `MenuBarExtra` switcher, windows, preview, onboarding, settings, persistence. | AuroraEngine + libs |

Dependency rule: arrows point **down** only. `AuroraCore` depends on nothing in
the project. UI depends on the engine, never the reverse.

## 3. Core data types (`AuroraCore`)

- `RGB` — 8-bit color with HSV, brightness, gamma, blend, Kelvin conversion.
- `LEDLayout` — `count`, `positions: [GridPoint]`, `musicChannels`, screen grid;
  loaded from vendor `controller_config` JSON (`key_num`, `ledMap`, `key_music`,
  `screenWidth/Height`).
- `ModeSource` — `func frame(at: Date) -> [RGB]` (or async/stream variant) that a
  mode implements to produce one frame for the current layout.
- `FrameSink` / `LEDController` — consumes `[RGB]` frames.
- `Mode` — `.circadian | .screenSync(SubMode) | .musicSync(MusicMode) | .static`.

## 4. Render pipeline

1. `RenderLoop` ticks at the active mode's target FPS (circadian ~1–5 fps;
   screen/music ~30–60 fps).
2. `ModeManager` asks the active `ModeSource` for a `[RGB]` frame sized to
   `layout.count`.
3. `FramePipeline` applies: master brightness → per-mode gamma → **temporal
   smoothing** (EMA to prevent flicker) → clamp.
4. Frame is fanned out to all active `FrameSink`s: the **preview** (always) and
   the **device** (when connected).
5. Backpressure: if a sink is slow (serial), drop to latest frame (never queue).

Threading: capture/audio/serial run off the main actor; UI state updates marshalled
to `@MainActor`. The render loop lives on a dedicated dispatch queue / task.

## 5. Device layer (`AuroraDevice`)

See [ADR-0003](adr/0003-device-abstraction.md). `LEDController` abstracts the sink.
`SerialLEDController` builds wire frames per
[docs/protocol/skydimo-serial-re.md](protocol/skydimo-serial-re.md) (header,
length, per-LED RGB/GRB order, checksum) and writes them to `/dev/cu.*` via
termios at the confirmed baud. Layouts come from the vendor configs.

## 6. Circadian engine (`AuroraCircadian`)

- **Solar position:** standard sunrise/sunset/elevation algorithm from
  lat/long + date (NOAA-style), pure math, offline.
- **Schedule:** piecewise temperature curve keyed on sun elevation / time to
  sunset, interpolated smoothly (no perceptible steps).
- **Kelvin→RGB:** planckian-locus approximation; optional brightness curve.
- Exposed as a `ModeSource`; deterministic and unit-tested (golden values for
  known lat/long/date).

## 7. App layer (`AuroraApp`)

- `MenuBarExtra` (window style) hosts the mode switcher + active-mode controls +
  brightness + pause — the headline UX.
- Main window: home/preview, per-mode settings, device status, onboarding.
- State: an `@Observable` app model wrapping the engine; persisted via
  `UserDefaults`/JSON (selected mode, per-mode settings, location, brightness).
- Permissions onboarding for Screen Recording (M3) and Microphone (M4).

## 8. Build & packaging

SwiftPM (`swift build`). The menu-bar agent bundle is assembled by
`Scripts/package_app.sh` into `dist/Aurora.app` with an `Info.plist`
(`LSUIElement=true`, usage strings, bundle id). See
[ADR-0002](adr/0002-build-system-spm.md).

## 9. Testing strategy

- **Unit:** color/Kelvin math, solar position (golden values), packet builder
  (byte-exact vs. RE spec), layout JSON loader.
- **Simulated integration:** engine + mode + `SimulatedLEDController` produce
  expected frame sequences.
- **Hardware (manual, M2+):** verify real controller output matches preview.
- Logic targets run headlessly via `swift test` (no Xcode needed).

## 10. Conventions

- Swift 6 concurrency (actors / `@MainActor` for UI). No force-unwraps in core.
- Each module has a focused public surface; internals `internal`.
- ADRs for every cross-cutting decision; docs updated in the same PR as the code.
