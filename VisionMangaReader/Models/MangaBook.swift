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

    // Toggle support
    private var landscapeFlags: [Bool] = []
    private var portraitSequences: [(start: Int, count: Int)] = []
    private var shiftedSequences: Set<Int> = []
    // Maps each spread index to (sequenceIndex, localSpreadIndex); nil for landscape spreads
    private var spreadSequenceMap: [(seq: Int, local: Int)?] = []

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

    // MARK: - Shift toggle

    /// Whether the current spread can be shift-toggled (in a portrait sequence with ≥2 pages)
    var canToggleShift: Bool {
        guard currentSpreadIndex < spreadSequenceMap.count,
              let mapping = spreadSequenceMap[currentSpreadIndex] else { return false }
        return portraitSequences[mapping.seq].count >= 2
    }

    /// Whether the current spread's portrait sequence is shifted
    var isCurrentSequenceShifted: Bool {
        guard currentSpreadIndex < spreadSequenceMap.count,
              let mapping = spreadSequenceMap[currentSpreadIndex] else { return false }
        return shiftedSequences.contains(mapping.seq)
    }

    /// Toggle the shift state for the portrait sequence containing the current spread
    func toggleShift() {
        guard let mapping = spreadSequenceMap[currentSpreadIndex] else { return }
        let seqIdx = mapping.seq
        let localIdx = mapping.local

        if shiftedSequences.contains(seqIdx) {
            shiftedSequences.remove(seqIdx)
        } else {
            shiftedSequences.insert(seqIdx)
        }

        rebuildSpreads()

        // Restore position: same local index within the sequence, clamped
        if let seqStart = firstSpreadIndex(forSequence: seqIdx) {
            let count = spreadCount(forSequence: seqIdx)
            let clampedLocal = min(localIdx, count - 1)
            currentSpreadIndex = seqStart + clampedLocal
        }
    }

    // MARK: - Loading

    func loadPages(from url: URL) {
        closeFolder()
        guard url.startAccessingSecurityScopedResource() else { return }
        folderURL = url
        pageURLs = FolderAccess.enumerateImages(in: url)
        pageSizes = pageURLs.map { Self.imageSize(for: $0) }
        landscapeFlags = pageSizes.map { $0.width > $0.height }
        portraitSequences = findPortraitSequences()
        shiftedSequences = []
        rebuildSpreads()
        currentSpreadIndex = 0
    }

    func closeFolder() {
        folderURL?.stopAccessingSecurityScopedResource()
        folderURL = nil
        pageURLs = []
        spreads = []
        pageSizes = []
        landscapeFlags = []
        portraitSequences = []
        shiftedSequences = []
        spreadSequenceMap = []
        currentSpreadIndex = 0
    }

    // MARK: - Spread building

    private func findPortraitSequences() -> [(start: Int, count: Int)] {
        var sequences: [(start: Int, count: Int)] = []
        var i = 0
        while i < landscapeFlags.count {
            if !landscapeFlags[i] {
                let start = i
                while i < landscapeFlags.count && !landscapeFlags[i] {
                    i += 1
                }
                sequences.append((start: start, count: i - start))
            } else {
                i += 1
            }
        }
        return sequences
    }

    private func rebuildSpreads() {
        var result: [SpreadLayout] = []
        var seqMap: [(seq: Int, local: Int)?] = []
        var pageIdx = 0
        var seqIdx = 0

        while pageIdx < pageURLs.count {
            if landscapeFlags[pageIdx] {
                result.append(.single(pageIdx))
                seqMap.append(nil)
                pageIdx += 1
            } else {
                let seq = portraitSequences[seqIdx]
                let shifted = shiftedSequences.contains(seqIdx)
                let seqEnd = seq.start + seq.count
                var i = seq.start
                var localIdx = 0

                if shifted {
                    result.append(.single(i))
                    seqMap.append((seq: seqIdx, local: localIdx))
                    i += 1
                    localIdx += 1
                }

                while i < seqEnd {
                    if i + 1 < seqEnd {
                        result.append(.pair(i, i + 1))
                        seqMap.append((seq: seqIdx, local: localIdx))
                        i += 2
                    } else {
                        result.append(.single(i))
                        seqMap.append((seq: seqIdx, local: localIdx))
                        i += 1
                    }
                    localIdx += 1
                }

                pageIdx = seqEnd
                seqIdx += 1
            }
        }

        spreads = result
        spreadSequenceMap = seqMap
    }

    // MARK: - Helpers

    private func firstSpreadIndex(forSequence seqIdx: Int) -> Int? {
        for (i, m) in spreadSequenceMap.enumerated() {
            if let m = m, m.seq == seqIdx {
                return i
            }
        }
        return nil
    }

    private func spreadCount(forSequence seqIdx: Int) -> Int {
        spreadSequenceMap.compactMap { $0 }.filter { $0.seq == seqIdx }.count
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
