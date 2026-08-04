import SwiftUI

struct ShakeEffect: GeometryEffect {
    var animatableData: CGFloat

    func effectValue(size: CGSize) -> ProjectionTransform {
        let translation = 6 * sin(animatableData * .pi * 6)
        return ProjectionTransform(CGAffineTransform(translationX: translation, y: 0))
    }
}

struct TileView: View {
    let tile: GameTile
    let width: CGFloat
    let height: CGFloat
    let isFree: Bool
    let isSelected: Bool
    let isHinted: Bool
    let shakeToken: Int
    let dealDelay: Double

    @State private var shakeProgress: CGFloat = 0
    @State private var dealt = false

    var body: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(
                LinearGradient(
                    colors: [Theme.tileFace, Theme.tileFaceShade],
                    startPoint: .top, endPoint: .bottom
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: isSelected || isHinted ? 2.5 : 1)
            )
            .overlay(
                Group {
                    if let typeId = tile.typeId {
                        TileFaceView(typeId: typeId)
                            .padding(5)
                    }
                }
            )
            .frame(width: width, height: height)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(isFree ? 0 : 0.38))
            )
            .shadow(color: glowColor, radius: (isSelected || isHinted) ? 10 : 2, y: isSelected ? 0 : 1.5)
            .scaleEffect(isSelected ? 1.08 : (dealt ? 1 : 0.4))
            .offset(y: isSelected ? -6 : 0)
            .opacity(dealt ? 1 : 0)
            .modifier(ShakeEffect(animatableData: shakeProgress))
            .animation(.spring(response: 0.28, dampingFraction: 0.6), value: isSelected)
            .onChange(of: shakeToken) { _ in
                shakeProgress = 0
                withAnimation(.linear(duration: 0.4)) { shakeProgress = 1 }
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.72).delay(dealDelay)) {
                    dealt = true
                }
            }
    }

    private var borderColor: Color {
        if isSelected { return Theme.accent }
        if isHinted { return Theme.ok }
        return Theme.tileEdge
    }

    private var glowColor: Color {
        if isSelected { return Theme.accentGlow }
        if isHinted { return Theme.ok.opacity(0.6) }
        return Color.black.opacity(0.25)
    }
}
