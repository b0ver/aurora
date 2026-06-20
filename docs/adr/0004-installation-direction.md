# ADR-0004: LED installation-direction model (host-side spatial remap)

- Status: Accepted
- Date: 2026-06-21

## Context

The vendor app's "Installation method" setup step exposes two independent axes:
- horizontal: **Left to right** / **Right to left**
- vertical: **From bottom to top** / **From top to bottom**

This describes how the physical strip is wound around the screen. We needed to
replicate it. A multi-agent reverse-engineering pass (configs + binary
disassembly + screen-sync coupling, cross-checked adversarially) found:

- The firmware applies each axis as an **`cv::flip`** (a coordinate mirror), via
  two independent flags (`installDirection`, `installDirectionTopDown`) — it is
  **not** a LED-index reversal and does **not** change the serial wire format.
- The canonical `ledMap` has LED 1 at bottom-left, winding up the left, across
  the top (y=0 is the top edge), down the right.

**Hardware-confirmed (SK0127):** the bring-up chase showed physical LED index 0
at the **bottom-right**, winding up — i.e. an x-mirror of the canonical map —
which matches the owner's real native-app setting of **Right to left**.

## Decision

- `InstallationMethod { horizontal, vertical }` in `AuroraCore` (Codable), with
  per-axis enums whose labels exactly match the vendor UI.
- `LEDLayout.applying(_:)` mirrors **point coordinates** only:
  `x → W-1-x` for Right-to-left, `y → H-1-y` for Top-to-bottom. LED `id`/index
  order is preserved, so the Ada serial frame stays strictly index-ordered.
- Extents (W/H) are derived from the points, not the unreliable vendor
  `screenWidth/Height` JSON fields.
- Default = **Right to left + Top to bottom** = the owner's confirmed setting.

## Consequences

- The transform is layout-layer state used by **screen sync (M3)** sampling; it
  has no effect on uniform modes (circadian, static).
- Involutive per axis; pure function; a live grid preview in Settings reflects it.
- The serial/device layer never needs to know about installation direction.
