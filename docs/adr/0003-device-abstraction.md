# ADR-0003: Device abstraction — `LEDController` protocol with simulated + serial backends

- Status: Accepted
- Date: 2026-06-20

## Context

The LED hardware speaks a **USB-serial** protocol (the original app links
`QtSerialPort`; device shows up as `/dev/cu.usb*`). The exact wire format is
being reverse-engineered (see [docs/protocol/skydimo-serial-re.md](../protocol/skydimo-serial-re.md))
and must ultimately be verified against the physical controller the owner has.

We need to make progress on modes/UX **before** the protocol is 100% confirmed,
and we want great testability and an on-screen preview.

## Decision

Define a backend-agnostic boundary in `AuroraDevice`:

```swift
protocol LEDController {
    var layout: LEDLayout { get }          // LED count + grid positions (from controller_config)
    func connect() throws
    func render(_ frame: [RGB]) throws     // push one frame of per-LED colors
    func disconnect()
}
```

Backends:
- **`SimulatedLEDController`** — drives an on-screen virtual strip (SwiftUI
  preview). Always available; used for development, demos, and UI testing.
- **`SerialLEDController`** — opens the `/dev/cu.*` port (termios), builds frames
  per the reverse-engineered packet format, writes them. Verified against real
  hardware.

LED layouts are loaded from the **vendor `controller_config` JSON** (already
read from the controller): `key_num` (LED count),
`ledMap` (grid coords), `key_music` (channel split), `screenWidth/Height`.

## Consequences

- Modes/engine depend only on `LEDController`; they don't know or care whether
  output goes to glass or copper.
- The on-screen preview is a first-class, permanent feature (not a throwaway),
  satisfying both "see progress without hardware" and "live preview" UX.
- Swapping/auto-detecting controllers becomes a backend concern, not a mode
  concern.

## Open

- Final packet format + baud + port-match are pending hardware verification;
  `SerialLEDController` ships behind that verification. Until then it can be
  exercised against a loopback / logging sink.
