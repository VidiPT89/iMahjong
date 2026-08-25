import SwiftUI

private struct LevelTile: View {
    let level: Int
    let unlocked: Bool
    let cleared: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(cleared ? Theme.accent.opacity(0.18) : Theme.bgPanel2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(cleared ? Theme.accent : Theme.border, lineWidth: 1)
                    )

                if unlocked {
                    Text("\(level)")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundColor(cleared ? Theme.accent : Theme.text)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textFaint)
                }
            }
            .frame(height: 56)
        }
        .buttonStyle(.plain)
        .disabled(!unlocked)
    }
}

private struct LevelTierSection: View {
    @EnvironmentObject var loc: Localization
    let tier: LevelTier
    let bestLevel: Int
    let onSelect: (Int) -> Void

    private var title: String {
        switch tier {
        case .easy: return loc.t("tierEasy")
        case .medium: return loc.t("tierMedium")
        case .hard: return loc.t("tierHard")
        }
    }

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundColor(Theme.textFaint)

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(Array(tier.range), id: \.self) { level in
                    LevelTile(
                        level: level,
                        unlocked: level <= bestLevel + 1,
                        cleared: level <= bestLevel,
                        action: { onSelect(level) }
                    )
                }
            }
        }
    }
}

struct LevelSelectView: View {
    @EnvironmentObject var loc: Localization
    let onBack: () -> Void
    let onSelectLevel: (Int) -> Void

    var body: some View {
        let bestLevel = Leaderboard.infiniteBestLevel()

        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onBack) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Theme.text)
                            .padding(10)
                            .background(Circle().fill(Theme.bgPanel2))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(loc.t("levelsSelectTitle")).font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding()

                Text(loc.t("levelsSelectSubtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(Theme.textDim)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 10)

                if bestLevel >= LEVELS_MAX_LEVEL {
                    Text(loc.t("allLevelsComplete"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.accent)
                        .padding(.bottom, 10)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        ForEach(LevelTier.allCases, id: \.self) { tier in
                            LevelTierSection(tier: tier, bestLevel: bestLevel, onSelect: onSelectLevel)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 30)
                }
            }
        }
    }
}
