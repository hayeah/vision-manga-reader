import Foundation

struct ReaderWindowID: Codable, Hashable {
    var id: UUID
    var folderBookmark: Data
    var spreadIndex: Int
    var offset: Int

    init(folderURL: URL, spreadIndex: Int, offset: Int) throws {
        self.id = UUID()
        self.folderBookmark = try folderURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        self.spreadIndex = spreadIndex
        self.offset = offset
    }

    func resolveFolder() -> URL? {
        var isStale = false
        guard let url = try? URL(
            resolvingBookmarkData: folderBookmark,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        ) else { return nil }
        if isStale { return nil }
        return url
    }
}
