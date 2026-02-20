import UIKit

actor ImageLoader {
    static let shared = ImageLoader()

    private let cache = NSCache<NSURL, UIImage>()
    private var inFlightTasks: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.totalCostLimit = 200 * 1024 * 1024 // 200MB
    }

    func load(url: URL) async -> UIImage? {
        if let cached = cache.object(forKey: url as NSURL) {
            return cached
        }

        if let existing = inFlightTasks[url] {
            return await existing.value
        }

        let task = Task<UIImage?, Never> {
            guard let image = await downsampledImage(at: url, maxDimension: 4096) else {
                return nil
            }
            let cost = Int(image.size.width * image.size.height * 4)
            cache.setObject(image, forKey: url as NSURL, cost: cost)
            return image
        }

        inFlightTasks[url] = task
        let result = await task.value
        inFlightTasks.removeValue(forKey: url)
        return result
    }

    private func downsampledImage(at url: URL, maxDimension: CGFloat) async -> UIImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }

        let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any]
        let width = properties?[kCGImagePropertyPixelWidth] as? CGFloat ?? 0
        let height = properties?[kCGImagePropertyPixelHeight] as? CGFloat ?? 0

        let maxSide = max(width, height)
        let options: [CFString: Any]
        if maxSide > maxDimension {
            options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: maxDimension,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
            ]
        } else {
            options = [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceShouldCacheImmediately: true,
            ]
        }

        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }
}
