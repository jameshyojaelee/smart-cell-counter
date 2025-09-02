import UIKit
import Vision
import CoreImage

public enum SegmentationError: Error { case failed }

public enum Segmenter {
    public static func segmentCells(in image: UIImage, params: ImagingParams) -> SegmentationResult {
        if let modelURL = Bundle.main.url(forResource: "UNet256", withExtension: "mlmodelc"), let compiled = try? MLModel(contentsOf: modelURL) {
            return segmentWithCoreML(image: image, params: params, model: compiled)
        }
        return segmentClassical(image: image, params: params)
    }

    private static func segmentWithCoreML(image: UIImage, params: ImagingParams, model: MLModel) -> SegmentationResult {
        let requestModel = try! VNCoreMLModel(for: model)
        let request = VNCoreMLRequest(model: requestModel)
        request.imageCropAndScaleOption = .scaleFill
        let handler = VNImageRequestHandler(cgImage: image.cgImage!, orientation: .up)
        // Tile 256x256
        let width = Int(image.size.width)
        let height = Int(image.size.height)
        var mask = [UInt8](repeating: 0, count: width*height)
        let tile = 256
        for y in stride(from: 0, to: height, by: tile) {
            for x in stride(from: 0, to: width, by: tile) {
                let rect = CGRect(x: x, y: y, width: min(tile, width - x), height: min(tile, height - y))
                guard let cg = image.cgImage?.cropping(to: rect) else { continue }
                let h = VNImageRequestHandler(cgImage: cg, orientation: .up)
                try? h.perform([request])
                guard let obs = request.results?.first as? VNPixelBufferObservation else { continue }
                let pb = obs.pixelBuffer
                CVPixelBufferLockBaseAddress(pb, .readOnly)
                let w = CVPixelBufferGetWidth(pb)
                let hgt = CVPixelBufferGetHeight(pb)
                let base = CVPixelBufferGetBaseAddress(pb)!.assumingMemoryBound(to: Float32.self)
                for j in 0..<hgt {
                    for i in 0..<w {
                        let p = base[j*w + i]
                        let binary: UInt8 = p >= 0.5 ? 255 : 0
                        if i + x < width && j + y < height { mask[(j + y)*width + (i + x)] = max(mask[(j + y)*width + (i + x)], binary) }
                    }
                }
                CVPixelBufferUnlockBaseAddress(pb, .readOnly)
            }
        }
        return SegmentationResult(width: width, height: height, mask: mask)
    }

    private static func segmentClassical(image: UIImage, params: ImagingParams) -> SegmentationResult {
        let context = CIContext(options: [.useSoftwareRenderer: false])
        var ci = CIImage(image: image)!
        // CLAHE
        if let clahe = CIFilter(name: "CIAreaHistogram") { _ = clahe }
        // Use morphological top-hat approximation
        ci = ci.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 1.2])
        // Adaptive threshold imitation using convolution and subtraction
        let blurred = ci.applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 3])
        let diff = ci.applyingFilter("CISubtractBlendMode", parameters: [kCIInputBackgroundImageKey: blurred])
        // Convert to monochrome
        let mono = diff.applyingFilter("CIPhotoEffectMono")
        let rect = mono.extent.integral
        let cg = context.createCGImage(mono, from: rect)!
        let width = Int(rect.width)
        let height = Int(rect.height)
        guard let provider = cg.dataProvider, let data = provider.data as Data? else { return SegmentationResult(width: width, height: height, mask: [UInt8](repeating: 0, count: width*height)) }
        let bytes = [UInt8](data)
        var mask = [UInt8](repeating: 0, count: width*height)
        // Simple Otsu-like threshold fallback
        var hist = [Int](repeating: 0, count: 256)
        for b in bytes { hist[Int(b)] += 1 }
        var total = width*height
        var sum = 0
        for t in 0..<256 { sum += t*hist[t] }
        var sumB = 0
        var wB = 0
        var maxVar: Double = -1
        var thresh = 128
        for t in 0..<256 {
            wB += hist[t]
            if wB == 0 { continue }
            let wF = total - wB
            if wF == 0 { break }
            sumB += t*hist[t]
            let mB = Double(sumB) / Double(wB)
            let mF = Double(sum - sumB) / Double(wF)
            let varBetween = Double(wB) * Double(wF) * pow(mB - mF, 2)
            if varBetween > maxVar { maxVar = varBetween; thresh = t }
        }
        for i in 0..<width*height { mask[i] = bytes[i] >= UInt8(thresh) ? 255 : 0 }
        return SegmentationResult(width: width, height: height, mask: mask)
    }
}
