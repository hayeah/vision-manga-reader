import Foundation

struct ReaderWindowID: Codable, Hashable {
    var id: UUID
    var rootBookmark: Data
    var volumeID: String
    var spreadIndex: Int

    init(rootURL: URL, volumeID: String, spreadIndex: Int) throws {
        self.id = UUID()
        self.rootBookmark = try rootURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.volumeID = volumeID
        self.spreadIndex = spreadIndex
    }

    func resolveRoot() -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: rootBookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        // Stale bookmarks still resolve — the URL is usable,
        // but the bookmark data should ideally be refreshed.
        return url
    }

    // MARK: - Open windows persistence

    private static let storageKey = "OpenReaderWindows"

    static func saveOpenWindows(_ windows: [ReaderWindowID]) {
        guard let data = try? JSONEncoder().encode(windows) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }

    static func loadOpenWindows() -> [ReaderWindowID] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let windows = try? JSONDecoder().decode([ReaderWindowID].self, from: data) else {
            return []
        }
        return windows
    }

    static func addOpenWindow(_ windowID: ReaderWindowID) {
        var windows = loadOpenWindows()
        windows.removeAll { $0.id == windowID.id }
        windows.append(windowID)
        saveOpenWindows(windows)
    }

    static func removeOpenWindow(id: UUID) {
        var windows = loadOpenWindows()
        windows.removeAll { $0.id == id }
        saveOpenWindows(windows)
    }

    static func updateOpenWindow(_ windowID: ReaderWindowID) {
        var windows = loadOpenWindows()
        if let idx = windows.firstIndex(where: { $0.id == windowID.id }) {
            windows[idx] = windowID
            saveOpenWindows(windows)
        }
    }
}
