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

struct DifficultyPicker: View {
    @EnvironmentObject var loc: Localization
    @Binding var selected: Difficulty

    var body: some View {
        VStack(spacing: 6) {
            Text(loc.t("difficultyLabel"))
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundColor(Theme.textFaint)
                .textCase(.uppercase)

            HStack(spacing: 2) {
                option(.easy, label: loc.t("difficultyEasy"))
                option(.medium, label: loc.t("difficultyMedium"))
                option(.hard, label: loc.t("difficultyHard"))
            }
            .padding(3)
            .background(Capsule().fill(Theme.bgPanel).overlay(Capsule().stroke(Theme.border, lineWidth: 1)))
        }
    }

    private func option(_ value: Difficulty, label: String) -> some View {
        Button(action: { selected = value }) {
            Text(label)
                .font(.system(size: 13, weight: .bold))
                .foregroundColor(selected == value ? Theme.bg : Theme.textFaint)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected == value ? Theme.accent : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

struct MainMenuView: View {
    @EnvironmentObject var loc: Localization
    let hasSave: Bool
    @Binding var selectedDifficulty: Difficulty
    let onPlay: () -> Void
    let onContinue: () -> Void
    let onHowToPlay: () -> Void
    let onTraditionalMode: () -> Void

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

                Text(loc.t("menuTag"))
                    .font(.system(size: 12, weight: .bold))
                    .tracking(2)
                    .foregroundColor(Theme.accent)

                BrandLogo(size: 44)

                Text(loc.t("menuSubtitle"))
                    .font(.system(size: 15))
                    .foregroundColor(Theme.textDim)

                DifficultyPicker(selected: $selectedDifficulty)
                    .padding(.top, 6)

                VStack(spacing: 12) {
                    if hasSave {
                        Button(loc.t("continueGame"), action: onContinue)
                            .buttonStyle(SecondaryButtonStyle())
                    }
                    Button(loc.t("play"), action: onPlay)
                        .buttonStyle(PrimaryButtonStyle())
                    Button(loc.t("traditionalMode"), action: onTraditionalMode)
                        .buttonStyle(SecondaryButtonStyle())
                    Button(loc.t("howToPlay"), action: onHowToPlay)
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
