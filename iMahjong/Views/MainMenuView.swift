import SwiftUI

struct LangToggle: View {
    @EnvironmentObject var loc: Localization

    var body: some View {
        Button(action: { withAnimation(.easeOut(duration: 0.2)) { loc.toggle() } }) {
            HStack(spacing: 10) {
                Text("PT")
                    .foregroundColor(loc.lang == .pt ? Theme.bg : Theme.textDim)
                Text("EN")
                    .foregroundColor(loc.lang == .en ? Theme.bg : Theme.textDim)
            }
            .font(.system(size: 12, weight: .bold))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .background(
                ZStack {
                    Capsule().fill(Theme.bgPanel2).overlay(Capsule().stroke(Theme.borderStrong, lineWidth: 1))
                    GeometryReader { geo in
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: geo.size.width / 2 - 4)
                            .offset(x: loc.lang == .pt ? 2 : geo.size.width / 2 + 2, y: 2)
                            .frame(height: geo.size.height - 4)
                    }
                }
            )
        }
        .buttonStyle(.plain)
    }
}

struct MainMenuView: View {
    @EnvironmentObject var loc: Localization
    let hasSave: Bool
    let onPlay: () -> Void
    let onContinue: () -> Void
    let onHowToPlay: () -> Void

    var body: some View {
        ZStack {
            BackgroundGlow()

            VStack {
                HStack {
                    Spacer()
                    LangToggle().padding(.top, 18).padding(.trailing, 18)
                }
                Spacer()
            }

            VStack(spacing: 18) {
                Spacer()

                Text(loc.t("menuTag"))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Theme.accent)

                BrandLogo(size: 44)

                Text(loc.t("menuSubtitle"))
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textDim)
                    .padding(.bottom, 10)

                VStack(spacing: 12) {
                    if hasSave {
                        Button(loc.t("continueGame"), action: onContinue)
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    Button(loc.t("play"), action: onPlay)
                        .buttonStyle(PrimaryButtonStyle())
                    Button(loc.t("howToPlay"), action: onHowToPlay)
                        .buttonStyle(GhostButtonStyle())
                }

                Spacer()
                FooterCredits()
            }
            .padding(.top, 24)
        }
    }
}
