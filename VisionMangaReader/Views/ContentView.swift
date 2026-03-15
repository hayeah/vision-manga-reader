import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var library = MangaLibrary()
    @State private var book = MangaBook()
    @State private var currentVolumeID: String?
    @State private var showFilePicker = false
    @State private var noImagesFound = false
    @State private var showVolumeDrawer = false
    @State private var showEndOfVolumePrompt = false

    var body: some View {
        Group {
            if library.rootURL == nil {
                setupView
            } else if book.pageURLs.isEmpty {
                seriesListOnly
            } else {
                readerWithPanels
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [UTType.folder],
            allowsMultipleSelection: false
        ) { result in
            handleRootFolderSelection(result)
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
                onSelectSeries: openSeries
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

    // MARK: - Reader with side panels

    private var readerWithPanels: some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                ZStack(alignment: .top) {
                    SpreadView(book: book)

                    if showEndOfVolumePrompt {
                        endOfVolumePrompt
                    }
                }

                ReaderToolbar(
                    book: book,
                    showVolumeDrawer: $showVolumeDrawer,
                    onLibrary: {
                        book.closeFolder()
                        currentVolumeID = nil
                        showVolumeDrawer = false
                        showEndOfVolumePrompt = false
                    }
                )
            }

            if showVolumeDrawer, let currentSeries {
                VolumeDrawer(
                    volumes: currentSeries.volumes,
                    currentVolumeID: currentVolumeID,
                    onSelectVolume: openVolume
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showVolumeDrawer)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button {
                    book.closeFolder()
                    currentVolumeID = nil
                    showVolumeDrawer = false
                    showEndOfVolumePrompt = false
                } label: {
                    Label("Library", systemImage: "books.vertical")
                }
            }
        }
        .onChange(of: book.currentSpreadIndex) { _, newIndex in
            guard let currentVolumeID else { return }
            // Only primary window tracks progress
            library.updateProgress(
                volumeID: currentVolumeID,
                spreadIndex: newIndex,
                totalSpreads: book.spreadCount
            )
            // Check end of volume
            if newIndex >= book.spreadCount - 1 {
                showEndOfVolumePrompt = true
            } else {
                showEndOfVolumePrompt = false
            }
        }
    }

    // MARK: - End of volume prompt

    private var endOfVolumePrompt: some View {
        HStack(spacing: 12) {
            if let currentVolumeID, let nextVol = library.nextVolume(after: currentVolumeID) {
                Text("Open \(nextVol.title)?")
                    .font(.subheadline)
                Button("Next") {
                    openVolume(nextVol)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            } else {
                Text("Volume complete")
                    .font(.subheadline)
            }
            Button("Dismiss") {
                showEndOfVolumePrompt = false
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .padding(.top, 12)
    }

    // MARK: - Helpers

    private var currentSeries: MangaSeries? {
        guard let currentVolumeID else { return nil }
        return library.seriesFor(volumeID: currentVolumeID)
    }

    private func handleRootFolderSelection(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result, let url = urls.first else { return }
        library.setRoot(url)
    }

    private func openSeries(_ s: MangaSeries) {
        // Resume from last-read volume, or start at first
        if let lastRead = library.lastReadVolume(forSeries: s.id) {
            openVolume(lastRead)
        } else if let first = s.volumes.first {
            openVolume(first)
        }
    }

    private func openVolume(_ vol: MangaVolume) {
        showEndOfVolumePrompt = false
        book.loadPages(from: vol.url)
        currentVolumeID = vol.id

        // Restore spread position if we have history
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
