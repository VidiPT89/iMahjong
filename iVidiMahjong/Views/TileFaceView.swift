import SwiftUI

/// Localization key for a seat/round wind id ("wE" → "windE").
func windLabelKey(_ windId: String?) -> String {
    ["wE": "windE", "wS": "windS", "wW": "windW", "wN": "windN"][windId ?? ""] ?? "windE"
}

/// Spoken name of a tile for VoiceOver, e.g. "Bamboo 3" or "East wind".
func tileAccessibilityName(_ typeId: String, _ loc: Localization) -> String {
    guard let type = TILE_TYPES_BY_ID[typeId] else { return typeId }
    switch type.category {
    case .suit:
        let suitKey: String
        switch type.suit! {
        case .characters: suitKey = "tileCharacters"
        case .bamboo: suitKey = "tileBamboo"
        case .circle: suitKey = "tileCircle"
        }
        return "\(loc.t(suitKey)) \(type.rank!)"
    case .wind: return loc.t(windLabelKey(typeId))
    case .dragon: return loc.t(["dR": "tileDragonRed", "dG": "tileDragonGreen"][typeId] ?? "tileDragonWhite")
    case .flower: return "\(loc.t("tileFlower")) \(type.rank!)"
    case .season: return "\(loc.t("tileSeason")) \(type.rank!)"
    }
}

/// Small read-only tile used for melds, discards, dora and call choices at the Riichi tables.
struct MiniTileChip: View {
    let typeId: String
    var width: CGFloat = 22

    var body: some View {
        TileFaceView(typeId: typeId)
            .frame(width: width, height: width * 30 / 22)
            .background(RoundedRectangle(cornerRadius: 3).fill(Theme.tileFace))
            .overlay(RoundedRectangle(cornerRadius: 3).stroke(Theme.tileEdge, lineWidth: 0.5))
    }
}

/// Renders the printed face of a tile type — CJK glyphs and simple vector pips, no image assets.
struct TileFaceView: View {
    let typeId: String

    var body: some View {
        guard let type = TILE_TYPES_BY_ID[typeId] else { return AnyView(EmptyView()) }
        switch type.category {
        case .suit:
            switch type.suit! {
            case .characters: return AnyView(charactersFace(rank: type.rank!))
            case .bamboo: return AnyView(pipFace(rank: type.rank!, kind: .bamboo))
            case .circle: return AnyView(pipFace(rank: type.rank!, kind: .circle))
            }
        case .wind:
            let kanji = ["wE": "東", "wS": "南", "wW": "西", "wN": "北"][typeId] ?? "?"
            return AnyView(soloGlyph(kanji, color: Theme.glyphDark))
        case .dragon:
            if typeId == "dR" { return AnyView(soloGlyph("中", color: Theme.dragonRed)) }
            if typeId == "dG" { return AnyView(soloGlyph("發", color: Theme.dragonGreen)) }
            // dW (white dragon / haku) is conventionally blank in real sets.
            return AnyView(RoundedRectangle(cornerRadius: 3).stroke(Theme.tileEdge.opacity(0.4), lineWidth: 2).padding(6))
        case .flower:
            let kanji = ["fl1": "梅", "fl2": "蘭", "fl3": "竹", "fl4": "菊"][typeId] ?? "?"
            return AnyView(bonusGlyph(kanji, number: type.rank!, color: Theme.bonusPink))
        case .season:
            let kanji = ["se1": "春", "se2": "夏", "se3": "秋", "se4": "冬"][typeId] ?? "?"
            return AnyView(bonusGlyph(kanji, number: type.rank!, color: Theme.bonusBlue))
        }
    }

    private func charactersFace(rank: Int) -> some View {
        VStack(spacing: 0) {
            Text(numerals[rank])
                .font(.system(size: 15, weight: .bold))
                .foregroundColor(Theme.charInk)
            Text("萬")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(Theme.glyphDark)
        }
    }

    private func soloGlyph(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 26, weight: .semibold))
            .foregroundColor(color)
    }

    private func bonusGlyph(_ text: String, number: Int, color: Color) -> some View {
        ZStack(alignment: .topTrailing) {
            Text(text)
                .font(.system(size: 24, weight: .semibold))
                .foregroundColor(color)
            Text("\(number)")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(color)
                .offset(x: 6, y: -2)
        }
    }

    private enum PipKind { case bamboo, circle }

    private func pipFace(rank: Int, kind: PipKind) -> some View {
        let rows = pipRows[rank] ?? [1]
        return GeometryReader { geo in
            let rowH = geo.size.height / CGFloat(rows.count)
            ZStack(alignment: .topLeading) {
                ForEach(Array(rows.enumerated()), id: \.offset) { ri, count in
                    let colW = geo.size.width / CGFloat(count)
                    ForEach(0..<count, id: \.self) { ci in
                        pip(kind: kind, rank: rank, rowIndex: ri, colIndex: ci)
                            .frame(width: colW * 0.78, height: rowH * 0.78)
                            .position(x: colW * CGFloat(ci) + colW / 2, y: rowH * CGFloat(ri) + rowH / 2)
                    }
                }
            }
        }
        .padding(4)
    }

    private static let circleColors: [Color] = [Theme.circleBlue, Theme.circleRed, Theme.circleGreen]

    @ViewBuilder
    private func pip(kind: PipKind, rank: Int, rowIndex: Int, colIndex: Int) -> some View {
        switch kind {
        case .circle:
            let color = Self.circleColors[(rowIndex + colIndex) % Self.circleColors.count]
            Circle()
                .fill(color)
                .overlay(Circle().stroke(Color.black.opacity(0.35), lineWidth: 0.6))
                .overlay(
                    Circle().fill(Color.white.opacity(0.55)).frame(width: 3, height: 3).offset(x: -2, y: -2)
                )
        case .bamboo:
            let color = rank == 1 ? Theme.bambooGold : Theme.bambooInk
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .overlay(
                    VStack(spacing: 0) {
                        Rectangle().fill(Color.black.opacity(0.25)).frame(height: 0.6)
                        Spacer()
                        Rectangle().fill(Color.black.opacity(0.25)).frame(height: 0.6)
                    }
                )
        }
    }
}
