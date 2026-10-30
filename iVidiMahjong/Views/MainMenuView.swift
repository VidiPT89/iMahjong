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
            .font(.system(size: 12, weight: .bold, design: .rounded))
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
                .font(.system(size: 10, weight: .semibold, design: .rounded))
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
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(selected == value ? Theme.bg : Theme.textFaint)
                .padding(.horizontal, 11)
                .padding(.vertical, 8)
                .background(Capsule().fill(selected == value ? Theme.accent : Color.clear))
        }
        .buttonStyle(.plain)
    }
}

struct MainMenuView: View {
    @AppStorage("ividimahjong-sound-enabled") private var soundEnabled = true
    @EnvironmentObject var loc: Localization
    let hasSave: Bool
    @Binding var selectedDifficulty: Difficulty
    let onPlay: () -> Void
    let onContinue: () -> Void
    let onLevels: () -> Void
    let onHowToPlay: () -> Void
    let onTraditionalMode: () -> Void
    let onAcademy: () -> Void
    let lessonsDone: Int

    var body: some View {
        let pt = loc.lang == .pt
        ZStack {
            BackgroundGlow()
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        Text("iVidiMahjong").font(.system(.headline, design: .rounded)).foregroundColor(Theme.textDim)
                        Spacer()
                        Button(action: { soundEnabled.toggle() }) {
                            Image(systemName: soundEnabled ? "speaker.wave.2" : "speaker.slash")
                                .frame(width: 44, height: 44)
                        }.buttonStyle(.plain).foregroundColor(Theme.text)
                            .accessibilityLabel(loc.t(soundEnabled ? "muteSound" : "enableSound"))
                        LangToggle()
                    }
                    HStack(spacing: 14) {
                        menuTile("p3", angle: -14)
                        menuTile("s2", angle: 0).offset(y: -12)
                        menuTile("m1", angle: 14)
                    }.padding(.top, 24).padding(.bottom, 6).accessibilityHidden(true)
                    VStack(spacing: 10) {
                        Text(pt ? "Aprende Riichi Mahjong" : "Learn Riichi Mahjong")
                            .font(.system(size: 32, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.text).multilineTextAlignment(.center)
                        Text(pt ? "Lições curtas, treinos sem fim e uma mesa com treinador que explica cada jogada."
                                : "Short lessons, endless drills and a coached table that explains every move.")
                            .font(.system(.body, design: .rounded)).foregroundColor(Theme.textDim).multilineTextAlignment(.center)
                    }
                    VStack(spacing: 14) {
                        Button(lessonsDone == 0 ? (pt ? "Começar a Academia" : "Start the Academy") : (pt ? "Academia Riichi" : "Riichi Academy"), action: onAcademy)
                            .buttonStyle(PrimaryButtonStyle())
                            .accessibilityIdentifier("academy")
                        if lessonsDone > 0 {
                            Text(pt ? "\(lessonsDone) de \(ACADEMY_LESSONS.count) lições feitas" : "\(lessonsDone) of \(ACADEMY_LESSONS.count) lessons done")
                                .font(.system(.caption, design: .rounded)).foregroundColor(Theme.accent)
                        }
                        Button(pt ? "Mesa Riichi com treinador" : "Coached Riichi table", action: onTraditionalMode)
                            .buttonStyle(SecondaryButtonStyle())
                            .accessibilityIdentifier("riichiTable")
                    }
                    Divider().overlay(Theme.border)
                    VStack(spacing: 12) {
                        SectionLabel(text: pt ? "Para descansar: Solitário" : "Unwind: Solitaire")
                        if hasSave {
                            Button(loc.t("continueGame"), action: onContinue).buttonStyle(SecondaryButtonStyle())
                        }
                        HStack(spacing: 12) {
                            Button(hasSave ? (pt ? "Nova partida" : "New game") : (pt ? "Solitário" : "Solitaire"), action: onPlay)
                                .buttonStyle(SecondaryButtonStyle())
                                .accessibilityIdentifier("solitaire")
                            Button(loc.t("levelsMode"), action: onLevels).buttonStyle(SecondaryButtonStyle())
                        }
                        DifficultyPicker(selected: $selectedDifficulty)
                    }
                    Button(loc.t("howToPlay"), action: onHowToPlay).buttonStyle(GhostButtonStyle())
                }
                .frame(maxWidth: 480).padding(24).frame(maxWidth: .infinity)
            }
        }
    }
    private func menuTile(_ type: String, angle: Double) -> some View {
        TraditionalTileArtwork(typeID: type)
            .scaleEffect(0.36).frame(width: 69, height: 92)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color(red: 0.54, green: 0.32, blue: 0.12)).offset(y: 8))
            .rotation3DEffect(.degrees(22), axis: (x: 1, y: 0, z: 0))
            .rotationEffect(.degrees(angle))
            .shadow(color: .black.opacity(0.4), radius: 12, y: 16)
    }

}
