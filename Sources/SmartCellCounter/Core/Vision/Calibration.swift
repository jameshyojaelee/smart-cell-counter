import CoreGraphics
import Foundation

public enum Calibration {
    public static func micronsPerPixel(squareWidthMicron: Double = 1000, squareWidthPixels: Double) -> Double {
        guard squareWidthPixels > 0 else { return 0 }
        return squareWidthMicron / squareWidthPixels
    }

    public static func pixelRadiusRange(minDiameterUm: Double, maxDiameterUm: Double, pxPerMicron: Double) -> (CGFloat, CGFloat) {
        let minR = CGFloat((minDiameterUm / 2.0) * pxPerMicron)
        let maxR = CGFloat((maxDiameterUm / 2.0) * pxPerMicron)
        return (minR, maxR)
    }
}
