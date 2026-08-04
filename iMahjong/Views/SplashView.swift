import SwiftUI

struct SplashView: View {
    @EnvironmentObject var loc: Localization
    var onFinish: () -> Void

    @State private var appeared = false

    var body: some View {
        ZStack {
            BackgroundGlow()

            VStack(spacing: 22) {
                Spacer()

                BrandLogo(size: 52)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 12)

                Text(loc.t("menuSubtitle"))
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textDim)
                    .opacity(appeared ? 1 : 0)

                VStack(spacing: 4) {
                    Text(loc.t("developedBy"))
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textFaint)
                    Text("David Arsénio Martins")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(Theme.text)
                    HStack(spacing: 6) {
                        Link("ividi.dev", destination: URL(string: "https://ividi.dev/")!)
                        Text("·").foregroundColor(Theme.textFaint)
                        Link("github.com/VidiPT89", destination: URL(string: "https://github.com/VidiPT89/")!)
                    }
                    .font(.system(size: 13))
                    .foregroundColor(Theme.accent)
                }
                .padding(.top, 18)
                .opacity(appeared ? 1 : 0)

                Spacer()

                Text(loc.t("tapToContinue"))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textFaint)
                    .padding(.bottom, 30)
                    .opacity(appeared ? 0.8 : 0)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onFinish() }
        .onAppear {
            withAnimation(.easeOut(duration: 0.7)) { appeared = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) { onFinish() }
        }
    }
}
