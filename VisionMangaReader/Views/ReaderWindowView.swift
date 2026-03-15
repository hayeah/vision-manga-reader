import SwiftUI

struct ReaderWindowView: View {
    var appState: AppState
    let windowState: ReaderWindowState

    @State private var book = MangaBook()
    @State private var currentVolumeID: String?
    @State private var error: String?

    var body: some View {
        Group {
            if let error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            } else if book.pageURLs.isEmpty {
                ProgressView("Loading...")
            } else {
                ReaderView(
                    appState: appState,
                    book: book,
                    currentVolumeID: $currentVolumeID
                )
            }
        }
        .onAppear {
            loadVolume()
        }
        .onDisappear {
            appState.unregisterWindow(id: windowState.id)
        }
    }

    private func loadVolume() {
        // Ensure library is booted (shared state — idempotent)
        appState.boot()

        // If library root isn't set, try resolving from this window's bookmark
        if appState.library.rootURL == nil {
            guard let rootURL = windowState.resolveRoot() else {
                error = "Could not access folder. Bookmark may be stale."
                return
            }
            let _ = rootURL.startAccessingSecurityScopedResource()
            appState.library.rootURL = rootURL
            appState.library.scan()
        }

        guard let vol = appState.library.volume(id: windowState.volumeID) else {
            error = "Volume not found."
            return
        }

        book.loadPages(from: vol.url)
        currentVolumeID = vol.id
        book.currentSpreadIndex = min(windowState.spreadIndex, max(0, book.spreadCount - 1))
    }
}
