import SwiftUI

@main
struct iVidiMahjongApp: App {
    #if os(macOS)
    @NSApplicationDelegateAdaptor(MacAppDelegate.self) private var appDelegate
    #endif

    var body: some Scene {
        #if os(macOS)
        // A single window: every screen shares one save slot, so a second window would
        // overwrite the first one's game.
        Window("iVidiMahjong", id: "main") {
            RootView()
                .preferredColorScheme(.dark)
                .frame(minWidth: 900, minHeight: 640)
        }
        .defaultSize(width: 1280, height: 800)
        #else
        WindowGroup {
            RootView()
                .preferredColorScheme(.dark)
        }
        #endif
    }
}

#if os(macOS)
final class MacAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
#endif
