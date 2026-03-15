import Foundation
import Observation

@Observable
class MangaLibrary {
    internal(set) var rootURL: URL?
    private(set) var series: [MangaSeries] = []
    private(set) var history: ReadingHistory = ReadingHistory()

    private static let rootBookmarkKey = "MangaLibraryRootBookmark"
    private static let historyFileName = "reading_history.json"

    // MARK: - Root bookmark

    func setRoot(_ url: URL) {
        rootURL?.stopAccessingSecurityScopedResource()
        guard url.startAccessingSecurityScopedResource() else { return }
        rootURL = url
        saveRootBookmark(url)
        scan()
    }

    func restoreRoot() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.rootBookmarkKey) else { return false }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return false }

        if isStale {
            saveRootBookmark(url)
        }

        guard url.startAccessingSecurityScopedResource() else { return false }
        rootURL = url
        scan()
        return true
    }

    private func saveRootBookmark(_ url: URL) {
        guard let data = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: Self.rootBookmarkKey)
    }

    // MARK: - Scanning

    func scan() {
        guard let rootURL else { return }
        let fm = FileManager.default

        guard let seriesDirs = try? fm.contentsOfDirectory(
            at: rootURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            series = []
            return
        }

        series = seriesDirs
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .map { seriesURL in
                let seriesName = seriesURL.lastPathComponent
                let title = infoJSONTitle(at: seriesURL) ?? seriesName
                let volumes = enumerateVolumes(in: seriesURL, seriesID: seriesName)
                return MangaSeries(id: seriesName, url: seriesURL, title: title, volumes: volumes)
            }
    }

    private func enumerateVolumes(in seriesURL: URL, seriesID: String) -> [MangaVolume] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: seriesURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .filter { url in
                (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true
            }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
            .enumerated()
            .map { (index, url) in
                let name = url.lastPathComponent
                return MangaVolume(
                    id: "\(seriesID)/\(name)",
                    url: url,
                    title: name,
                    seriesID: seriesID,
                    sortIndex: index
                )
            }
    }

    private func infoJSONTitle(at seriesURL: URL) -> String? {
        let infoURL = seriesURL.appendingPathComponent("info.json")
        guard let data = try? Data(contentsOf: infoURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String else {
            return nil
        }
        return title
    }

    // MARK: - Volume lookup

    func volume(id: String) -> MangaVolume? {
        for s in series {
            if let v = s.volumes.first(where: { $0.id == id }) {
                return v
            }
        }
        return nil
    }

    func nextVolume(after volumeID: String) -> MangaVolume? {
        for s in series {
            if let idx = s.volumes.firstIndex(where: { $0.id == volumeID }),
               idx + 1 < s.volumes.count {
                return s.volumes[idx + 1]
            }
        }
        return nil
    }

    func seriesFor(volumeID: String) -> MangaSeries? {
        let seriesID = volumeID.components(separatedBy: "/").first ?? ""
        return series.first(where: { $0.id == seriesID })
    }

    // MARK: - Reading history persistence

    func loadHistory() {
        guard let url = historyFileURL(),
              let data = try? Data(contentsOf: url) else { return }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let decoded = try? decoder.decode(ReadingHistory.self, from: data) {
            history = decoded
        }
    }

    func saveHistory() {
        guard let url = historyFileURL() else { return }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(history) else { return }
        try? data.write(to: url, options: .atomic)
    }

    func updateProgress(volumeID: String, spreadIndex: Int, totalSpreads: Int) {
        let isCompleted = spreadIndex >= totalSpreads - 1
        history.progress[volumeID] = VolumeProgress(
            lastSpreadIndex: spreadIndex,
            totalSpreads: totalSpreads,
            lastReadDate: Date(),
            isCompleted: isCompleted
        )
        history.lastActiveVolumeID = volumeID

        // Update recent series
        let seriesID = volumeID.components(separatedBy: "/").first ?? ""
        history.recentSeriesIDs.removeAll { $0 == seriesID }
        history.recentSeriesIDs.insert(seriesID, at: 0)
        if history.recentSeriesIDs.count > 20 {
            history.recentSeriesIDs = Array(history.recentSeriesIDs.prefix(20))
        }

        saveHistory()
    }

    func lastReadVolume(forSeries seriesID: String) -> MangaVolume? {
        guard let s = series.first(where: { $0.id == seriesID }) else { return nil }
        // Find the most recently read volume in this series
        var latest: (MangaVolume, Date)?
        for vol in s.volumes {
            if let prog = history.progress[vol.id] {
                if latest == nil || prog.lastReadDate > latest!.1 {
                    latest = (vol, prog.lastReadDate)
                }
            }
        }
        return latest?.0
    }

    private func historyFileURL() -> URL? {
        guard let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        return dir.appendingPathComponent(Self.historyFileName)
    }

    deinit {
        rootURL?.stopAccessingSecurityScopedResource()
    }
}
