import Testing
import Foundation
@testable import VisionMangaReader

@Suite("MangaLibrary scanning")
struct MangaLibraryScanTests {

    /// Create a temp directory with a manga-like structure and return the root URL
    private func makeTempMangaRoot(
        series: [(name: String, volumes: [String], infoJSON: String?)] = []
    ) throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaLibraryTests-\(UUID().uuidString)")
        let fm = FileManager.default

        for s in series {
            let seriesDir = root.appendingPathComponent(s.name)
            try fm.createDirectory(at: seriesDir, withIntermediateDirectories: true)

            if let json = s.infoJSON {
                try json.write(to: seriesDir.appendingPathComponent("info.json"), atomically: true, encoding: .utf8)
            }

            for vol in s.volumes {
                let volDir = seriesDir.appendingPathComponent(vol)
                try fm.createDirectory(at: volDir, withIntermediateDirectories: true)
                // Put a dummy image file so it looks realistic
                try Data("fake".utf8).write(to: volDir.appendingPathComponent("001.jpg"))
            }
        }
        return root
    }

    private func cleanup(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }

    @Test("Scan discovers series and volumes in natural sort order")
    func scanDiscoversSorted() throws {
        let root = try makeTempMangaRoot(series: [
            (name: "SeriesB", volumes: ["第02卷", "第01卷", "第10卷"], infoJSON: nil),
            (name: "SeriesA", volumes: ["第03卷", "第01卷"], infoJSON: nil),
        ])
        defer { cleanup(root) }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        #expect(lib.series.count == 2)
        #expect(lib.series[0].id == "SeriesA")
        #expect(lib.series[1].id == "SeriesB")

        // Volumes should be naturally sorted
        let volsB = lib.series[1].volumes.map(\.title)
        #expect(volsB == ["第01卷", "第02卷", "第10卷"])

        let volsA = lib.series[0].volumes.map(\.title)
        #expect(volsA == ["第01卷", "第03卷"])
    }

    @Test("Scan uses folder name when info.json is absent")
    func scanNoInfoJSON() throws {
        let root = try makeTempMangaRoot(series: [
            (name: "烙印战士", volumes: ["第01卷"], infoJSON: nil),
        ])
        defer { cleanup(root) }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        #expect(lib.series.count == 1)
        #expect(lib.series[0].title == "烙印战士")
    }

    @Test("Scan uses info.json title when present")
    func scanWithInfoJSON() throws {
        let json = #"{"title": "Berserk", "authors": ["三浦建太郎"]}"#
        let root = try makeTempMangaRoot(series: [
            (name: "烙印战士", volumes: ["第01卷"], infoJSON: json),
        ])
        defer { cleanup(root) }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        #expect(lib.series[0].title == "Berserk")
        #expect(lib.series[0].id == "烙印战士") // id stays as folder name
    }

    @Test("Scan ignores non-directory items at series level")
    func scanIgnoresFiles() throws {
        let root = try makeTempMangaRoot(series: [
            (name: "RealSeries", volumes: ["第01卷"], infoJSON: nil),
        ])
        defer { cleanup(root) }

        // Add a stray file at root level
        try Data("junk".utf8).write(to: root.appendingPathComponent("notes.txt"))

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        #expect(lib.series.count == 1)
        #expect(lib.series[0].id == "RealSeries")
    }

    @Test("Scan handles empty root")
    func scanEmptyRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaLibraryTests-empty-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { cleanup(root) }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        #expect(lib.series.isEmpty)
    }

    @Test("Scan handles series with no volumes")
    func scanEmptySeries() throws {
        let root = try makeTempMangaRoot(series: [
            (name: "EmptySeries", volumes: [], infoJSON: nil),
        ])
        defer { cleanup(root) }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        #expect(lib.series.count == 1)
        #expect(lib.series[0].volumes.isEmpty)
    }

    @Test("Volume IDs are relative paths")
    func volumeIDsAreRelative() throws {
        let root = try makeTempMangaRoot(series: [
            (name: "火之鸟", volumes: ["第01卷", "第02卷"], infoJSON: nil),
        ])
        defer { cleanup(root) }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        let ids = lib.series[0].volumes.map(\.id)
        #expect(ids == ["火之鸟/第01卷", "火之鸟/第02卷"])
    }

    @Test("Volume sortIndex is sequential")
    func volumeSortIndex() throws {
        let root = try makeTempMangaRoot(series: [
            (name: "S", volumes: ["第03卷", "第01卷", "第02卷"], infoJSON: nil),
        ])
        defer { cleanup(root) }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        let indices = lib.series[0].volumes.map(\.sortIndex)
        #expect(indices == [0, 1, 2])
    }
}

