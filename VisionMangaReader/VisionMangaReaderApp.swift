import SwiftUI

@main
struct VisionMangaReaderApp: App {
    @State private var appState = AppState()

    var body: some Scene {
        WindowGroup(id: "reader", for: ReaderWindowState.self) { $windowState in
            if let windowState {
                ReaderWindowView(appState: appState, windowState: windowState)
            } else if !appState.hasRoot {
                SetupView(appState: appState, windowState: $windowState)
            } else {
                // Has root, no windowState — first window on relaunch
                let first = appState.firstWindowState
                Group {
                    if let first {
                        ReaderWindowView(appState: appState, windowState: first)
                            .onAppear {
                                windowState = first
                                appState.openRemainingWindows(openWindow: openWindow)
                            }
                    } else {
                        // Root exists but no volumes found
                        SetupView(appState: appState, windowState: $windowState)
                    }
                }
            }
        }
    }

    @Environment(\.openWindow) private var openWindow
}
