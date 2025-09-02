import Foundation
import UIKit

public struct RectangleDetectionResult {
    public let found: Bool
    public let corners: [CGPoint] // in image coordinates, clockwise from topLeft
    public let confidence: Float
    public init(found: Bool, corners: [CGPoint], confidence: Float) {
        self.found = found
        self.corners = corners
        self.confidence = confidence
    }
}

public enum ThresholdMethod: String {
    case adaptive
    case otsu
}

public struct ImagingParams {
    public var thresholdMethod: ThresholdMethod = .adaptive
    public var blockSize: Int = 51 // odd, 31...101
    public var C: Int = 0 // -10...10
    public var minAreaUm2: Double = 50
    public var maxAreaUm2: Double = 5000
    public var useWatershed: Bool = true
    public init() {}
}

public struct SegmentationResult {
    public let width: Int
    public let height: Int
    // Binary mask; true = foreground (cell)
    public let mask: [Bool]
    public init(width: Int, height: Int, mask: [Bool]) {
        self.width = width
        self.height = height
        self.mask = mask
    }
}

public struct CellObject: Identifiable {
    public let id: Int
    public let pixelCount: Int
    public let areaPx: Double
    public let perimeterPx: Double
    public let circularity: Double
    public let solidity: Double
    public let centroid: CGPoint
    public let bbox: CGRect
}

public struct ColorSampleStats {
    public let hue: Double // 0...360
    public let saturation: Double // 0...1
    public let value: Double // 0...1
    public let L: Double // 0...100
    public let a: Double
    public let b: Double
}

public struct CellObjectLabeled: Identifiable {
    public let id: Int
    public let base: CellObject
    public let color: ColorSampleStats
    public let label: String // "live" or "dead"
    public let confidence: Double // 0...1
}

