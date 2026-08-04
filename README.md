# 🀄 iMahjong — Mahjong Solitaire for macOS & iOS

> A native SwiftUI take on Mahjong Solitaire — the same provably solvable 144-tile turtle spread, rebuilt from scratch in Swift for macOS and iOS.

"iMahjong" clears a 144-tile turtle pyramid by matching two free tiles at a time. Every deal is generated from a solved state working backwards, so a full clear is always mathematically possible — the same dealing algorithm proven out in the [VidiMahjong](https://github.com/VidiPT89/VidiMahjong) web version, reimplemented natively in Swift.

## 📦 What's Inside

- 🐢 Full 144-tile "turtle" pyramid spread across 5 layers, with proper covered / blocked / free tile rules
- ✅ Provably solvable deals — tiles are assigned by walking the board's own removal order backwards, so a complete solve always exists
- 💡 Limited hints that highlight a real playable pair, 🔀 a shuffle that keeps the remaining board solvable, and ↩️ unlimited undo
- 🎬 Smooth SwiftUI animations — lift on select, shake on mismatch, staggered deal-in
- 🀫 34 tile faces (Characters, Bamboos, Circles, Winds, Dragons, Flowers, Seasons) drawn with CJK glyphs and native SwiftUI shapes — no image assets
- 💾 Autosaves mid-game, with a "Continue Game" option from the main menu
- 📖 An in-app "How to Play" guide with a visual diagram of the covered / blocked / free tile rule
- 🇵🇹 🇬🇧 One-click language toggle between European Portuguese and English, remembered between visits
- 🖥️ 📱 One codebase, two native targets — macOS and iOS/iPadOS, both built with SwiftUI

## 🛠️ Tech Stack

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0066CC?style=flat&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-16%2B-000000?style=flat&logo=apple&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-13%2B-000000?style=flat&logo=apple&logoColor=white)
![xcodegen](https://img.shields.io/badge/xcodegen-project.yml-blue?style=flat)

## 🏗️ Project Structure

```
iMahjong/
├── project.yml              # xcodegen config — iMahjong-iOS and iMahjong-macOS targets
├── iMahjong/                # Shared SwiftUI source for both targets
│   ├── iMahjongApp.swift     # App entry point
│   ├── Theme.swift           # ividi.dev-matched color tokens
│   ├── Localization.swift    # PT/EN strings and language persistence
│   ├── Models/
│   │   ├── TileType.swift     # 34 tile types, matching rules, pair-unit builders
│   │   └── Tile.swift          # Board position & tile instance types
│   ├── Engine/
│   │   ├── Layout.swift        # Fixed 144-position turtle layout
│   │   ├── GameEngine.swift    # Board state, free-tile rules, solvable dealing
│   │   └── SaveStore.swift     # Mid-game autosave/restore
│   ├── Views/
│   │   ├── RootView.swift          # Screen router (splash/menu/how-to-play/game)
│   │   ├── SplashView.swift         # Animated intro with developer credit
│   │   ├── MainMenuView.swift       # Menu, language toggle
│   │   ├── HowToPlayView.swift      # Rules guide with visual diagrams
│   │   ├── GameView.swift            # Board screen, stats, actions, modals
│   │   ├── TileView.swift             # Individual tile rendering & animations
│   │   ├── TileFaceView.swift         # CJK glyph / pip tile face rendering
│   │   ├── BoardGeometry.swift        # Layout → screen coordinate math
│   │   ├── Modals.swift               # Win / stuck / confirm modals
│   │   └── BackgroundGlow.swift       # Shared theme components
│   └── Assets.xcassets/
├── LICENSE
└── README.md
```

## ⚙️ Game Mechanics

```
Free tile rule:
  a tile is FREE only if:
    - no other tile occupies the same (x, y) at a higher layer, AND
    - its left OR right neighbour (same layer, same row) is empty

Dealing a solvable board:
  1. walk every board position, repeatedly pairing up whichever tiles are
     currently free (given only the positions not yet paired)
  2. assign each matching pair-unit of tile types to one such pair
  3. because freeness only depends on position — never on tile type —
     replaying that same pairing order back is always a valid full solve
```

## 🚀 How to Run

```bash
# 1. Clone the repository
git clone https://github.com/VidiPT89/iMahjong.git
cd iMahjong

# 2. Generate the Xcode project (requires xcodegen: brew install xcodegen)
xcodegen generate

# 3. Open in Xcode and run either scheme
open iMahjong.xcodeproj
```

Pick the **iMahjong-iOS** scheme for iPhone/iPad (Simulator or device) or **iMahjong-macOS** for a native Mac app. Both targets share the exact same SwiftUI source.

## 📝 Notes

- Flowers and Seasons are special: any Flower matches any other Flower, and any Season matches any other Season, without needing to be identical — matching real Mahjong rules
- Language, hints used and in-progress games are stored locally, so they persist between visits
- The board layout, matching rules and solvable-dealing algorithm mirror the web version at [VidiMahjong](https://github.com/VidiPT89/VidiMahjong), but this is an independent Swift codebase — no code is shared between the two

---

Developed by **David Arsénio Martins** — *"Vidi"*
