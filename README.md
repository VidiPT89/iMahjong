# 🀄 iMahjong — Mahjong Solitaire & 4-Player Riichi for macOS & iOS

> Two games in one: a polished Mahjong Solitaire with provably solvable deals, and a full local 4-player Riichi table with bots — native SwiftUI, for macOS and iOS.

"iMahjong" ships two independent modes that share their tile-rendering code and 34 tile types:

- **Solitaire** — clear a 144-tile turtle pyramid by matching two free tiles at a time. Every deal is generated from a solved state working backwards, so a full clear is always mathematically possible — the same dealing algorithm proven out in the [VidiMahjong](https://github.com/VidiPT89/VidiMahjong) web version, reimplemented natively in Swift.
- **4 Players (Riichi)** — a real local Riichi table: wall, hands, chi/pon/kan, riichi, dora/ura-dora, yaku detection and han/fu scoring. Play 1–4 human seats on one device, pass-and-play style, with bots auto-filling any empty seats.

The interface opens with an animated splash intro, and is fully bilingual (European Portuguese / English), switching instantly and remembering the choice between visits.

## 📦 What's Inside

### Solitaire
- 🎚️ Three difficulty levels — **Easy** (a flat 108-tile suits-only spread, nothing ever covered), **Medium** (the classic 144-tile turtle) and **Hard** (the same 144 tiles stacked taller)
- 🐢 Full turtle-pyramid spreads with proper covered / blocked-side / free tile rules
- ✅ Provably solvable deals — tiles are assigned by walking the board's own removal order backwards, so a complete solve always exists
- 💡 Limited hints that highlight a real playable pair, 🔀 a shuffle that keeps the remaining board solvable, and ↩️ unlimited undo
- 🎬 Smooth SwiftUI animations — lift on select, shake on mismatch, staggered deal-in
- 🏆 Local leaderboard — best time and fewest moves are tracked per difficulty, stored on-device, no account or backend needed
- 🔊 Sound feedback on tile pick, match, mismatch and victory
- 💾 Autosaves mid-game, with a "Continue Game" option from the main menu
- 📖 An in-app "How to Play" guide with a visual diagram of the covered / blocked / free tile rule

### 4 Players (Riichi)
- 🀫 34 tile faces (Characters, Bamboos, Circles, Winds, Dragons, Flowers, Seasons) drawn with CJK glyphs and native SwiftUI shapes — shared with Solitaire, no image assets
- 🎴 Real winning-hand detection — recursive decomposition into 4 sets + pair, plus the special Chiitoitsu (seven pairs) and Kokushi Musou (thirteen orphans) shapes, tried against every possible split so the best-scoring yaku combination wins
- 🀄 Full call support — chi, pon, daiminkan/ankan/shouminkan (open, concealed and added kans), with correct reaction priority (ron > pon/kan > chi)
- 🀚 Riichi declaration (incl. double riichi and ippatsu), dora and ura-dora counting
- 🏅 A wide yaku set — Riichi, Tanyao, Yakuhai, Pinfu, Iipeiko, Sanshoku Doujun/Doukou, Ittsu, Toitoi, Sanankou, Honitsu/Chinitsu, Chanta/Junchan, Shousangen, Haitei/Houtei/Rinshan/Chankan — plus every yakuman (Kokushi, Suuankou, Daisangen, Tsuuiisou, Chinroutou, Ryuuiisou, Suukantsu), with proper han/fu → point conversion and ron/tsumo payment splits
- 🤖 A discard/reaction bot AI that auto-fills any empty seats
- 👥 Local pass-and-play for 1–4 people on one device — no networking, no online rooms
- 🎚️ Configurable seat setup — choose how many seats are human, the rest are bots

### Shared
- 🎞️ Animated splash intro with the developer credit, that hands off into the main menu
- 🇵🇹 🇬🇧 One-click language toggle between European Portuguese and English, remembered between visits
- 🖥️ 📱 One codebase, two native targets — macOS and iOS/iPadOS, both built with SwiftUI

## 🛠️ Tech Stack

![Swift](https://img.shields.io/badge/Swift-F05138?style=flat&logo=swift&logoColor=white)
![SwiftUI](https://img.shields.io/badge/SwiftUI-0066CC?style=flat&logo=swift&logoColor=white)
![iOS](https://img.shields.io/badge/iOS-16%2B-000000?style=flat&logo=apple&logoColor=white)
![macOS](https://img.shields.io/badge/macOS-13%2B-000000?style=flat&logo=apple&logoColor=white)
![xcodegen](https://img.shields.io/badge/xcodegen-project.yml-blue?style=flat)
![XCTest](https://img.shields.io/badge/XCTest-unit%20tests-blue?style=flat)

## 🏗️ Project Structure

```
iMahjong/
├── project.yml               # xcodegen config — iMahjong-iOS, iMahjong-macOS and iMahjongTests targets
├── iMahjong/                 # Shared SwiftUI source for both app targets
│   ├── iMahjongApp.swift      # App entry point
│   ├── Theme.swift            # ividi.dev-matched color tokens
│   ├── Localization.swift     # PT/EN strings and language persistence
│   ├── Models/
│   │   ├── TileType.swift      # 34 tile types, matching rules, pair-unit builders
│   │   └── Tile.swift           # Board position & tile instance types
│   ├── Engine/
│   │   ├── Layout.swift         # Fixed turtle layouts (Easy/Medium/Hard)
│   │   ├── GameEngine.swift     # Solitaire board state, free-tile rules, solvable dealing
│   │   ├── SaveStore.swift      # Mid-game autosave/restore
│   │   ├── Leaderboard.swift    # Local best-time/best-moves records per difficulty
│   │   └── SoundManager.swift   # Tile pick / match / mismatch / win sound feedback
│   ├── Riichi/                 # 4-Player Riichi mode — pure game logic, no UI dependencies
│   │   ├── RiichiTiles.swift     # Standard 136-tile wall, honor/terminal helpers
│   │   ├── HandEval.swift        # Winning-hand decomposition (standard/chiitoitsu/kokushi)
│   │   ├── Yaku.swift             # Yaku detection + fu calculation
│   │   ├── Scoring.swift          # Han/fu → points, ron/tsumo payment split
│   │   ├── RiichiEngine.swift     # Turn engine: draw/discard/chi/pon/kan/riichi, authoritative state
│   │   ├── Bot.swift               # Discard/reaction bot heuristics
│   │   └── LocalMatch.swift        # Chains hands together, drives bots, local pass-and-play
│   ├── Views/
│   │   ├── RootView.swift              # Screen router
│   │   ├── SplashView.swift             # Animated intro with developer credit
│   │   ├── MainMenuView.swift           # Menu, language toggle, difficulty picker
│   │   ├── HowToPlayView.swift           # Rules guide, incl. 4-Player Riichi section
│   │   ├── GameView.swift                 # Solitaire board screen, stats, actions, modals
│   │   ├── TraditionalModeSelectView.swift # 4-Player entry point
│   │   ├── TraditionalSetupView.swift      # Human seat count picker
│   │   ├── TraditionalTableView.swift      # 4-Player table UI
│   │   ├── TileView.swift / TileFaceView.swift  # Tile rendering (shared by both modes)
│   │   ├── BoardGeometry.swift             # Layout → screen coordinate math
│   │   ├── Modals.swift                     # Win / stuck / confirm / leaderboard modals
│   │   └── BackgroundGlow.swift             # Shared theme components
│   └── Assets.xcassets/
├── iMahjongTests/            # XCTest unit tests (solitaire dealing + Riichi hand/yaku eval)
├── LICENSE
└── README.md
```

## ⚙️ Game Mechanics

### Solitaire — solvable dealing
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

### 4 Players — turn engine
```
Draw → (tsumo? / kan?) → discard → reaction window (ron > pon/kan > chi) → next draw

Winning-hand check: recursive decomposition into 4 sets + 1 pair (plus the
special Chiitoitsu / Kokushi Musou shapes), tried against every possible
split so the highest-scoring yaku combination is used.
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

Pick the **iMahjong-iOS** scheme for iPhone/iPad (Simulator or device) or **iMahjong-macOS** for a native Mac app. Both targets share the exact same SwiftUI source. To run the unit tests, select the **iMahjongTests** target (or `Product > Test` / `xcodebuild test`) from either app scheme.

## 📝 Notes

- Flowers and Seasons in Solitaire are special: any Flower matches any other Flower, and any Season matches any other Season, without needing to be identical — matching real Mahjong rules
- The 4-Player mode is entirely local (pass-and-play on one device, with bots filling empty seats) — there is no online/networked play in this Swift version
- The 4-Player mode plays a single East round (one dealer turn per seat) — a common casual "tonpuusen" format
- Yaku scope covers the common competitive set plus all yakuman; a few rare edge cases (e.g. double-yakuman variants counting as a single yakuman) are intentionally simplified — see the doc comment at the top of `Yaku.swift`
- Sound feedback uses `AudioServicesPlaySystemSound` (AudioToolbox) as a placeholder, since the project ships no custom audio assets yet — see the comment in `SoundManager.swift` for how to swap in real `.caf`/`.wav` files via `AVAudioPlayer` later
- Language, best leaderboard scores, hints used and in-progress games are stored locally (`UserDefaults`), so they persist between visits
- The board layout, matching rules and solvable-dealing algorithm mirror the web version at [VidiMahjong](https://github.com/VidiPT89/VidiMahjong), but this is an independent Swift codebase — no code is shared between the two

---

Developed by **David Arsénio Martins** — *"Vidi"*
