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
                // Has root, no windowState — bootstrap the first restored window
                let first = appState.prepareInitialWindowState()
                Group {
                    if let first {
                        ProgressView("Loading...")
                            .onAppear {
                                windowState = first
                                appState.openRemainingWindowsIfNeeded(openWindow: openWindow)
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
