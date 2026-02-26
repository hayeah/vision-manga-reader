import UIKit
import Vision
import CoreImage

enum SubjectExtractor {
    static func extractSubject(from image: UIImage) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage)

        do {
            try handler.perform([request])

            guard let result = request.results?.first else { return nil }

            let mask = try result.generateScaledMaskForImage(
                forInstances: result.allInstances,
                from: handler
            )

            let maskCI = CIImage(cvPixelBuffer: mask)

            let filter = CIFilter.blendWithMask()
            filter.inputImage = ciImage
            filter.maskImage = maskCI
            filter.backgroundImage = CIImage.empty()

            guard let output = filter.outputImage else { return nil }

            let context = CIContext()
            guard let cgImage = context.createCGImage(output, from: output.extent) else { return nil }
            let subjectImage = UIImage(cgImage: cgImage)
            return trimTransparentEdges(from: subjectImage)
        } catch {
            print("Subject extraction failed: \(error)")
            return nil
        }
    }

    private static func trimTransparentEdges(from image: UIImage, threshold: UInt8 = 8, padding: Int = 8) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let width = cgImage.width
        let height = cgImage.height
        guard width > 0, height > 0 else { return image }

        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = bytesPerRow * height
        var pixels = [UInt8](repeating: 0, count: totalBytes)

        guard let context = CGContext(
            data: &pixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        ) else {
            return image
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        var minX = width
        var minY = height
        var maxX = -1
        var maxY = -1

        for y in 0..<height {
            for x in 0..<width {
                let alpha = pixels[y * bytesPerRow + x * bytesPerPixel + 3]
                if alpha > threshold {
                    minX = min(minX, x)
                    minY = min(minY, y)
                    maxX = max(maxX, x)
                    maxY = max(maxY, y)
                }
            }
        }

        guard maxX >= minX, maxY >= minY else {
            return image
        }

        let cropMinX = max(0, minX - padding)
        let cropMinY = max(0, minY - padding)
        let cropMaxX = min(width - 1, maxX + padding)
        let cropMaxY = min(height - 1, maxY + padding)
        let cropRect = CGRect(
            x: cropMinX,
            y: cropMinY,
            width: cropMaxX - cropMinX + 1,
            height: cropMaxY - cropMinY + 1
        )

        guard let cropped = cgImage.cropping(to: cropRect) else {
            return image
        }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }

    static func copyToClipboard(_ image: UIImage) {
        guard let pngData = image.pngData() else { return }
        UIPasteboard.general.setData(pngData, forPasteboardType: "public.png")
    }
}
