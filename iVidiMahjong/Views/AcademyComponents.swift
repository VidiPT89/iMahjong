import SwiftUI

extension Bilingual {
    func callAsFunction(_ lang: Lang) -> String { lang == .pt ? pt : en }
}

/// A study tile: the engraved artwork with a small rank index, so suits can be counted at
/// a glance while learning. Optional outline marks right/wrong answers.
struct StudyTile: View {
    let typeId: String
    var width: CGFloat = 40
    var outline: Color?
    var dimmed = false

    var body: some View {
        let height = width * 256 / 192
        TraditionalTileArtwork(typeID: typeId)
            .scaleEffect(width / 192)
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: width * 0.14))
            .overlay(alignment: .topLeading) {
                if let type = TILE_TYPES_BY_ID[typeId], type.category == .suit, type.suit != .characters, let rank = type.rank {
                    Text("\(rank)").font(.system(size: max(8, width * 0.24), weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.glyphDark).padding(.horizontal, 2)
                        .background(RoundedRectangle(cornerRadius: 2).fill(Theme.tileFace.opacity(0.9)))
                        .padding(2)
                }
            }
            .background(RoundedRectangle(cornerRadius: width * 0.14).fill(Color(red: 0.54, green: 0.32, blue: 0.12)).offset(y: width * 0.08))
            .overlay(RoundedRectangle(cornerRadius: width * 0.14).stroke(outline ?? Color.black.opacity(0.25), lineWidth: outline == nil ? 0.5 : 3))
            .opacity(dimmed ? 0.4 : 1)
            .padding(.bottom, width * 0.08)
            .accessibilityElement()
            .accessibilityLabel(tileAccessibilityName(typeId, Localization.shared))
    }
}

/// A row of tiles that shrinks to fit the available width (up to `maxTile` wide).
struct TileRow: View {
    let tiles: [String]
    var maxTile: CGFloat = 46
    var outline: (Int) -> Color? = { _ in nil }
    var dimmed: (Int) -> Bool = { _ in false }
    var onTap: ((Int) -> Void)?

    var body: some View {
        GeometryReader { geo in
            let spacing: CGFloat = 3
            let count = CGFloat(max(tiles.count, 1))
            let width = min(maxTile, (geo.size.width - spacing * (count - 1)) / count)
            HStack(spacing: spacing) {
                ForEach(Array(tiles.enumerated()), id: \.offset) { index, tile in
                    let face = StudyTile(typeId: tile, width: width, outline: outline(index), dimmed: dimmed(index))
                    if let onTap {
                        Button(action: { onTap(index) }) { face }.buttonStyle(.plain).accessibilityIdentifier("drill-tile")
                    } else {
                        face
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: rowHeight)
    }

    private var rowHeight: CGFloat { maxTile * 256 / 192 * 1.1 }
}

struct AcademyCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) { content }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 14).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.border, lineWidth: 1)))
    }
}

struct ScreenHeader: View {
    let title: String
    let onBack: () -> Void

    var body: some View {
        HStack {
            BackButton(action: onBack)
            Spacer()
            Text(title).font(.system(size: 17, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
            Spacer()
            Color.clear.frame(width: 44, height: 44)
        }
        .padding(.horizontal).padding(.vertical, 8)
    }
}

struct SectionLabel: View {
    let text: String

    var body: some View {
        Text(text).font(.system(size: 11, weight: .bold, design: .rounded)).tracking(1.5)
            .foregroundColor(Theme.accent).textCase(.uppercase)
    }
}

/// Each yaku of a won hand with its han and a one-line reason, used in drills and at the table.
struct YakuExplanationList: View {
    let yakuList: [YakuEntry]
    let lang: Lang

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(Array(yakuList.enumerated()), id: \.offset) { _, yaku in
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(yakuDisplayName(yaku.name)) · \(yaku.han) han").font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundColor(Theme.text)
                    if let why = YAKU_EXPLANATIONS[yakuExplanationKey(yaku.name)] {
                        Text(why(lang)).font(.system(size: 12, design: .rounded)).foregroundColor(Theme.textDim)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// "Yakuhai (dW)" → "Yakuhai (White dragon)": the engine keys yakuhai by tile id.
func yakuDisplayName(_ name: String) -> String {
    guard name.hasPrefix("Yakuhai ("), name.hasSuffix(")") else { return name }
    let tile = String(name.dropFirst("Yakuhai (".count).dropLast())
    return "Yakuhai (\(tileAccessibilityName(tile, Localization.shared)))"
}

func waitShapeName(_ shape: WaitShape, _ lang: Lang) -> String {
    let pt: [WaitShape: String] = [.ryanmen: "dois lados (ryanmen)", .kanchan: "do meio (kanchan)", .penchan: "de ponta (penchan)", .shanpon: "dois pares (shanpon)", .tanki: "ficha isolada (tanki)"]
    let en: [WaitShape: String] = [.ryanmen: "two-sided (ryanmen)", .kanchan: "middle (kanchan)", .penchan: "edge (penchan)", .shanpon: "two pairs (shanpon)", .tanki: "single tile (tanki)"]
    return (lang == .pt ? pt : en)[shape] ?? shape.rawValue
}

func fuPartLabel(_ part: FuPart, _ loc: Localization) -> String {
    let pt = loc.lang == .pt
    switch part {
    case .base(let fu): return pt ? "Base: \(fu) fu" : "Base: \(fu) fu"
    case .pinfu(let fu): return pt ? "Pinfu: sempre \(fu) fu" : "Pinfu: always \(fu) fu"
    case .sevenPairs: return pt ? "Sete pares: sempre 25 fu" : "Seven pairs: always 25 fu"
    case .closedRon: return pt ? "Ron com mão fechada: +10" : "Closed Ron: +10"
    case .tsumo: return pt ? "Tsumo: +2" : "Tsumo: +2"
    case .triplet(let tile, let concealed, let fu):
        let name = tileAccessibilityName(tile, loc)
        if concealed { return pt ? "Trinca escondida de \(name): +\(fu)" : "Concealed triplet of \(name): +\(fu)" }
        return pt ? "Trinca de \(name) completada por Ron (conta como aberta): +\(fu)" : "Triplet of \(name) completed by Ron (counts as open): +\(fu)"
    case .valuePair(let tile, let fu):
        return pt ? "Par de \(tileAccessibilityName(tile, loc)): +\(fu)" : "Pair of \(tileAccessibilityName(tile, loc)): +\(fu)"
    case .wait(let shape, let fu):
        let shapeName = waitShapeName(shape, loc.lang)
        return pt ? "Espera \(shapeName): +\(fu)" : "\(shapeName.prefix(1).uppercased() + shapeName.dropFirst()) wait: +\(fu)"
    }
}
