# ADR-0002: Build with Swift Package Manager; package the app via script

- Status: Accepted
- Date: 2026-06-20

## Context

The dev machine has the **Swift toolchain via Command Line Tools** but **not the
full Xcode** (`xcodebuild` unavailable). The build must be reproducible and
drivable headlessly (the project is developed by AI agents from the CLI).

A menu-bar SwiftUI app still needs an `.app` bundle with an `Info.plist`
(`LSUIElement` to run as an agent without a Dock icon, usage-description keys for
microphone/screen capture).

## Decision

- Use **Swift Package Manager** with a multi-module package (one library target
  per layer + one `executableTarget` for the app). Build with `swift build`.
- Produce the distributable bundle with **`Scripts/package_app.sh`**, which
  assembles `dist/Aurora.app/Contents/{MacOS,Resources,Info.plist}`, copies the
  built executable, and writes the `Info.plist` (LSUIElement = true, usage
  strings, bundle id `com.evgenypopov.aurora`).
- Keep `Info.plist` source-controlled as a template under `Scripts/`.

## Consequences

- Fully CLI-buildable, no Xcode GUI needed for development.
- **Code signing / notarization / App Store** later will require full Xcode (or
  `codesign`/`notarytool`). Tracked as a release-phase risk in the roadmap.
- Asset catalogs (`.xcassets`) are not used; the app icon and resources are
  copied as plain files by the package script.
- We avoid committing a fragile `.pbxproj`. If a contributor wants Xcode, SwiftPM
  packages open directly in Xcode with no project file.

## Risk

- Some Apple frameworks behave slightly differently when run as a bare SPM
  executable vs. a bundled `.app` (menu-bar presentation, TCC permission
  prompts). Mitigation: always test the **packaged** bundle for runtime/UX, use
  `swift build`/tests for logic.
