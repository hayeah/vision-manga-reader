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

#Preview("Full Reader") {
    ReaderPreview()
}

/// Stateful wrapper so the reader preview has interactive controls.
private struct ReaderPreview: View {
    @State private var book = previewBook()
    @State private var expandedPanel: OrnamentPanel?

    var body: some View {
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
        // Ornaments don't render in canvas previews — simulate as overlay.
        .overlay(alignment: .leading) {
            HStack(spacing: 0) {
                if expandedPanel == .volumes {
                    ScrollView {
                        VStack(spacing: 4) {
                            ForEach(previewVolumes()) { vol in
                                Button { } label: {
                                    Text(vol.title)
                                        .font(.callout)
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(8)
                    }
                    .frame(width: 200).frame(maxHeight: 400)
                }

                VStack(spacing: 12) {
                    Button { togglePanel(.volumes) } label: {
                        Label("Volumes", systemImage: "list.number")
                    }
                    Button { togglePanel(.series) } label: {
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
            }
            .glassBackgroundEffect()
            .padding(.leading, 8)
            .animation(.easeInOut(duration: 0.2), value: expandedPanel)
        }
        .background(.black)
    }

    private func togglePanel(_ panel: OrnamentPanel) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if expandedPanel == panel {
                expandedPanel = nil
            } else {
                expandedPanel = panel
            }
        }
    }
}

#Preview("End of Volume Prompt") {
    VStack {
        Spacer()
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
