import SwiftUI

struct ModalOverlay<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                content
            }
            .padding(26)
            .frame(maxWidth: 380)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(Theme.bgPanel)
                    .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.borderStrong, lineWidth: 1))
                    .shadow(color: .black.opacity(0.5), radius: 30, y: 10)
            )
            .padding(24)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }
}

struct WinModalView: View {
    @EnvironmentObject var loc: Localization
    let time: String
    let moves: Int
    let score: Int
    let onPlayAgain: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ModalOverlay {
            Text("🎉").font(.system(size: 44))
            Text(loc.t("winTitle")).font(.system(size: 24, weight: .bold)).foregroundColor(Theme.text)
            Text(loc.t("winSubtitle")).font(.system(size: 14)).foregroundColor(Theme.textDim).multilineTextAlignment(.center)

            HStack(spacing: 20) {
                statBlock(loc.t("finalTime"), time)
                statBlock(loc.t("finalMoves"), "\(moves)")
                statBlock(loc.t("finalScore"), "\(score)")
            }
            .padding(.vertical, 6)

            Button(loc.t("playAgain"), action: onPlayAgain).buttonStyle(PrimaryButtonStyle())
            Button(loc.t("backToMenu"), action: onMenu).buttonStyle(GhostButtonStyle())
        }
    }

    private func statBlock(_ label: String, _ value: String) -> some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 16, weight: .bold)).foregroundColor(Theme.accent)
            Text(label).font(.system(size: 11)).foregroundColor(Theme.textFaint)
        }
    }
}

struct StuckModalView: View {
    @EnvironmentObject var loc: Localization
    let onShuffle: () -> Void
    let onUndo: () -> Void
    let onMenu: () -> Void

    var body: some View {
        ModalOverlay {
            Text("🀫").font(.system(size: 40))
            Text(loc.t("stuckTitle")).font(.system(size: 22, weight: .bold)).foregroundColor(Theme.text)
            Text(loc.t("stuckSubtitle")).font(.system(size: 14)).foregroundColor(Theme.textDim).multilineTextAlignment(.center)

            Button(loc.t("shuffle"), action: onShuffle).buttonStyle(PrimaryButtonStyle())
            Button(loc.t("undo"), action: onUndo).buttonStyle(SecondaryButtonStyle())
            Button(loc.t("backToMenu"), action: onMenu).buttonStyle(GhostButtonStyle())
        }
    }
}

struct ConfirmModalView: View {
    @EnvironmentObject var loc: Localization
    let message: String
    let onYes: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ModalOverlay {
            Text(message).font(.system(size: 15)).foregroundColor(Theme.text).multilineTextAlignment(.center)
            Button(loc.t("confirmYes"), action: onYes).buttonStyle(PrimaryButtonStyle())
            Button(loc.t("confirmNo"), action: onCancel).buttonStyle(GhostButtonStyle())
        }
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Theme.text)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(
                Capsule().fill(Theme.bgPanel2).overlay(Capsule().stroke(Theme.borderStrong, lineWidth: 1))
            )
            .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
            .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
