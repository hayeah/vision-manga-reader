import SwiftUI
import UniformTypeIdentifiers

struct DuplicatedReaderView: View {
    let windowID: ReaderWindowID

    @State private var book = MangaBook()
    @State private var error: String?
    @State private var showFilePicker = false
    @State private var noImagesFound = false

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
                    ReaderToolbar(book: book) {
                        showFilePicker = true
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
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

        book.loadPages(from: url)

        if let loadError = book.loadError {
            error = loadError
            return
        }

        if book.pageURLs.isEmpty {
            error = "No images found in folder."
            return
        }

        book.currentSpreadIndex = min(windowID.spreadIndex, max(0, book.spreadCount - 1))
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        guard url.startAccessingSecurityScopedResource() else { return }
        let images = FolderAccess.enumerateImages(in: url)
        url.stopAccessingSecurityScopedResource()

        if images.isEmpty {
            error = "No images found in selected folder"
            return
        }

        error = nil
        FolderAccess.saveBookmark(for: url)
        book.loadPages(from: url)

        if let loadError = book.loadError {
            error = loadError
        }
    }
}
