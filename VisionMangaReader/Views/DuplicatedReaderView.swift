import SwiftUI

struct DuplicatedReaderView: View {
    let windowID: ReaderWindowID

    @State private var library = MangaLibrary()
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
                    library: library,
                    book: book,
                    currentVolumeID: $currentVolumeID
                )
            }
        }
        .onAppear {
            resolveAndLoad()
        }
    }

    private func resolveAndLoad() {
        guard let rootURL = windowID.resolveRoot() else {
            error = "Could not access folder. Bookmark may be stale."
            return
        }

        guard rootURL.startAccessingSecurityScopedResource() else {
            error = "Could not access folder."
            return
        }

        library.rootURL = rootURL
        library.scan()
        library.loadHistory()

        guard let vol = library.volume(id: windowID.volumeID) else {
            error = "Volume not found."
            return
        }

        book.loadPages(from: vol.url)
        currentVolumeID = vol.id
        book.currentSpreadIndex = min(windowID.spreadIndex, max(0, book.spreadCount - 1))
    }
}
