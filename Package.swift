// swift-tools-version: 5.9
import PackageDescription

// Headless core tests run on macOS without launching an application or simulator.
let package = Package(
    name: "iVidiMahjong",
    platforms: [.macOS(.v13)],
    products: [.library(name: "iVidiMahjong", targets: ["iVidiMahjong"])],
    targets: [
        .target(name: "iVidiMahjong", path: "iVidiMahjong",
                exclude: ["Views", "Assets.xcassets", "Theme.swift", "Localization.swift", "iVidiMahjongApp.swift", "Engine/SoundManager.swift", "PrivacyInfo.xcprivacy"]),
        .testTarget(name: "iVidiMahjongTests", dependencies: ["iVidiMahjong"], path: "iVidiMahjongTests")
    ]
)
