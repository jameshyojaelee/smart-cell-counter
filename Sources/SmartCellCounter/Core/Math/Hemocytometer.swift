import Foundation

/// Hemocytometer calculation utilities
public enum Hemocytometer {
    /// Concentration (cells/mL) = Average cells per square × 10^4 × Dilution factor
    /// - Parameters:
    ///   - avgCellsPerSquare: Average count across counted squares
    ///   - dilutionFactor: Sample dilution factor (default 1.0)
    /// - Returns: Concentration in cells per milliliter
    public static func concentration(avgCellsPerSquare: Double, dilutionFactor: Double = 1.0) -> Double {
        return avgCellsPerSquare * 10_000.0 * dilutionFactor
    }

    /// Viability (%) = (Live cells / Total cells) × 100
    /// - Parameters:
    ///   - live: Number of live cells
    ///   - dead: Number of dead cells
    /// - Returns: Viability percentage in [0, 100]
    public static func viability(live: Int, dead: Int) -> Double {
        let total = live + dead
        guard total > 0 else { return 0 }
        return (Double(live) / Double(total)) * 100.0
    }

    /// Convert pixel area to square microns using calibration (pixels per micron).
    /// area_um2 = pixelCount / (pxPerMicron^2)
    public static func areaUm2(pixelCount: Int, pxPerMicron: Double) -> Double {
        guard pxPerMicron > 0 else { return 0 }
        return Double(pixelCount) / (pxPerMicron * pxPerMicron)
    }
}
