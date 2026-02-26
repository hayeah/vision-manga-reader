import UIKit
import Vision
import CoreImage
import CoreVideo

enum SubjectExtractor {
    private static func instanceID(
        at normalizedPoint: CGPoint,
        in observation: VNInstanceMaskObservation
    ) -> Int? {
        let maskBuffer = observation.instanceMask
        CVPixelBufferLockBaseAddress(maskBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(maskBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(maskBuffer)
        let height = CVPixelBufferGetHeight(maskBuffer)
        guard width > 0, height > 0 else { return nil }

        func readLabel(x: Int, y: Int) -> Int? {
            guard x >= 0, x < width, y >= 0, y < height else { return nil }

            let format = CVPixelBufferGetPixelFormatType(maskBuffer)
            let planeCount = CVPixelBufferGetPlaneCount(maskBuffer)
            let usesPlane0 = planeCount > 0
            let rowBytes = usesPlane0
                ? CVPixelBufferGetBytesPerRowOfPlane(maskBuffer, 0)
                : CVPixelBufferGetBytesPerRow(maskBuffer)
            guard rowBytes > 0 else { return nil }

            let baseAddress = usesPlane0
                ? CVPixelBufferGetBaseAddressOfPlane(maskBuffer, 0)
                : CVPixelBufferGetBaseAddress(maskBuffer)
            guard let baseAddress else { return nil }

            switch format {
            case kCVPixelFormatType_OneComponent8:
                let ptr = baseAddress.assumingMemoryBound(to: UInt8.self)
                return Int(ptr[y * rowBytes + x])
            case kCVPixelFormatType_OneComponent16:
                let ptr = baseAddress.assumingMemoryBound(to: UInt16.self)
                let elementStride = rowBytes / MemoryLayout<UInt16>.size
                return Int(ptr[y * elementStride + x])
            case kCVPixelFormatType_OneComponent32Float:
                let ptr = baseAddress.assumingMemoryBound(to: Float32.self)
                let elementStride = rowBytes / MemoryLayout<Float32>.size
                return Int(ptr[y * elementStride + x].rounded())
            default:
                return nil
            }
        }

        // Probe both vertical orientations and a small neighborhood around pinch.
        let x = Int((min(max(normalizedPoint.x, 0), 1) * CGFloat(width - 1)).rounded())
        let yLowerLeft = Int((min(max(normalizedPoint.y, 0), 1) * CGFloat(height - 1)).rounded())
        let yUpperLeft = (height - 1) - yLowerLeft

        let candidateYs = [yLowerLeft, yUpperLeft]
        for baseY in candidateYs {
            for dy in -2...2 {
                for dx in -2...2 {
                    if let label = readLabel(x: x + dx, y: baseY + dy),
                       label > 0,
                       observation.allInstances.contains(label) {
                        return label
                    }
                }
            }
        }
        return nil
    }

    static func extractSubject(from image: UIImage, at normalizedPoint: CGPoint, trimOutput: Bool = true) async -> UIImage? {
        guard let ciImage = CIImage(image: image) else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(ciImage: ciImage)

        do {
            try handler.perform([request])

            guard let result = request.results?.first else { return nil }

            // Conservative mode: only select the instance under pinch.
            // If this feels too strict later, switch this to `result.allInstances`.
            guard let pickedID = instanceID(at: normalizedPoint, in: result) else { return nil }
            let pickedInstances = IndexSet(integer: pickedID)

            let mask = try result.generateScaledMaskForImage(
                forInstances: pickedInstances,
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
            if trimOutput {
                return trimTransparentEdges(from: subjectImage)
            }
            return subjectImage
        } catch {
            print("Subject extraction failed: \(error)")
            return nil
        }
    }

    static func trimmedSubjectImage(from image: UIImage) -> UIImage {
        trimTransparentEdges(from: image)
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
