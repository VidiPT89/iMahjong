import SwiftUI

struct TraditionalModeSelectView: View {
    @EnvironmentObject var loc: Localization
    let onBack: () -> Void
    let onLocal: () -> Void
    let onOnline: () -> Void

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

            VStack(spacing: 16) {
                Spacer()

                Text(loc.t("tradSetupTitle"))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Theme.accent)

                BrandLogo(size: 40)

                Text(loc.t("tradSetupSubtitle"))
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    Button(loc.t("playLocal"), action: onLocal)
                        .buttonStyle(PrimaryButtonStyle())
                    Button(loc.t("playOnline"), action: onOnline)
                        .buttonStyle(SecondaryButtonStyle())
                    Button(loc.t("back"), action: onBack)
                        .buttonStyle(GhostButtonStyle())
                }
                .padding(.top, 10)

                Spacer()
                FooterCredits()
            }
            .padding(.top, 24)
        }
    }
}
