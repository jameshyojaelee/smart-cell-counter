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

public enum ThresholdMethod: String, CaseIterable {
    case adaptive
    case otsu
}

public enum SegmentationStrategy: String, CaseIterable {
    case automatic
    case classical
    case coreML
}

public struct ImagingParams {
    public var strategy: SegmentationStrategy = .automatic
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
    public let downscaleFactor: Double
    public let polarityInverted: Bool
    public let usedStrategy: SegmentationStrategy
    public let originalSize: CGSize

    public init(width: Int,
                height: Int,
                mask: [Bool],
                downscaleFactor: Double = 1.0,
                polarityInverted: Bool = false,
                usedStrategy: SegmentationStrategy = .classical,
                originalSize: CGSize = .zero)
    {
        self.width = width
        self.height = height
        self.mask = mask
        self.downscaleFactor = max(downscaleFactor, 1.0)
        self.polarityInverted = polarityInverted
        self.usedStrategy = usedStrategy
        self.originalSize = originalSize == .zero ? CGSize(width: width, height: height) : originalSize
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

@MainActor
extension ImagingParams {
    static func from(_ store: SettingsStore) -> ImagingParams {
        var params = ImagingParams()
        params.strategy = store.segmentationStrategy
        params.thresholdMethod = store.thresholdMethod
        params.blockSize = store.blockSize
        params.C = store.thresholdC
        params.minAreaUm2 = store.areaMinUm2
        params.maxAreaUm2 = store.areaMaxUm2
        return params
    }
}
