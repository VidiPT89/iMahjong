import SwiftUI

private struct MiniTile: View {
    var highlighted = false
    var dimmed = false
    var width: CGFloat = 34
    var height: CGFloat = 46

    var body: some View {
        RoundedRectangle(cornerRadius: 4)
            .fill(dimmed ? Theme.tileFaceShade.opacity(0.5) : Theme.tileFace)
            .frame(width: width, height: height)
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(highlighted ? Theme.ok : Theme.tileEdge, lineWidth: highlighted ? 2 : 1))
            .shadow(color: highlighted ? Theme.ok.opacity(0.5) : .clear, radius: 6)
    }
}

private struct HTPExample: View {
    let label: String
    let desc: String
    let diagram: AnyView

    var body: some View {
        VStack(spacing: 8) {
            diagram.frame(height: 60)
            Text(label).font(.system(size: 14, weight: .semibold)).foregroundColor(Theme.text)
            Text(desc).font(.system(size: 12)).foregroundColor(Theme.textDim).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct HTPSection: View {
    let title: String
    let body_: String

    init(_ title: String, _ body: String) {
        self.title = title
        self.body_ = body
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
            Text(body_).font(.system(size: 14)).foregroundColor(Theme.textDim)
        }
    }
}

struct HowToPlayView: View {
    @EnvironmentObject var loc: Localization
    let onClose: () -> Void

    @State private var riichiTab = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button(action: onClose) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(Theme.text)
                            .padding(10)
                            .background(Circle().fill(Theme.bgPanel2))
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Text(loc.t("htpTitle")).font(.system(size: 17, weight: .semibold)).foregroundColor(Theme.text)
                    Spacer()
                    Color.clear.frame(width: 36, height: 36)
                }
                .padding()

                HStack(spacing: 8) {
                    htpTab(loc.t("htpModeSolitaire"), selected: !riichiTab) { riichiTab = false }
                    htpTab(loc.t("htpModeRiichi"), selected: riichiTab) { riichiTab = true }
                }
                .padding(.horizontal, 20)

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        if !riichiTab {
                            Text(loc.t("htpIntro"))
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textDim)

                            VStack(alignment: .leading, spacing: 10) {
                                Text(loc.t("htpFreeTitle")).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
                                Text(loc.t("htpFreeBody")).font(.system(size: 14)).foregroundColor(Theme.textDim)

                                HStack(alignment: .top, spacing: 16) {
                                    HTPExample(
                                        label: loc.t("htpCoveredLabel"),
                                        desc: loc.t("htpCoveredDesc"),
                                        diagram: AnyView(
                                            ZStack {
                                                MiniTile().offset(y: 6)
                                                MiniTile(highlighted: false, width: 30, height: 40).offset(y: -6)
                                            }
                                        )
                                    )
                                    HTPExample(
                                        label: loc.t("htpBlockedLabel"),
                                        desc: loc.t("htpBlockedDesc"),
                                        diagram: AnyView(
                                            HStack(spacing: 0) {
                                                MiniTile(width: 28, height: 42)
                                                MiniTile(width: 28, height: 42).offset(x: -4)
                                                MiniTile(width: 28, height: 42).offset(x: -8)
                                            }
                                        )
                                    )
                                    HTPExample(
                                        label: loc.t("htpFreeLabel"),
                                        desc: loc.t("htpFreeDesc"),
                                        diagram: AnyView(
                                            HStack(spacing: 6) {
                                                MiniTile(highlighted: true, width: 30, height: 42)
                                                MiniTile(width: 28, height: 42)
                                            }
                                        )
                                    )
                                }
                            }

                            VStack(alignment: .leading, spacing: 10) {
                                Text(loc.t("htpMatchTitle")).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
                                Text(loc.t("htpMatchBody")).font(.system(size: 14)).foregroundColor(Theme.textDim)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Text(loc.t("htpToolsTitle")).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
                                toolRow(loc.t("hint"), loc.t("htpHintBody"))
                                toolRow(loc.t("shuffle"), loc.t("htpShuffleBody"))
                                toolRow(loc.t("undo"), loc.t("htpUndoBody"))
                            }

                            HTPSection(loc.t("htpScoreTitle"), loc.t("htpScoreBody"))
                        } else {
                            Text(loc.t("htpRiichiIntro"))
                                .font(.system(size: 15))
                                .foregroundColor(Theme.textDim)

                            HTPSection(loc.t("htpRiichiTableTitle"), loc.t("htpRiichiTableBody"))
                            HTPSection(loc.t("htpRiichiTurnTitle"), loc.t("htpRiichiTurnBody"))
                            HTPSection(loc.t("htpRiichiHandTitle"), loc.t("htpRiichiHandBody"))
                            HTPSection(loc.t("htpRiichiCallsTitle"), loc.t("htpRiichiCallsBody"))
                            HTPSection(loc.t("htpRiichiDeclareTitle"), loc.t("htpRiichiDeclareBody"))
                            HTPSection(loc.t("htpRiichiDoraTitle"), loc.t("htpRiichiDoraBody"))
                            HTPSection(loc.t("htpRiichiScoringTitle"), loc.t("htpRiichiScoringBody"))
                            HTPSection(loc.t("htpRiichiEndTitle"), loc.t("htpRiichiEndBody"))
                        }
                    }
                    .padding(20)
                }

                Button(loc.t("htpCloseButton"), action: onClose)
                    .buttonStyle(PrimaryButtonStyle())
                    .padding(.bottom, 20)
            }
        }
    }

    private func htpTab(_ label: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(label)
                    .font(.system(size: 13, weight: .bold))
                    .foregroundColor(selected ? Theme.accent : Theme.textDim)
                Rectangle()
                    .fill(selected ? Theme.accent : Color.clear)
                    .frame(height: 2)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }

    private func toolRow(_ title: String, _ body: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text(title).font(.system(size: 14, weight: .bold)).foregroundColor(Theme.text)
            Text("— " + body).font(.system(size: 14)).foregroundColor(Theme.textDim)
        }
    }
}
