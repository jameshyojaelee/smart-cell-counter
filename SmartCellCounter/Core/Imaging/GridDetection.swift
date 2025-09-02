import UIKit
import Vision
import CoreImage

public enum GridDetectionError: Error { case notFound }

public struct GridTunables {
    public var minimumSize: Float = 0.2
    public var quadratureTolerance: Float = 20
    public var minAspect: CGFloat = 0.9
    public var maxAspect: CGFloat = 1.1
    public init() {}
}

public enum GridDetector {
    public static func detectOuterFrame(in image: UIImage, tunables: GridTunables = GridTunables()) throws -> RectangleDetectionResult {
        guard let cg = image.cgImage else { throw GridDetectionError.notFound }
        let request = VNDetectRectanglesRequest()
        request.minimumSize = tunables.minimumSize
        request.quadratureTolerance = tunables.quadratureTolerance
        request.minimumAspectRatio = tunables.minAspect
        request.maximumAspectRatio = tunables.maxAspect
        request.minimumConfidence = 0.4
        let handler = VNImageRequestHandler(cgImage: cg, orientation: .up)
        try handler.perform([request])
        guard let rect = request.results?.first as? VNRectangleObservation else { throw GridDetectionError.notFound }
        let corners = [rect.topLeft, rect.topRight, rect.bottomRight, rect.bottomLeft].map { CGPoint(x: CGFloat($0.x) * image.size.width, y: (1 - CGFloat($0.y)) * image.size.height) }
        let bbox = CGRect(x: corners.map{$0.x}.min() ?? 0, y: corners.map{$0.y}.min() ?? 0, width: (corners.map{$0.x}.max() ?? 0) - (corners.map{$0.x}.min() ?? 0), height: (corners.map{$0.y}.max() ?? 0) - (corners.map{$0.y}.min() ?? 0))
        return RectangleDetectionResult(corners: corners, boundingBox: bbox)
    }
}

public enum PerspectiveCorrection {
    public static func correct(_ image: UIImage, corners: [CGPoint]) -> (corrected: UIImage, mapping: [CGPoint]) {
        let ci = CIImage(image: image)!
        let filter = CIFilter(name: "CIPerspectiveCorrection")!
        filter.setValue(ci, forKey: kCIInputImageKey)
        let tl = corners[0]; let tr = corners[1]; let br = corners[2]; let bl = corners[3]
        filter.setValue(CIVector(cgPoint: tl), forKey: "inputTopLeft")
        filter.setValue(CIVector(cgPoint: tr), forKey: "inputTopRight")
        filter.setValue(CIVector(cgPoint: bl), forKey: "inputBottomLeft")
        filter.setValue(CIVector(cgPoint: br), forKey: "inputBottomRight")
        let context = CIContext(options: [.useSoftwareRenderer: false])
        let out = filter.outputImage!.transformed(by: .identity)
        let cg = context.createCGImage(out, from: out.extent)!
        return (UIImage(cgImage: cg), corners)
    }
}
