# ADR-0001: Native Swift/SwiftUI for the Aurora macOS app

- Status: Accepted
- Date: 2026-06-20
- Deciders: Product owner (Evgeny), Tech lead (Aurora team)

## Context

We are building an ambient-lighting controller that must:
- live in the **menu bar** with one-click mode switching (the product owner's
  primary unmet need vs. the original Skydimo app);
- run a **real-time render loop** (screen + audio → LED frames at ~30–60 fps)
  with low latency and low CPU;
- capture the screen and system audio on macOS;
- feel polished — UX/UI is an explicit top priority.

Target user is macOS-first. Candidate stacks considered: native Swift/SwiftUI,
Tauri (Rust + web UI), Electron (TypeScript), and staying on C++/Qt like the
original.

## Decision

Build a **native macOS app in Swift 6 / SwiftUI**.

Rationale:
- `MenuBarExtra` is purpose-built for the tray mode-switcher requirement.
- `ScreenCaptureKit` is the modern, GPU-efficient capture API (lowest latency,
  per-display, HDR-aware) — far better than generic cross-platform capture.
- `AVAudioEngine` + `vDSP`/Accelerate give fast, native FFT for music sync.
- Best-in-class UX/animation fidelity on macOS with the least effort.
- No runtime/web-bridge overhead in the hot path.

## Consequences

- **macOS-only** for v1. Cross-platform (Windows) is explicitly out of scope;
  if it ever matters, the core (color math, protocol, scheduling) is isolated in
  platform-agnostic modules and could be reused.
- Requires the Swift toolchain to build (see [ADR-0002](0002-build-system-spm.md)).
- Team works in Swift; reverse-engineered protocol details (C++) are translated.

## Alternatives rejected

- **Tauri/Electron**: cross-platform, but heavier and higher-latency for a 60fps
  LED hot path, and the menu-bar + capture stories are worse than native.
- **C++/Qt (like original)**: reusable knowledge but poor UX velocity; Qt menu
  bar and theming fight macOS conventions.
