import Foundation

enum FolderAccess {
    private static let bookmarkKey = "MangaFolderBookmark"
    private static let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "webp"]

    static func enumerateImages(in url: URL) -> [URL] {
        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        return contents
            .filter { imageExtensions.contains($0.pathExtension.lowercased()) }
            .sorted { $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending }
    }

    static func saveBookmark(for url: URL) {
        guard let data = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return }
        UserDefaults.standard.set(data, forKey: bookmarkKey)
    }

    static func restoreBookmark() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }

        if isStale {
            // Refresh the bookmark
            saveBookmark(for: url)
        }
        return url
    }

    static func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }
}
