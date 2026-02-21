import Foundation
import CoreGraphics
import ImageIO
import Observation

enum SpreadLayout {
    case single(Int)        // one page shown alone (landscape or unpaired portrait)
    case pair(Int, Int)     // two portrait pages: (right, left) for RTL
}

@Observable
class MangaBook {
    var folderURL: URL?
    var pageURLs: [URL] = []
    var currentSpreadIndex: Int = 0
    private(set) var spreads: [SpreadLayout] = []
    private(set) var pageSizes: [CGSize] = []

    var spreadCount: Int { spreads.count }

    /// Returns page indices for a spread. RTL: right = earlier page, left = later page.
    func pagesForSpread(_ index: Int) -> (right: Int?, left: Int?) {
        guard index >= 0, index < spreads.count else { return (nil, nil) }
        switch spreads[index] {
        case .single(let page):
            return (right: page, left: nil)
        case .pair(let right, let left):
            return (right: right, left: left)
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

    /// Can +1 shift produce a new pair from the current spread?
    var canShiftForward: Bool {
        let pages = pagesForSpread(currentSpreadIndex)
        // Only works when currently on a pair
        guard pages.left != nil, let rightPage = pages.right else { return false }
        let nextRight = rightPage + 1
        // Need two portrait pages to form a new pair
        guard nextRight + 1 < pageURLs.count else { return false }
        return !isLandscape(pageSizes[nextRight]) && !isLandscape(pageSizes[nextRight + 1])
    }

    /// Shift forward by one page: pair [9,8] → single [8], then pair [10,9].
    func shiftPageForward() {
        guard canShiftForward else { return }
        let rightPage = pagesForSpread(currentSpreadIndex).right!

        // Keep spreads before current, orphan the right page as single, rebuild rest
        var result = Array(spreads.prefix(currentSpreadIndex))
        result.append(.single(rightPage))
        appendAutoSpreads(from: rightPage + 1, to: &result)
        spreads = result
        currentSpreadIndex += 1
    }

    func loadPages(from url: URL) {
        closeFolder()
        guard url.startAccessingSecurityScopedResource() else { return }
        folderURL = url
        pageURLs = FolderAccess.enumerateImages(in: url)
        buildSpreads()
        currentSpreadIndex = 0
    }

    func closeFolder() {
        folderURL?.stopAccessingSecurityScopedResource()
        folderURL = nil
        pageURLs = []
        spreads = []
        pageSizes = []
        currentSpreadIndex = 0
    }

    // MARK: - Smart spread layout

    private func buildSpreads() {
        pageSizes = pageURLs.map { Self.imageSize(for: $0) }
        var result: [SpreadLayout] = []
        appendAutoSpreads(from: 0, to: &result)
        spreads = result
    }

    /// Auto-detect and append spreads starting from page index `start`.
    private func appendAutoSpreads(from start: Int, to result: inout [SpreadLayout]) {
        var i = start
        while i < pageURLs.count {
            if isLandscape(pageSizes[i]) {
                result.append(.single(i))
                i += 1
            } else if i + 1 < pageURLs.count, !isLandscape(pageSizes[i + 1]) {
                result.append(.pair(i, i + 1))
                i += 2
            } else {
                result.append(.single(i))
                i += 1
            }
        }
    }

    private func isLandscape(_ size: CGSize) -> Bool {
        size.width > size.height
    }

    static func imageSize(for url: URL) -> CGSize {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let width = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let height = props[kCGImagePropertyPixelHeight] as? CGFloat
        else {
            return CGSize(width: 1, height: 2) // Default to portrait
        }
        // EXIF orientations 5–8 swap width and height
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        if orientation >= 5 && orientation <= 8 {
            return CGSize(width: height, height: width)
        }
        return CGSize(width: width, height: height)
    }

    deinit {
        folderURL?.stopAccessingSecurityScopedResource()
    }
}
