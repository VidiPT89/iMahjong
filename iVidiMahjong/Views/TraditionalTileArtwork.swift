import SwiftUI

/// Large, traditional engraved motifs, drawn at texture resolution rather than
/// enlarging small interface icons. The same artwork is used on the menu samples.
struct TraditionalTileArtwork: View {
    let typeID: String
    private let red = Color(red: 0.55, green: 0.08, blue: 0.045)
    private let green = Color(red: 0.055, green: 0.25, blue: 0.15)
    private let blue = Color(red: 0.055, green: 0.16, blue: 0.25)
    private var type: TileType? { TILE_TYPES_BY_ID[typeID] }

    var body: some View {
        ZStack {
            Color(red: 0.91, green: 0.86, blue: 0.72)
            LinearGradient(colors: [.white.opacity(0.12), .clear, Color.brown.opacity(0.04)], startPoint: .topLeading, endPoint: .bottomTrailing)
            Canvas { context, size in
                for i in 0..<1500 {
                    let x = CGFloat((i * 73 + 17) % 193)
                    let y = CGFloat((i * 137 + 31) % 257)
                    context.fill(Path(ellipseIn: CGRect(x: x, y: y, width: 0.6, height: 0.6)), with: .color(.brown.opacity(0.08)))
                }
            }
            motif.padding(.horizontal, 17).padding(.vertical, 20)
                .shadow(color: Color(red: 0.3, green: 0.2, blue: 0.1).opacity(0.22), radius: 0.5, x: 0.4, y: 0.8)
        }.frame(width: 192, height: 256)
    }

    @ViewBuilder private var motif: some View {
        if let type {
            switch type.category {
            case .suit:
                if type.suit == .characters {
                    VStack(spacing: -5) {
                        Text(numerals[type.rank ?? 1]).font(.system(size: 76, weight: .medium, design: .serif)).foregroundColor(blue)
                        Text("萬").font(.system(size: 112, weight: .medium, design: .serif)).foregroundColor(red)
                    }
                } else {
                    pips(rank: type.rank ?? 1, bamboo: type.suit == .bamboo)
                }
            case .wind:
                Text(["wE":"東", "wS":"南", "wW":"西", "wN":"北"][typeID] ?? "東")
                    .font(.system(size: 142, weight: .medium, design: .serif)).foregroundColor(blue)
            case .dragon:
                if typeID == "dW" {
                    RoundedRectangle(cornerRadius: 5).stroke(blue, lineWidth: 7).padding(13)
                        .overlay(RoundedRectangle(cornerRadius: 2).stroke(blue.opacity(0.7), lineWidth: 2).padding(23))
                } else {
                    Text(typeID == "dR" ? "中" : "發")
                        .font(.system(size: 142, weight: .medium, design: .serif)).foregroundColor(typeID == "dR" ? red : green)
                }
            case .flower, .season:
                VStack(spacing: 5) {
                    botanical
                    Text(type.category == .flower ? "花" : "季")
                        .font(.system(size: 42, weight: .medium, design: .serif)).foregroundColor(type.category == .flower ? red : blue)
                }
            }
        }
    }

    private func pips(rank: Int, bamboo: Bool) -> some View {
        GeometryReader { geo in
            let rows = pipRows[rank] ?? [1]
            let rowHeight = geo.size.height / CGFloat(rows.count)
            ForEach(Array(rows.enumerated()), id: \.offset) { row, count in
                let colWidth = geo.size.width / CGFloat(count)
                ForEach(0..<count, id: \.self) { col in
                    Group {
                        if bamboo {
                            bambooStalk
                                .frame(width: min(32, colWidth * 0.55), height: min(rank == 1 ? 168 : 70, rowHeight * 0.84))
                        } else {
                            rosette(color: (rank == 1 || (row + col) % 3 == 0) ? red : ((row + col) % 3 == 1 ? green : blue))
                                .frame(width: min(124, colWidth * 0.87, rowHeight * 0.87), height: min(124, colWidth * 0.87, rowHeight * 0.87))
                        }
                    }.position(x: colWidth * (CGFloat(col) + 0.5), y: rowHeight * (CGFloat(row) + 0.5))
                }
            }
        }
    }

    private var bambooStalk: some View {
        GeometryReader { geo in
            ZStack {
                Capsule().fill(green)
                Capsule().fill(Color(red: 0.40, green: 0.53, blue: 0.28)).frame(width: geo.size.width * 0.30).offset(x: -geo.size.width * 0.15)
                VStack {
                    ForEach(0..<3) { _ in
                        RoundedRectangle(cornerRadius: 1).fill(green.opacity(0.95)).frame(height: 5)
                            .overlay(Rectangle().fill(Color(red: 0.81, green: 0.77, blue: 0.53)).frame(height: 1).offset(y: -1))
                        Spacer(minLength: 0)
                    }
                }.padding(.vertical, 5)
            }
        }
    }

    private func rosette(color: Color) -> some View {
        GeometryReader { geo in
            let d = geo.size.width
            ZStack {
                Circle().stroke(color, lineWidth: max(2, d * 0.055))
                Circle().stroke(color, lineWidth: max(1, d * 0.025)).padding(d * 0.11)
                ForEach(0..<8) { petal in
                    Ellipse().stroke(color, lineWidth: max(1, d * 0.022))
                        .frame(width: d * 0.17, height: d * 0.34)
                        .offset(y: -d * 0.20)
                        .rotationEffect(.degrees(Double(petal) * 45))
                }
                Circle().fill(color).frame(width: d * 0.16, height: d * 0.16)
            }
        }
    }

    private var botanical: some View {
        Canvas { context, size in
            var branch = Path()
            branch.move(to: CGPoint(x: size.width * 0.35, y: size.height))
            branch.addQuadCurve(to: CGPoint(x: size.width * 0.60, y: 8), control: CGPoint(x: size.width * 0.64, y: size.height * 0.55))
            context.stroke(branch, with: .color(green), style: StrokeStyle(lineWidth: 4, lineCap: .round))
            for i in 0..<5 {
                let y = size.height * (0.14 + Double(i) * 0.16)
                let x = size.width * (i % 2 == 0 ? 0.37 : 0.65)
                for j in 0..<5 {
                    let angle = Double(j) * .pi * 2 / 5
                    let rect = CGRect(x: x + cos(angle) * 9 - 7, y: y + sin(angle) * 9 - 7, width: 14, height: 14)
                    context.fill(Path(ellipseIn: rect), with: .color(red.opacity(0.75)))
                }
                context.fill(Path(ellipseIn: CGRect(x: x - 3, y: y - 3, width: 6, height: 6)), with: .color(.orange))
            }
        }
    }
}
