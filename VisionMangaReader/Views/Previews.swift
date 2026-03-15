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
