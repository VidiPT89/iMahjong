import SwiftUI

enum Theme {
    static let bg = Color(red: 0x0a / 255.0, green: 0x0a / 255.0, blue: 0x0f / 255.0)
    static let bgPanel = Color(red: 0x0d / 255.0, green: 0x0d / 255.0, blue: 0x18 / 255.0)
    static let bgPanel2 = Color(red: 0x12 / 255.0, green: 0x12 / 255.0, blue: 0x1f / 255.0)
    static let border = Color(red: 226 / 255.0, green: 232 / 255.0, blue: 240 / 255.0).opacity(0.10)
    static let borderStrong = Color(red: 226 / 255.0, green: 232 / 255.0, blue: 240 / 255.0).opacity(0.18)
    static let text = Color(red: 0xe2 / 255.0, green: 0xe8 / 255.0, blue: 0xf0 / 255.0)
    static let textDim = Color(red: 0x94 / 255.0, green: 0xa3 / 255.0, blue: 0xb8 / 255.0)
    static let textFaint = Color(red: 0x5b / 255.0, green: 0x64 / 255.0, blue: 0x74 / 255.0)
    static let accent = Color(red: 0xf5 / 255.0, green: 0x9e / 255.0, blue: 0x0b / 255.0)
    static let accentLight = Color(red: 0xfb / 255.0, green: 0xbf / 255.0, blue: 0x24 / 255.0)
    static let accentDark = Color(red: 0xb4 / 255.0, green: 0x53 / 255.0, blue: 0x09 / 255.0)
    static let accentGlow = Color(red: 0xf5 / 255.0, green: 0x9e / 255.0, blue: 0x0b / 255.0).opacity(0.35)
    static let danger = Color(red: 0xef / 255.0, green: 0x44 / 255.0, blue: 0x44 / 255.0)
    static let ok = Color(red: 0x22 / 255.0, green: 0xc5 / 255.0, blue: 0x5e / 255.0)

    static let charInk = Color(red: 0xc0 / 255.0, green: 0x39 / 255.0, blue: 0x2b / 255.0)
    static let bambooInk = Color(red: 0x2f / 255.0, green: 0x9e / 255.0, blue: 0x5c / 255.0)
    static let bambooGold = Color(red: 0xc9 / 255.0, green: 0x93 / 255.0, blue: 0x2c / 255.0)
    static let circleBlue = Color(red: 0x1d / 255.0, green: 0x5f / 255.0, blue: 0xa8 / 255.0)
    static let circleRed = Color(red: 0xc0 / 255.0, green: 0x39 / 255.0, blue: 0x2b / 255.0)
    static let circleGreen = Color(red: 0x1f / 255.0, green: 0x7a / 255.0, blue: 0x4d / 255.0)
    static let glyphDark = Color(red: 0x1a / 255.0, green: 0x22 / 255.0, blue: 0x33 / 255.0)
    static let dragonRed = Color(red: 0xc0 / 255.0, green: 0x39 / 255.0, blue: 0x2b / 255.0)
    static let dragonGreen = Color(red: 0x1f / 255.0, green: 0x7a / 255.0, blue: 0x4d / 255.0)
    static let bonusPink = Color(red: 0xd1 / 255.0, green: 0x47 / 255.0, blue: 0x7a / 255.0)
    static let bonusBlue = Color(red: 0x1d / 255.0, green: 0x5f / 255.0, blue: 0xa8 / 255.0)
    static let tileFace = Color(red: 0.96, green: 0.94, blue: 0.88)
    static let tileFaceShade = Color(red: 0.88, green: 0.85, blue: 0.78)
    static let tileEdge = Color(red: 0.55, green: 0.50, blue: 0.40)

    static let radius: CGFloat = 10
    static let ease: Animation = .timingCurve(0.22, 1, 0.36, 1, duration: 0.35)
}
