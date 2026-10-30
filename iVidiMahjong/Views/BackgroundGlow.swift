import SwiftUI

/// Soft ambient radial accent glow behind menu-style screens.
struct BackgroundGlow: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            RadialGradient(
                colors: [Theme.accent.opacity(0.16), Theme.accent.opacity(0.0)],
                center: .init(x: 0.5, y: 0.15),
                startRadius: 10,
                endRadius: 480
            )
            .ignoresSafeArea()
            RadialGradient(
                colors: [Theme.circleBlue.opacity(0.10), Color.clear],
                center: .init(x: 0.85, y: 0.9),
                startRadius: 10,
                endRadius: 420
            )
            .ignoresSafeArea()
        }
    }
}

struct BrandLogo: View {
    var size: CGFloat = 40

    var body: some View {
        Text("iVidiMahjong")
            .font(.system(size: size, weight: .bold, design: .rounded))
            .foregroundColor(Theme.accent)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .accessibilityLabel("iVidiMahjong")
    }
}

struct FooterCredits: View {
    var body: some View {
        let loc = Localization.shared
        HStack(spacing: 6) {
            Text(loc.t("developedBy"))
                .foregroundColor(Theme.textDim)
            Text("David Arsénio Martins")
                .fontWeight(.semibold)
                .foregroundColor(Theme.text)
            Text("·").foregroundColor(Theme.textFaint)
            Link("ividi.dev", destination: URL(string: "https://ividi.dev/")!)
                .foregroundColor(Theme.accent)
            Text("·").foregroundColor(Theme.textFaint)
            Link("GitHub", destination: URL(string: "https://github.com/VidiPT89/")!)
                .foregroundColor(Theme.accent)
        }
        .font(.system(size: 12))
        .padding(.bottom, 14)
    }
}

/// Round chevron button used at the top-left of every inner screen. Escape triggers it on
/// the Mac, and the "back" identifier lets UI tests find it among the window's own buttons.
struct BackButton: View {
    @EnvironmentObject var loc: Localization
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "chevron.left")
                .foregroundColor(Theme.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.bgPanel2))
        }
        .buttonStyle(.plain)
        .keyboardShortcut(.cancelAction)
        .accessibilityLabel(loc.t("back"))
        .accessibilityIdentifier("back")
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Theme.bg)
            .frame(maxWidth: 340)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(LinearGradient(colors: [Theme.accentLight, Theme.accent], startPoint: .top, endPoint: .bottom))
                    .shadow(color: Theme.accentGlow, radius: configuration.isPressed ? 4 : 14, y: 4)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(Theme.text)
            .frame(maxWidth: 340)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .fill(Theme.bgPanel2)
                    .overlay(RoundedRectangle(cornerRadius: Theme.radius).stroke(Theme.borderStrong, lineWidth: 1))
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

struct GhostButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 15, weight: .medium))
            .foregroundColor(Theme.textDim)
            .frame(maxWidth: 340)
            .padding(.vertical, 12)
            .background(configuration.isPressed ? Theme.bgPanel : Color.clear)
            .cornerRadius(Theme.radius)
            .overlay(
                RoundedRectangle(cornerRadius: Theme.radius)
                    .stroke(Theme.borderStrong, lineWidth: 1)
            )
    }
}
