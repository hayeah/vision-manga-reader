import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var library = MangaLibrary()
    @State private var book = MangaBook()
    @State private var currentVolumeID: String?
    @State private var showFilePicker = false

    var body: some View {
        Group {
            if library.rootURL == nil {
                setupView
            } else if book.pageURLs.isEmpty {
                seriesListOnly
            } else {
                ReaderView(
                    library: library,
                    book: book,
                    currentVolumeID: $currentVolumeID
                )
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.folder],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                library.setRoot(url)
            }
        }
        .onAppear {
            library.loadHistory()
            if library.restoreRoot() {
                restoreLastReading()
            }
        }
    }

    // MARK: - Setup (no root yet)

    private var setupView: some View {
        VStack(spacing: 20) {
            Image(systemName: "book.pages")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)

            Text("VisionMangaReader")
                .font(.largeTitle)

            Text("Select your manga folder")
                .foregroundStyle(.secondary)

            Button("Select Folder") {
                showFilePicker = true
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Series list only (no volume loaded)

    private var seriesListOnly: some View {
        HStack(spacing: 0) {
            SeriesListView(
                library: library,
                currentVolumeID: currentVolumeID,
                onSelectSeries: { s in
                    openSeries(s)
                }
            )

            VStack(spacing: 20) {
                Image(systemName: "book.pages")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Select a series to start reading")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Helpers

    private func openSeries(_ s: MangaSeries) {
        if let lastRead = library.lastReadVolume(forSeries: s.id) {
            openVolume(lastRead)
        } else if let first = s.volumes.first {
            openVolume(first)
        }
    }

    private func openVolume(_ vol: MangaVolume) {
        book.loadPages(from: vol.url)
        currentVolumeID = vol.id

        if let progress = library.history.progress[vol.id] {
            book.currentSpreadIndex = min(progress.lastSpreadIndex, max(0, book.spreadCount - 1))
        }
    }

    private func restoreLastReading() {
        guard let lastID = library.history.lastActiveVolumeID,
              let vol = library.volume(id: lastID) else { return }
        openVolume(vol)
    }
}
