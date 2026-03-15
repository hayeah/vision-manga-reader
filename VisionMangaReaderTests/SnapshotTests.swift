import Testing
import SwiftUI
import UIKit
@testable import VisionMangaReader

@Suite("UI Snapshots")
struct SnapshotTests {

    private static let outputDir: URL = {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("MangaSnapshots")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    @MainActor
    private func saveSnapshot<V: View>(_ view: V, name: String, width: CGFloat, height: CGFloat) throws {
        let sized = view
            .frame(width: width, height: height)

        let renderer = ImageRenderer(content: sized)
        renderer.scale = 2.0
        renderer.proposedSize = .init(width: width, height: height)

        guard let image = renderer.uiImage,
              let data = image.pngData() else {
            Issue.record("Failed to render \(name)")
            return
        }

        let url = Self.outputDir.appendingPathComponent("\(name).png")
        try data.write(to: url)
        print("[Snapshot] Saved: \(url.path)")
    }

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

    /// Load UIImages synchronously from preview assets
    private func loadPreviewImages() -> [UIImage] {
        previewImageURLs().compactMap { UIImage(contentsOfFile: $0.path) }
    }

    private func makeVolumes(count: Int = 9) -> [MangaVolume] {
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

    private func makeHistory() -> ReadingHistory {
        var h = ReadingHistory()
        h.progress["SeriesA/第01卷"] = VolumeProgress(lastSpreadIndex: 19, totalSpreads: 20, lastReadDate: .now, isCompleted: true)
        h.progress["SeriesA/第02卷"] = VolumeProgress(lastSpreadIndex: 24, totalSpreads: 25, lastReadDate: .now, isCompleted: true)
        h.progress["SeriesA/第03卷"] = VolumeProgress(lastSpreadIndex: 8, totalSpreads: 22, lastReadDate: .now, isCompleted: false)
        return h
    }

    // MARK: - Spread snapshots using raw UIImage (no async loading)

    /// Single landscape page centered
    @Test("Snapshot: landscape cover spread")
    @MainActor
    func snapshotLandscapeCover() throws {
        let images = loadPreviewImages()
        guard !images.isEmpty else { Issue.record("No preview images"); return }
        // Image 0 is landscape (1960x1021)
        let img = images[0]

        let view = Image(uiImage: img)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)

        try saveSnapshot(view, name: "spread_landscape", width: 1200, height: 600)
    }

    /// Portrait pair (RTL: right = earlier page, left = later page)
    @Test("Snapshot: portrait pair spread")
    @MainActor
    func snapshotPortraitPair() throws {
        let images = loadPreviewImages()
        guard images.count >= 3 else { Issue.record("Need at least 3 preview images"); return }
        // Pages 1 and 2 are portrait. RTL layout: left=page2, right=page1
        let rightPage = images[1]
        let leftPage = images[2]

        let view = HStack(spacing: 0) {
            Image(uiImage: leftPage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

            Image(uiImage: rightPage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .background(.black)

        try saveSnapshot(view, name: "spread_pair", width: 1200, height: 600)
    }

    @Test("Snapshot: VolumeDrawer")
    @MainActor
    func snapshotVolumeDrawer() throws {
        let volumes = makeVolumes()
        let currentID = "SeriesA/第04卷"

        let view = VStack(spacing: 6) {
            ForEach(volumes) { vol in
                let isCurrent = vol.id == currentID
                ZStack {
                    Circle()
                        .fill(isCurrent ? Color.blue : Color.gray.opacity(0.4))
                        .frame(width: 28, height: 28)
                    Text("\(vol.sortIndex + 1)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(isCurrent ? .white : .primary)
                }
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .background(Color(white: 0.92))

        try saveSnapshot(view, name: "volume_drawer", width: 60, height: 420)
    }

    @Test("Snapshot: EndOfVolume prompt")
    @MainActor
    func snapshotEndOfVolumePrompt() throws {
        let prompt = HStack(spacing: 12) {
            Text("Open 第05卷?")
                .font(.subheadline)
                .foregroundStyle(.white)
            Button("Next") {}
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            Button("Dismiss") {}
                .buttonStyle(.bordered)
                .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color(white: 0.2), in: Capsule())
        .background(.black)

        try saveSnapshot(prompt, name: "end_of_volume_prompt", width: 400, height: 80)
    }

    @Test("Snapshot: Reader with drawer composite")
    @MainActor
    func snapshotReaderWithDrawer() throws {
        let images = loadPreviewImages()
        guard images.count >= 3 else { Issue.record("Need at least 3 preview images"); return }
        let rightPage = images[1]
        let leftPage = images[2]

        let view = HStack(spacing: 0) {
            // Reader area
            HStack(spacing: 0) {
                Image(uiImage: leftPage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)

                Image(uiImage: rightPage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .background(.black)

            // Drawer
            VolumeDrawer(
                volumes: makeVolumes(),
                currentVolumeID: "SeriesA/第04卷",
                onSelectVolume: { _ in }
            )
            .environment(\.colorScheme, .light)
            .background(Color(white: 0.9))
        }

        try saveSnapshot(view, name: "reader_with_drawer", width: 1200, height: 600)
    }

    @Test("Print snapshot output directory")
    func printOutputDir() {
        print("[Snapshot] Output directory: \(Self.outputDir.path)")
    }
}
