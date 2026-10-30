# iVidiMahjong

Native SwiftUI iVidiMahjong for iPhone, iPad and Mac. Requires iOS/iPadOS 16+ or macOS 13+.

- Solitaire: three difficulties, solvable initial deals and reshuffles, hints, undo, autosave, paused timer and local records.
- Levels: 15 increasingly large boards, with progression saved on this device.
- Riichi: 0–4 human seats on one device with a private handoff screen between players, bots for the other seats, and an East round with dealer repeats.
- European Portuguese and English, sound toggle, native tile rendering.

Everything runs on the device: no account, no server and no data collection.

## Build and test

Open `iVidiMahjong.xcodeproj`, then choose `iVidiMahjong-iOS` or `iVidiMahjong-macOS`.
The checked-in Xcode project can be regenerated with `xcodegen generate` from `project.yml`.
Choose your signing team in Xcode for physical-device builds.

```sh
# Core tests, no app or simulator required (macOS)
swift test

# Full native build/test
xcodebuild -project iVidiMahjong.xcodeproj -scheme iVidiMahjong-macOS \
  -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test
xcodebuild -project iVidiMahjong.xcodeproj -scheme iVidiMahjong-iOS \
  -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Rules and limits

This is a casual Riichi implementation, not a certified tournament ruleset. Both engines implement common yaku, seven pairs, thirteen orphans, dora/ura-dora, chi/pon/open and concealed kan, riichi discard locking, furiten and han/fu payments. Winning decompositions and winning-tile placements are evaluated for the highest score.

Deliberate limits: no added kan/chankan, no kan after riichi, no abortive draws, no honba payments, no red fives, no liability payments, and no complete tournament-yakuman set (for example, four winds and nine gates are not implemented). Multiple ron pays every winner. Riichi requires 1,000 points and four tiles remaining. Double-yakuman variants count once, and mangan is capped without kiriage rounding.

Rule reference used during review: [European Mahjong Association Riichi rules](https://mahjong-europe.org/portal/images/docs/Riichi-rules-2025-EN.pdf). This reference does not imply full compliance; the limits above apply.

## Compatibility and repository name

The app, source directory, module, project and schemes are named **iVidiMahjong**. The bundle identifier is `dev.ividi.ividimahjong`; preference keys use `ividimahjong-*`. This replaces the previous installation identity and preference namespace.

The remote repository was originally `VidiPT89/iMahjong`. Its GitHub rename and pushes require network access; see the dated audit for the confirmed publication state.

## Verification

See [the 2026-10-29 audit](docs/2026-10-29-audit.md) for fixes, evidence and remaining checks. Passing core tests does not replace testing the native interface on devices.

Developed by David Arsénio Martins (Vidi), [ividi.dev](https://ividi.dev).
