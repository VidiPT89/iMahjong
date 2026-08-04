import SwiftUI

@main
struct iMahjongApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
                #if os(macOS)
                .frame(minWidth: 900, minHeight: 640)
                #endif
        }
        #if os(macOS)
        .windowResizability(.contentSize)
        #endif
    }
}
