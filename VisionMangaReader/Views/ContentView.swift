import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var book = MangaBook()
    @State private var showFilePicker = false
    @State private var noImagesFound = false

    var body: some View {
        Group {
            if book.pageURLs.isEmpty {
                folderPickerView
            } else {
                readerView
            }
        }
        .onAppear {
            restoreLastFolder()
        }
    }

    private var folderPickerView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("VisionMangaReader")
                .font(.largeTitle)

            Text("Select a folder of manga page images")
                .foregroundStyle(.secondary)

            if noImagesFound {
                Text("No images found in selected folder")
                    .foregroundStyle(.red)
            }

            Button("Open Folder") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }

    private var readerView: some View {
        VStack(spacing: 0) {
            SpreadView(book: book)

            ReaderToolbar(book: book)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    book.closeFolder()
                    noImagesFound = false
                    FolderAccess.clearBookmark()
                } label: {
                    Label("Close", systemImage: "xmark")
                }
            }
        }
    }

    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }

        // Temporarily access to enumerate and save bookmark
        guard url.startAccessingSecurityScopedResource() else { return }
        let images = FolderAccess.enumerateImages(in: url)
        url.stopAccessingSecurityScopedResource()

        if images.isEmpty {
            noImagesFound = true
            return
        }

        noImagesFound = false
        FolderAccess.saveBookmark(for: url)
        // loadPages starts its own security-scoped access that persists
        book.loadPages(from: url)
    }

    private func restoreLastFolder() {
        guard let url = FolderAccess.restoreBookmark() else { return }
        // loadPages handles security-scoped access
        book.loadPages(from: url)
    }
}
