import Foundation

struct ReaderWindowState: Codable, Hashable {
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
        return url
    }
}
