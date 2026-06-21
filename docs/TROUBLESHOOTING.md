# Troubleshooting

Quick fixes for the most common issues after you've installed your strip and
opened Aurora. Most problems are one of: the **native Skydimo app still holding
the USB port**, a **missing macOS permission**, or the **installation direction**.

> **First, find your setup.** Open Aurora → **Open Aurora…**. The bottom line
> shows your device, e.g. `Device: SK0127 · 65 LEDs · /dev/cu.usbserial-…`.
> If it says **"Preview only"**, the controller wasn't detected — see below.

---

### "Aurora can't be opened" / "unidentified developer"

The build is ad-hoc signed (not yet notarized), so Gatekeeper blocks the first
open.

- **Right-click** Aurora.app → **Open** → **Open** in the dialog. You only do
  this once.
- If macOS says the app is "damaged", run once in Terminal:
  `xattr -dr com.apple.quarantine /Applications/Aurora.app`

### The strip isn't detected ("Preview only")

1. **Quit the official Skydimo app completely.** The USB port is exclusive — only
   one app can hold it. Quit Skydimo from its menu-bar/Dock icon, then in Aurora
   the device should appear within a second (it auto-reconnects).
2. **Check the cable/port.** Use the data USB cable that came with the strip
   (some cables are power-only) and try another USB port.
3. **Replug** the controller, wait a few seconds.
4. Confirm your model is supported — see [COMPATIBILITY](COMPATIBILITY.md). If the
   device line never shows an `SK####`, the controller may be a model Aurora
   doesn't know yet — please [report it](#reporting-a-bug).

### Colors are wrong (e.g. red looks green)

Aurora currently assumes **RGB** channel order (verified on SK0127). Some strips
use **GRB**, which swaps red and green.

- This needs a small per-model fix. Please [report](#reporting-a-bug) your model
  id and which colors you actually saw for a red / green / blue test.

### The effect is mirrored or upside-down (Screen / Music)

Red on the wrong side, or the Music "Level" meter rising the wrong way? That's the
**installation direction** — how your strip is physically wound around the screen.

- **Open Aurora… → Installation method.** Flip **Left to right ↔ Right to left**
  (and **Bottom ↔ Top**). The strip updates live; match the little **grid preview**
  (big dot = where the strip starts) to your real strip. This orients **both**
  Screen Sync and Music Sync.

### Screen Sync or Music Sync does nothing

Both need macOS **Screen Recording** permission (Music Sync uses it to capture
**system audio**).

1. Switch to **Screen** or **Music** — Aurora should prompt for Screen Recording.
2. Open **System Settings → Privacy & Security → Screen & System Audio Recording**
   and enable **Aurora**.
3. **Quit Aurora and reopen it.** ⚠️ Screen Recording only takes effect after a
   relaunch — this is the step macOS doesn't make obvious.
4. Make sure audio is actually playing through your Mac's normal output (Music
   Sync listens to system audio, not a separate audio device), and nudge the
   **Sensitivity** slider.

### There are several "Aurora" entries, or permission keeps resetting

This happens if you ran more than one copy (e.g. a `dist/` build and the
`/Applications` one) — each has its own identity.

- Keep a **single** copy in `/Applications`. Then reset and re-grant:
  - Terminal: `tccutil reset ScreenCapture com.evgenypopov.aurora`
  - Reopen Aurora, grant the (now single) prompt, **quit & reopen**.

### The strip turns off, flickers, or freezes

This was an early bug and is fixed (Aurora streams continuously). If you still see
it, note what you were doing and [report it](#reporting-a-bug) — include your
macOS version and model.

### Part of the strip is dark / wrong number of LEDs lit

Aurora drives exactly the LED count it detected (shown on the device line). If
that count doesn't match your strip, the model mapping may be off — please
[report](#reporting-a-bug) the model id and your strip's real LED count.

### Circadian looks too warm/cool for the time of day

Circadian follows the sun for your location.

- Set your location: **Open Aurora… → Circadian → Use my location** (or it
  defaults to a generic location). At high latitudes in summer ("white nights")
  the night never goes fully warm in **Auto** — use the **Night** override to
  force your warm color, and tune the **Night** Kelvin slider.

---

## Reporting a bug

If self-serve didn't help, open an issue:
**https://github.com/b0ver/aurora/issues**

Please include:

- **macOS version** (e.g. 14.5) and Mac (Apple Silicon / Intel).
- **Controller model + LED count** — copy the device line from *Open Aurora…*
  (e.g. `SK0127 · 65 LEDs`). If it says "Preview only", say so.
- **Which mode** and what you expected vs. what happened.
- For wrong colors: what color the strip showed for a **red / green / blue** test.
- For "not detected": whether the official Skydimo app was fully quit.

The more of the above you include, the faster it's fixable. Thank you!
