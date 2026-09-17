# LifeTrack

Personal iPhone app for tracking food, habits, money, and whatever else comes up.
One user. Sideloaded through SideStore, never the App Store.

## Design language

Clean and minimalistic, in black and white.

- Monochrome only: black, white, and grays. No accent colors. Hierarchy comes from
  weight, size, and spacing, not color.
- Black on white in light mode, white on black in dark mode. State and progress are
  shown with gray fills, strokes, and opacity.
- Generous space between groups, tight within them. Content starts right under the
  status bar using `ScreenHeader`; no navigation bar large titles.
- One primary action per screen, a plain glyph button. Quick input happens in a
  drawer over the current screen, not on a new screen.
- System fonts and SF Symbols. No gradients, shadows, illustrations, or decoration.
- A flow should finish in a couple of taps. If a screen needs explaining, simplify it.

When adding or changing UI, follow this even where existing screens don't yet.

## Build and run

Plain SwiftPM plus a Makefile. There is no Xcode project; Xcode.app is installed only
for the iOS SDK and the Makefile points at it directly.

- `make sim` builds, installs, and launches on the iPhone 18 Pro simulator.
- `make ipa` builds the unsigned IPA for the phone. SideStore signs it on device.
- `make release` builds, publishes a GitHub Release, and updates `source.json`, the
  SideStore feed the phone polls. Needs a clean tree on `main`.
- Launch arguments for headless screenshots: `--tab=money|habits|food|status`,
  `--demo-food`, `--show=add|voice`. Screenshot with
  `xcrun simctl io "iPhone 18 Pro" screenshot out.png`.

## Layout

- `Sources/LifeTrack/` is the SwiftUI app. `Food/` is the food tab. `Views/` holds
  shared views such as `ScreenHeader` and the tab shell.
- `Store.swift` opens the single SQLite database. Persistence is added per feature as
  each one is built.
- Privacy strings in `Resources/Info.plist` must be mirrored in `source.json` under
  `appPermissions.privacy`.

## Constraints

- Deployment target is iOS 26. Use current APIs: `SpeechAnalyzer` for speech, not
  `SFSpeechRecognizer`; the `Tab` API; `@Observable`.
- Signed with a free Personal Team via SideStore, so no iCloud, push, or other
  entitlements. Data lives on the phone unless a feature syncs it explicitly.
- The Simulator has no camera and no on-device speech model. Those flows only run on
  the phone; the Simulator shows their failure states.
