# Aurora — Roadmap

Milestone-based, trunk-friendly. Each milestone is a vertical slice that builds
and is mergeable to `main`. Branch naming: `feat/<milestone>-<slug>`.

Legend: ✅ done · 🔨 in progress · ⏳ planned

---

## M0 — Foundation ✅
**Goal:** repo, docs, buildable multi-module skeleton, CI-able build.
- ✅ Git repo + `.gitignore` (vendor binary excluded)
- ✅ Docs: PRD, Architecture, ADRs, reference configs extracted
- ✅ Reverse-engineering spike: **Skydimo serial protocol decoded** →
  `docs/protocol/skydimo-serial-re.md` (115200 8N1, "Ada" header, `Moni-A`
  handshake; only RGB-vs-GRB order pending hardware)
- ✅ Swift package: modules `AuroraCore`, `AuroraDevice`, `AuroraCircadian`,
  `AuroraEngine`, `AuroraApp`; `swift build` green; `AuroraChecks` harness (14/14)
- ✅ `MenuBarExtra` shell with a mode-switcher (the headline UX) + live LED preview
- ✅ `Scripts/package_app.sh` → `dist/Aurora.app`
- ✅ Real `SkydimoProtocol` packet builder + `SerialLEDController` (termios),
  byte-exact tested — ready for M2 hardware bring-up

## M1 — Circadian mode (first real mode) ✅
**Goal:** the flagship differentiator, end-to-end on the simulated controller.
- ✅ Solar position (sunrise/sunset from lat/long + date, no network)
- ✅ Time-of-day → color-temperature schedule (day/sunset/night, configurable)
- ✅ Kelvin → RGB; smooth elevation-based transitions like f.lux
- ✅ Location: manual + CoreLocation ("Use my location"); night brightness curve
- ✅ Menu-bar quick toggles: Auto/Day/Night override + pause
- ✅ Settings panel: Kelvin sliders, 24h **schedule preview graph** + time scrubber
- ✅ Persistence (UserDefaults); `AuroraChecks` covers override/schedule/codable
- ✅ Launch smoke test: app runs as menu-bar agent without startup crash

## M2 — Device layer on real hardware ✅
**Goal:** drive the owner's physical controller.
- ✅ `AuroraProbe` bring-up CLI: port scan, handshake auto-discovery, color/order
  test, live circadian on real LEDs
- ✅ **Confirmed on hardware (SK0127, 65 LEDs):** `Moni-A`→`SK0127` handshake,
  channel order **RGB**, count from `ControllerCatalog`
- ✅ `DeviceManager` auto-detect wired into the app; `SerialLEDController` (real)
  with `SimulatedLEDController` fallback
- ✅ Installation-direction model + setup screen (see [ADR-0004](adr/0004-installation-direction.md))
- ✅ Circadian renders to the real strip (menu-bar agent)
- ⏳ Brightness/gamma calibration; live reconnect/rescan & port-busy UX (carry to polish)

### Bring-up prerequisite
The serial port is **exclusive** — the native Skydimo app must be fully quit
before Aurora/AuroraProbe can open it.

## M3 — Screen Sync ⏳
**Goal:** core Skydimo parity feature.
- `ScreenCaptureKit` capture, per-display
- Edge-zone sampling → per-LED averaging mapped via `ledMap`
- Sub-modes: Full / Cinema (letterbox) / Top / Bottom / Left / Right halves
- Temporal smoothing, saturation/brightness controls, capture FPS control
- Multi-monitor selection
- **LED layout / direction setup screen** (parity with the original's setup step):
  configure routing left→right / top→bottom, start corner, per-side counts —
  seeded from the vendor `lines` (e.g. SK0124 = [14, 26, 14]) and `ledMap`.
  Lives in Settings, not the menu bar. *(Owner requested; screenshot to follow.)*

## M4 — Music Sync ⏳
**Goal:** audio-reactive lighting.
- System-audio loopback + mic capture; source picker
- `vDSP` FFT → frequency bands → `key_music` channel mapping
- Modes 1–4 (peak/spectrum/flow/mood), sensitivity & smoothing
- Beat detection

## M5 — Scenes, schedules, polish ⏳
**Goal:** delight + automation.
- Static colors, gradients, saved scenes/presets
- Time/automation rules (e.g. circadian by day → screen-sync in the evening)
- Global hotkeys for modes; launch-at-login; per-mode persistence
- Onboarding, empty/permission states, accessibility pass

## M6 — Release engineering ⏳
**Goal:** shippable.
- Code signing + notarization (requires full Xcode/`notarytool`)
- Auto-update, crash reporting (opt-in), DMG packaging
- App icon, marketing page

---

### Stretch / backlog (see PRD "Future feature ideas")
Wake-up sunrise alarm · Now-Playing album-art color · ambient-light adaptive
brightness · Focus/Pomodoro lighting · notification glows · HDR/game-aware
capture · iOS companion via Shortcuts.
