# Aurora — Product Requirements Document (PRD)

- Owner: Evgeny (product owner)
- Author: Aurora team (product/tech lead)
- Date: 2026-06-20
- Status: Living document

## 1. Vision

A native, menu-bar-first macOS app that drives Skydimo-compatible USB LED
strips with **screen sync**, **music sync**, and a flagship **circadian rhythm**
mode — faster and more elegant than the original, with the controls you actually
reach for one click away in the menu bar.

## 2. Problem & motivation

The owner uses Skydimo hardware but the official app has two concrete gaps:
1. **No mode switching from the menu-bar icon.** Changing mode means opening the
   full window. The owner wants to click the tray icon and switch modes instantly.
2. **No circadian mode.** There is no "cool light in the morning, warm + dimmer
   as it gets dark" behaviour (the f.lux idea, applied to ambient LEDs).

Aurora is built around fixing these, with UX/UI as a first-class requirement.

## 3. Target users

- **Primary:** the owner — a Mac power user who wants ambient light that is
  ambient *automation*, controllable from the menu bar.
- **Secondary:** enthusiasts who own Skydimo-class strips and want a better Mac
  client (bias lighting fans, streamers, people who care about eye strain / sleep).

## 4. Goals & non-goals

**Goals**
- Menu-bar mode switcher (one click to change mode / pause / pick scene).
- Circadian mode that visibly tracks the day like f.lux.
- Faithful screen sync and music sync (parity with Skydimo's core value).
- Beautiful, native, low-friction UX; great default behaviour.
- Drive the owner's real controller over USB-serial.

**Non-goals (v1)**
- Windows/Linux support.
- Cloud accounts, social features, ads (the original bundles an ad manager — we
  deliberately omit it).
- Supporting every one of the 1000+ third-party RGB brands the original claims;
  we target Skydimo controllers (model table embedded in `ControllerCatalog`).

## 5. Modes (functional requirements)

### 5.1 Circadian rhythm 🌅 (NEW — first to build)
- Continuously sets LED **color temperature** from the local **sun position**
  (computed from latitude/longitude + date; no internet needed).
- Defaults like f.lux: ~6500 K daytime → ~3400 K around sunset → ~1900 K deep
  night, with smooth transitions over a configurable window around sunrise/sunset.
- Configurable: day/night temperatures, transition length, optional **brightness
  curve** (dimmer at night), location (manual or CoreLocation).
- Manual overrides: "force day", "force night", "pause for 1h", from the menu bar.
- Output: single warm/cool color across the strip (optionally a subtle gradient).

### 5.2 Screen sync 🖥️
- Mirror screen-edge colors to LEDs using `ledMap` zone positions.
- Sub-modes (parity with original): Full, Cinema (ignore letterbox bars),
  Top / Bottom / Left / Right half.
- Controls: capture FPS, smoothing, saturation, brightness, per-monitor select.

### 5.3 Music sync 🎵
- FFT spectrum of **system audio (loopback)** or **microphone**.
- Map frequency bands to `key_music` channels (with per-channel direction).
- Modes 1–4 (peak meter / spectrum / flowing / mood), sensitivity + smoothing,
  beat detection.

### 5.4 Static & scenes 🎨
- Single color, gradients, saved presets; quick-apply from the menu bar.

## 6. The menu-bar experience (headline UX requirement)

Clicking the menu-bar icon opens a compact panel:
- Big segmented **mode switcher** (Circadian / Screen / Music / Scene).
- Context controls for the active mode (e.g. circadian: current temp + day/night
  override; screen: sub-mode; music: source).
- Master **brightness** slider, **pause/resume**, **on/off**.
- Footer: open full window, device status (connected controller + LED count).
- Optional **global hotkeys** to switch modes without the mouse.

## 7. UX/UI principles

- Native macOS feel (SF Symbols, vibrancy, system controls), dark-mode-first.
- "It just works" defaults; nothing required before light appears.
- Live **on-screen LED preview** mirroring exactly what the strip shows.
- Clear permission onboarding (Screen Recording, Microphone) with rationale.
- Accessible: contrast, full keyboard control, reduced-motion respect.
- Designs reviewed with the design skills (design-critique, accessibility-review,
  ux-copy) before implementation of each surface.

## 8. Success metrics

- Owner switches modes from the menu bar in < 2 s, no window needed.
- Circadian transition is perceptually smooth (no visible stepping).
- Screen-sync end-to-end latency feels immediate (< ~50 ms target).
- CPU usage modest during screen sync (target < ~15% on the owner's Mac).
- Owner's real controller is driven correctly (colors match preview).

## 9. Constraints & risks

- Serial protocol must be confirmed on real hardware (M2). Risk: undiscovered
  handshake/checksum. Mitigation: RE doc + on-device snoop experiments.
- No full Xcode on the dev machine → SPM build + packaging script
  ([ADR-0002](adr/0002-build-system-spm.md)); signing/notarization deferred to M6.
- macOS TCC permissions (screen, mic) gate capture; needs solid onboarding.
- System-audio loopback on macOS may require a virtual audio device or
  ScreenCaptureKit audio; to be validated in M4.

## 10. Future feature ideas (brainstorm for the owner)

Curated to the owner's stated preferences (menu-bar control, circadian, strong UX):

**High value**
- **Wake-up sunrise alarm** — gradual warm→bright ramp at a set time (extends
  circadian; great for mornings).
- **Time/automation rules** — "circadian during the day, auto-switch to screen
  sync when a video is fullscreen / in the evening".
- **Global hotkeys** for modes (original had a hotkey manager) — fits menu-bar,
  mouse-free control.
- **Now-Playing integration** — pull album art color into music/scene mode.

**Medium value**
- **Adaptive brightness** from the Mac's ambient light sensor.
- **Bias-lighting / movie mode** — gentle warm backlight to cut eye strain.
- **Focus / Pomodoro lighting** — color signals work vs. break; ties to Focus modes.
- **Notification glow** — brief pulse on calendar/Slack events (opt-in).
- **HDR / game-aware capture** — better screen-sync color in HDR and games.
- **Multi-zone / multi-monitor** — independent strips per display.

**Nice to have**
- **iOS companion via Shortcuts/Home** — toggle modes from iPhone.
- **Scene sharing / import-export** presets.
- **Energy saver** — auto-off when the display sleeps or Mac is idle.
- **Color-blind-friendly** palette presets.

These are not commitments; they seed M5+/backlog prioritization with the owner.
