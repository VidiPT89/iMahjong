import SwiftUI

struct TraditionalSetupView: View {
    @EnvironmentObject var loc: Localization
    @Binding var humanSeats: [Bool]
    let onBack: () -> Void
    let onStart: () -> Void

    private let windKeys = ["windE", "windS", "windW", "windN"]

    var body: some View {
        ZStack {
            BackgroundGlow()

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

                VStack(spacing: 10) {
                    Text(loc.t("humanPlayers"))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textDim)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(0..<4, id: \.self) { i in
                            Button(action: { humanSeats[i].toggle() }) {
                                VStack(spacing: 2) {
                                    Text(loc.t(windKeys[i])).font(.system(size: 15, weight: .bold))
                                    if !humanSeats[i] {
                                        Text("(\(loc.t("bot")))").font(.system(size: 11)).opacity(0.7)
                                    }
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(humanSeats[i] ? Theme.accent : Theme.bgPanel2)
                                )
                                .foregroundColor(humanSeats[i] ? Theme.bg : Theme.textDim)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.bgPanel).overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.border, lineWidth: 1)))
                .frame(maxWidth: 340)

                VStack(spacing: 12) {
                    Button(loc.t("startMatch"), action: onStart)
                        .buttonStyle(PrimaryButtonStyle())
                    Button(loc.t("back"), action: onBack)
                        .buttonStyle(GhostButtonStyle())
                }
                .padding(.top, 10)

                Spacer()
            }
            .padding(.top, 24)
        }
    }
}