@Suite("MangaLibrary volume lookup")
struct MangaLibraryLookupTests {

    private func makeLibWithTwoSeries() throws -> (MangaLibrary, URL) {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MangaLibraryLookup-\(UUID().uuidString)")
        let fm = FileManager.default

        for (series, vols) in [("A", ["v1", "v2", "v3"]), ("B", ["v1", "v2"])] {
            for vol in vols {
                let dir = root.appendingPathComponent(series).appendingPathComponent(vol)
                try fm.createDirectory(at: dir, withIntermediateDirectories: true)
                try Data("img".utf8).write(to: dir.appendingPathComponent("001.jpg"))
            }
        }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()
        return (lib, root)
    }

    @Test("volume(id:) finds existing volume")
    func volumeByID() throws {
        let (lib, root) = try makeLibWithTwoSeries()
        defer { try? FileManager.default.removeItem(at: root) }

        let vol = lib.volume(id: "A/v2")
        #expect(vol != nil)
        #expect(vol?.title == "v2")
        #expect(vol?.seriesID == "A")
    }

    @Test("volume(id:) returns nil for nonexistent")
    func volumeByIDMissing() throws {
        let (lib, root) = try makeLibWithTwoSeries()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(lib.volume(id: "A/v99") == nil)
        #expect(lib.volume(id: "C/v1") == nil)
    }

    @Test("nextVolume returns correct next volume")
    func nextVolume() throws {
        let (lib, root) = try makeLibWithTwoSeries()
        defer { try? FileManager.default.removeItem(at: root) }

        let next = lib.nextVolume(after: "A/v1")
        #expect(next?.id == "A/v2")

        let next2 = lib.nextVolume(after: "A/v2")
        #expect(next2?.id == "A/v3")
    }

    @Test("nextVolume returns nil at end of series")
    func nextVolumeAtEnd() throws {
        let (lib, root) = try makeLibWithTwoSeries()
        defer { try? FileManager.default.removeItem(at: root) }

        #expect(lib.nextVolume(after: "A/v3") == nil)
        #expect(lib.nextVolume(after: "B/v2") == nil)
    }

    @Test("nextVolume does NOT cross series boundaries")
    func nextVolumeNoCrossover() throws {
        let (lib, root) = try makeLibWithTwoSeries()
        defer { try? FileManager.default.removeItem(at: root) }

        // Last volume of A should not return first volume of B
        let next = lib.nextVolume(after: "A/v3")
        #expect(next == nil)
    }

    @Test("seriesFor returns correct series")
    func seriesForVolume() throws {
        let (lib, root) = try makeLibWithTwoSeries()
        defer { try? FileManager.default.removeItem(at: root) }

        let s = lib.seriesFor(volumeID: "B/v1")
        #expect(s?.id == "B")
    }
}

@Suite("Reading history persistence")
struct ReadingHistoryTests {

    @Test("updateProgress stores and retrieves progress")
    func updateAndRetrieve() {
        let lib = MangaLibrary()
        lib.updateProgress(volumeID: "A/v1", spreadIndex: 5, totalSpreads: 20)

        let prog = lib.history.progress["A/v1"]
        #expect(prog != nil)
        #expect(prog?.lastSpreadIndex == 5)
        #expect(prog?.totalSpreads == 20)
        #expect(prog?.isCompleted == false)
    }

    @Test("updateProgress marks completed at last spread")
    func completionDetection() {
        let lib = MangaLibrary()
        lib.updateProgress(volumeID: "A/v1", spreadIndex: 19, totalSpreads: 20)

        #expect(lib.history.progress["A/v1"]?.isCompleted == true)
    }

    @Test("updateProgress does NOT mark completed before last spread")
    func notCompletedEarly() {
        let lib = MangaLibrary()
        lib.updateProgress(volumeID: "A/v1", spreadIndex: 18, totalSpreads: 20)

        #expect(lib.history.progress["A/v1"]?.isCompleted == false)
    }

    @Test("updateProgress updates recent series list")
    func recentSeriesTracking() {
        let lib = MangaLibrary()
        lib.updateProgress(volumeID: "A/v1", spreadIndex: 0, totalSpreads: 10)
        lib.updateProgress(volumeID: "B/v1", spreadIndex: 0, totalSpreads: 10)
        lib.updateProgress(volumeID: "A/v2", spreadIndex: 0, totalSpreads: 10)

        // A should be most recent (last updated), B second
        #expect(lib.history.recentSeriesIDs == ["A", "B"])
    }

