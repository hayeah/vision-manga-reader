import SwiftUI

struct DuplicatedReaderView: View {
    let windowID: ReaderWindowID

    @State private var book = MangaBook()
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
                VStack(spacing: 0) {
                    SpreadView(book: book)
                    ReaderToolbar(book: book)
                }
            }
        }
        .onAppear {
            resolveAndLoad()
        }
    }

    private func resolveAndLoad() {
        guard let url = windowID.resolveFolder() else {
            error = "Could not access folder. Bookmark may be stale."
            return
        }

        // loadPages handles security-scoped access
        book.loadPages(from: url)

        if book.pageURLs.isEmpty {
            error = "No images found in folder."
            return
        }

        book.currentSpreadIndex = min(windowID.spreadIndex, max(0, book.spreadCount - 1))
    }
}
