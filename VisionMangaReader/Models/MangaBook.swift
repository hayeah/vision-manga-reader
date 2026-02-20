import Foundation
import Observation

@Observable
class MangaBook {
    var folderURL: URL?
    var pageURLs: [URL] = []
    var currentSpreadIndex: Int = 0
    var offset: Int = 0 // 0 = normal pairing, 1 = first page alone (cover)

    var spreadCount: Int {
        guard !pageURLs.isEmpty else { return 0 }
        let effectivePages = pageURLs.count - offset
        if effectivePages <= 0 { return offset > 0 ? 1 : 0 }
        // offset pages form spread 0 alone, then pairs
        let pairedSpreads = (effectivePages + 1) / 2
        return offset > 0 ? 1 + pairedSpreads : pairedSpreads
    }

    /// Returns page indices for a spread. RTL: right = earlier page, left = later page.
    func pagesForSpread(_ index: Int) -> (right: Int?, left: Int?) {
        guard !pageURLs.isEmpty else { return (nil, nil) }

        if offset == 1 {
            if index == 0 {
                // Cover page alone
                return (right: 0, left: nil)
            }
            // After cover, pairs start at page index 1
            let base = 1 + (index - 1) * 2
            let rightPage = base
            let leftPage = base + 1
            if rightPage >= pageURLs.count { return (nil, nil) }
            if leftPage >= pageURLs.count { return (right: rightPage, left: nil) }
            return (right: rightPage, left: leftPage)
        } else {
            // offset == 0: normal pairing (0,1), (2,3), ...
            let base = index * 2
            let rightPage = base
            let leftPage = base + 1
            if rightPage >= pageURLs.count { return (nil, nil) }
            if leftPage >= pageURLs.count { return (right: rightPage, left: nil) }
            return (right: rightPage, left: leftPage)
        }
    }

    func nextSpread() {
        if currentSpreadIndex < spreadCount - 1 {
            currentSpreadIndex += 1
        }
    }

    func previousSpread() {
        if currentSpreadIndex > 0 {
            currentSpreadIndex -= 1
        }
    }

    func toggleOffset() {
        shiftOffset(by: offset == 0 ? 1 : -1)
    }

    /// Shift offset by delta, keeping the view near the same page.
    func shiftOffset(by delta: Int) {
        // Find the first page currently visible
        let currentPages = pagesForSpread(currentSpreadIndex)
        let anchorPage = currentPages.right ?? 0

        offset = max(0, min(offset + delta, pageURLs.count - 1))

        // Find the spread that contains anchorPage under the new offset
        if offset == 0 {
            currentSpreadIndex = anchorPage / 2
        } else {
            if anchorPage == 0 {
                currentSpreadIndex = 0
            } else {
                currentSpreadIndex = 1 + (anchorPage - 1) / 2
            }
        }

        // Clamp
        let maxIndex = max(0, spreadCount - 1)
        currentSpreadIndex = min(currentSpreadIndex, maxIndex)
    }

    func loadPages(from url: URL) {
        closeFolder()
        guard url.startAccessingSecurityScopedResource() else { return }
        folderURL = url
        pageURLs = FolderAccess.enumerateImages(in: url)
        currentSpreadIndex = 0
    }

    func closeFolder() {
        folderURL?.stopAccessingSecurityScopedResource()
        folderURL = nil
        pageURLs = []
        currentSpreadIndex = 0
    }

    deinit {
        folderURL?.stopAccessingSecurityScopedResource()
    }
}