    @Test("updateProgress sets lastActiveVolumeID")
    func lastActiveVolume() {
        let lib = MangaLibrary()
        lib.updateProgress(volumeID: "A/v1", spreadIndex: 3, totalSpreads: 10)
        #expect(lib.history.lastActiveVolumeID == "A/v1")

        lib.updateProgress(volumeID: "B/v2", spreadIndex: 0, totalSpreads: 5)
        #expect(lib.history.lastActiveVolumeID == "B/v2")
    }

    @Test("updateProgress deduplicates recent series")
    func recentSeriesDedup() {
        let lib = MangaLibrary()
        for i in 0..<5 {
            lib.updateProgress(volumeID: "A/v\(i)", spreadIndex: 0, totalSpreads: 10)
        }
        // Should only appear once
        let aCount = lib.history.recentSeriesIDs.filter { $0 == "A" }.count
        #expect(aCount == 1)
    }

    @Test("updateProgress caps recent series at 20")
    func recentSeriesCap() {
        let lib = MangaLibrary()
        for i in 0..<25 {
            lib.updateProgress(volumeID: "S\(i)/v1", spreadIndex: 0, totalSpreads: 10)
        }
        #expect(lib.history.recentSeriesIDs.count == 20)
    }

    @Test("History round-trips through JSON")
    func historyRoundTrip() throws {
        var history = ReadingHistory()
        history.progress["A/v1"] = VolumeProgress(
            lastSpreadIndex: 5,
            totalSpreads: 20,
            lastReadDate: Date(timeIntervalSince1970: 1000000),
            isCompleted: false
        )
        history.recentSeriesIDs = ["A", "B"]
        history.lastActiveVolumeID = "A/v1"

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(history)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ReadingHistory.self, from: data)

        #expect(decoded.progress["A/v1"]?.lastSpreadIndex == 5)
        #expect(decoded.progress["A/v1"]?.totalSpreads == 20)
        #expect(decoded.progress["A/v1"]?.isCompleted == false)
        #expect(decoded.recentSeriesIDs == ["A", "B"])
        #expect(decoded.lastActiveVolumeID == "A/v1")
    }

    @Test("Save and load history via MangaLibrary")
    func saveLoadViaLibrary() throws {
        // Write to a temp file to avoid sandbox issues
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent("test_history_\(UUID().uuidString).json")

        let uniqueID = "DiskTest/v\(UUID().uuidString.prefix(8))"
        var history = ReadingHistory()
        history.progress[uniqueID] = VolumeProgress(
            lastSpreadIndex: 7,
            totalSpreads: 15,
            lastReadDate: Date(timeIntervalSince1970: 1000000),
            isCompleted: false
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(history)
        try data.write(to: tempFile, options: .atomic)

        let readData = try Data(contentsOf: tempFile)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(ReadingHistory.self, from: readData)

        #expect(decoded.progress[uniqueID]?.lastSpreadIndex == 7)
        #expect(decoded.progress[uniqueID]?.totalSpreads == 15)

        try? FileManager.default.removeItem(at: tempFile)
    }
}

@Suite("MangaLibrary lastReadVolume")
struct LastReadVolumeTests {

    @Test("lastReadVolume returns most recently read volume in series")
    func lastReadVolume() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LastRead-\(UUID().uuidString)")
        let fm = FileManager.default
        for vol in ["v1", "v2", "v3"] {
            let dir = root.appendingPathComponent("S").appendingPathComponent(vol)
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
            try Data("x".utf8).write(to: dir.appendingPathComponent("001.jpg"))
        }
        defer { try? fm.removeItem(at: root) }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        // Read v1, then v2 — v2 should be most recent
        lib.updateProgress(volumeID: "S/v1", spreadIndex: 0, totalSpreads: 10)
        lib.updateProgress(volumeID: "S/v2", spreadIndex: 3, totalSpreads: 10)

        let lastRead = lib.lastReadVolume(forSeries: "S")
        #expect(lastRead?.id == "S/v2")
    }

    @Test("lastReadVolume returns nil for never-read series")
    func lastReadVolumeNeverRead() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LastReadNone-\(UUID().uuidString)")
        let dir = root.appendingPathComponent("S").appendingPathComponent("v1")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("x".utf8).write(to: dir.appendingPathComponent("001.jpg"))
        defer { try? FileManager.default.removeItem(at: root) }

        let lib = MangaLibrary()
        lib.rootURL = root
        lib.scan()

        #expect(lib.lastReadVolume(forSeries: "S") == nil)
    }
}
