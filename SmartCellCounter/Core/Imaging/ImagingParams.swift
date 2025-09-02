import UIKit
import CoreGraphics

public enum ThresholdMethod: String {
    case adaptive
    case otsu
}

public struct ImagingParams {
    public var thresholdMethod: ThresholdMethod
    public var blockSize: Int
    public var c: Int
    public var minAreaUm2: Double
    public var maxAreaUm2: Double
    public var useWatershed: Bool

    public init(
        thresholdMethod: ThresholdMethod = .adaptive,
        blockSize: Int = 51,
        c: Int = -2,
        minAreaUm2: Double = 50,
        maxAreaUm2: Double = 5000,
        useWatershed: Bool = true
    ) {
        self.thresholdMethod = thresholdMethod
        self.blockSize = max(31, min(101, blockSize | 1)) // force odd within range
        self.c = max(-10, min(10, c))
        self.minAreaUm2 = minAreaUm2
        self.maxAreaUm2 = maxAreaUm2
        self.useWatershed = useWatershed
    }
}

public struct RectangleDetectionResult {
    public let corners: [CGPoint] // in image space: topLeft, topRight, bottomRight, bottomLeft
    public let boundingBox: CGRect
}

public struct SegmentationResult {
    public let width: Int
    public let height: Int
    public let mask: [UInt8] // 0 or 255
}

public struct CellObject: Identifiable {
    public struct BoundingBox { public let x: Int; public let y: Int; public let width: Int; public let height: Int }

    public let id: Int
    public let areaPx: Int
    public let perimeterPx: Int
    public let circularity: Double
    public let solidity: Double
    public let centroid: CGPoint
    public let bbox: BoundingBox
}

public struct CellObjectLabeled: Identifiable {
    public let id: Int
    public let base: CellObject
    public let isDead: Bool
    public let confidence: Double
    public let hsv: (h: Double, s: Double, v: Double)
    public let lab: (l: Double, a: Double, b: Double)
}
