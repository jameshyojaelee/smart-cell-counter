import Foundation

public struct ColorStats {
    public let hue: Double
    public let saturation: Double
    public let value: Double
}

public struct ViabilityResult {
    public let isLive: Bool
    public let confidence: Double
    public let reason: String
}

public protocol ViabilityClassifier {
    func classify(_ stats: ColorStats) -> ViabilityResult
}

public enum Viability {}

