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

            return UIImage(cgImage: cgImage)
        } catch {
            print("Subject extraction failed: \(error)")
            return nil
        }
    }

    static func copyToClipboard(_ image: UIImage) {
        guard let pngData = image.pngData() else { return }
        UIPasteboard.general.setData(pngData, forPasteboardType: "public.png")
    }
}
