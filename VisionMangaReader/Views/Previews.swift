import SwiftUI

// MARK: - Preview helpers

/// Loads preview images from the PreviewContent bundle resource folder.
/// Returns URLs sorted by filename. Returns empty if PreviewContent is missing.
private func previewImageURLs() -> [URL] {
    guard let resourceURL = Bundle.main.resourceURL else { return [] }
    let previewDir = resourceURL.appendingPathComponent("PreviewContent")
    let fm = FileManager.default
    guard let files = try? fm.contentsOfDirectory(
        at: previewDir,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
    ) else { return [] }

    return files
        .filter { ["jpg", "jpeg", "png", "webp"].contains($0.pathExtension.lowercased()) }
        .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
}

private func previewBook() -> MangaBook {
    let book = MangaBook()
    let urls = previewImageURLs()
    guard !urls.isEmpty else { return book }
    book.loadLocalPages(urls)
    return book
}

private func previewVolumes(count: Int = 9) -> [MangaVolume] {
    (0..<count).map { i in
        MangaVolume(
            id: "SeriesA/第\(String(format: "%02d", i + 1))卷",
            url: URL(filePath: "/tmp"),
            title: "第\(String(format: "%02d", i + 1))卷",
            seriesID: "SeriesA",
            sortIndex: i
        )
    }
}

private func previewHistory() -> ReadingHistory {
    var h = ReadingHistory()
    // First two volumes completed
    h.progress["SeriesA/第01卷"] = VolumeProgress(lastSpreadIndex: 19, totalSpreads: 20, lastReadDate: .now, isCompleted: true)
    h.progress["SeriesA/第02卷"] = VolumeProgress(lastSpreadIndex: 24, totalSpreads: 25, lastReadDate: .now, isCompleted: true)
    // Third volume in progress
    h.progress["SeriesA/第03卷"] = VolumeProgress(lastSpreadIndex: 8, totalSpreads: 22, lastReadDate: .now, isCompleted: false)
    return h
}

private func previewLibrary() -> MangaLibrary {
    let lib = MangaLibrary()
    return lib
}

// MARK: - Previews

#Preview("Spread View — Reader") {
    let book = previewBook()
    VStack(spacing: 0) {
        SpreadView(book: book)
        Text("\(book.currentSpreadIndex + 1) / \(book.spreadCount)")
            .monospacedDigit()
            .foregroundStyle(.secondary)
            .padding(8)
    }
    .background(.black)
}

#Preview("Spread View — Pair") {
    let book = previewBook()
    let _ = { book.currentSpreadIndex = 1 }()
    SpreadView(book: book)
        .background(.black)
}

#Preview("Volume Drawer") {
    VolumeDrawer(
        volumes: previewVolumes(),
        currentVolumeID: "SeriesA/第04卷",

        onSelectVolume: { _ in }
    )
    .frame(height: 400)
}

#Preview("Series List") {
    SeriesListView(
        library: previewLibrary(),
        currentVolumeID: "SeriesA/第04卷",
        onSelectSeries: { _ in }
    )
    .frame(height: 500)
}

#Preview("Reader + Drawer") {
    let book = previewBook()
    HStack(spacing: 0) {
        SpreadView(book: book)
        VolumeDrawer(
            volumes: previewVolumes(),
            currentVolumeID: "SeriesA/第04卷",

            onSelectVolume: { _ in }
        )
    }
    .background(.black)
}

#Preview("Full Reader") {
    ReaderPreview()
}

/// Stateful wrapper so the reader preview has interactive controls.
private struct ReaderPreview: View {
    @State private var book = previewBook()
    @State private var showVolumeDrawer = false

    var body: some View {
        HStack(spacing: 0) {
            ZStack(alignment: .bottomTrailing) {
                SpreadView(book: book)

                if book.spreadCount > 0 {
                    Text("\(book.currentSpreadIndex + 1) / \(book.spreadCount)")
                        .monospacedDigit()
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 20)
                        .padding(.bottom, 16)
                }
            }

            if showVolumeDrawer {
                VolumeDrawer(
                    volumes: previewVolumes(),
                    currentVolumeID: "SeriesA/第04卷",
                    onSelectVolume: { _ in }
                )
                .transition(.move(edge: .trailing))
            }
        }
        .animation(.easeInOut(duration: 0.2), value: showVolumeDrawer)
        // Ornaments only render in a real window, not canvas previews.
        // Simulating the nav buttons as an overlay for preview purposes.
        .overlay(alignment: .leading) {
            VStack(spacing: 12) {
                Button { showVolumeDrawer.toggle() } label: {
                    Label("Volumes", systemImage: "list.number")
                }
                Button {} label: {
                    Label("Library", systemImage: "books.vertical")
                }
                Button {} label: {
                    Label("Duplicate", systemImage: "plus.rectangle.on.rectangle")
                }

                Divider()

                Button { book.toggleShift() } label: {
                    Label("Toggle page pairing", systemImage: "arrow.left.arrow.right")
                        .symbolVariant(book.isCurrentSequenceShifted ? .fill : .none)
                }
                .disabled(!book.canToggleShift)
            }
            .labelStyle(.iconOnly)
            .padding(8)
            .glassBackgroundEffect()
            .padding(.leading, 8)
        }
        .background(.black)
    }
}

#Preview("End of Volume Prompt") {
    VStack {
        Spacer()
        // Simulating the prompt overlay
        HStack(spacing: 12) {
            Text("Open 第05卷?")
                .font(.subheadline)
            Button("Next") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button("Dismiss") {}
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        Spacer()
    }
}
