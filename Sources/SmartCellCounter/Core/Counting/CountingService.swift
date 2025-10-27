import CoreGraphics
import Foundation

public protocol InclusionRules {
    func include(x: Double, y: Double, in rect: CGRect) -> Bool
}

public protocol Aggregator {
    func averageCounts(_ counts: [Int]) -> Double
}

public enum Counting {}

// MARK: - Grid Geometry for Neubauer Improved

public struct GridGeometry {
    public let originPx: CGPoint // top-left of grid in pixels (corrected image)
    public let pxPerMicron: Double // scale factor
    public let widthMicron: Double // usually 3000 µm
    public let heightMicron: Double // usually 3000 µm
    public let largeSizeUm: Double // 1000 µm
    public let smallSizeUm: Double // 50 µm

    public init(originPx: CGPoint, pxPerMicron: Double, widthMicron: Double = 3000, heightMicron: Double = 3000, largeSizeUm: Double = 1000, smallSizeUm: Double = 50) {
        self.originPx = originPx
        self.pxPerMicron = pxPerMicron
        self.widthMicron = widthMicron
        self.heightMicron = heightMicron
        self.largeSizeUm = largeSizeUm
        self.smallSizeUm = smallSizeUm
    }
}

public struct GridIndex: Equatable {
    public let largeX: Int // 0..2
    public let largeY: Int // 0..2
    public let smallX: Int // 0..19 within large
    public let smallY: Int // 0..19 within large
    public var largeIndex: Int { largeY * 3 + largeX }
    public var smallIndex: Int { smallY * 20 + smallX }
}

public enum CountingService {
    // Include top and left borders, exclude bottom and right
    public static func mapCentroidToGrid(ptPx: CGPoint, geometry: GridGeometry) -> GridIndex? {
        let xPx = Double(ptPx.x - geometry.originPx.x)
        let yPx = Double(ptPx.y - geometry.originPx.y)
        let uUm = xPx / geometry.pxPerMicron
        let vUm = yPx / geometry.pxPerMicron
        guard uUm >= 0, vUm >= 0, uUm < geometry.widthMicron, vUm < geometry.heightMicron else {
            return nil // Outside or on right/bottom border
        }
        // Snap boundary points to top/left by nudging epsilon when exactly on grid line
        let uAdj = adjustToTopLeft(uUm, step: geometry.smallSizeUm)
        let vAdj = adjustToTopLeft(vUm, step: geometry.smallSizeUm)

        let largeX = Int(uAdj / geometry.largeSizeUm)
        let largeY = Int(vAdj / geometry.largeSizeUm)
        let localX = uAdj - Double(largeX) * geometry.largeSizeUm
        let localY = vAdj - Double(largeY) * geometry.largeSizeUm
        let smallX = Int(localX / geometry.smallSizeUm) // 0..19
        let smallY = Int(localY / geometry.smallSizeUm)
        guard (0 ... 2).contains(largeX), (0 ... 2).contains(largeY), (0 ... 19).contains(smallX), (0 ... 19).contains(smallY) else {
            return nil
        }
        return GridIndex(largeX: largeX, largeY: largeY, smallX: smallX, smallY: smallY)
    }

    private static func adjustToTopLeft(_ value: Double, step: Double) -> Double {
        let r = value.truncatingRemainder(dividingBy: step)
        if r == 0, value > 0 { // exactly on a gridline (not the origin)
            return value - 1e-9
        }
        return value
    }

    // Tally counts per large square (0..8) using centroid mapping
    public static func tallyByLargeSquare(objects: [CellObject], geometry: GridGeometry) -> [Int: Int] {
        let start = Date()
        var tally: [Int: Int] = [:]
        for obj in objects {
            if let idx = mapCentroidToGrid(ptPx: obj.centroid, geometry: geometry)?.largeIndex {
                tally[idx, default: 0] += 1
            }
        }
        let ms = Date().timeIntervalSince(start) * 1000
        PerformanceLogger.shared.record(stage: .counting, duration: ms, metadata: ["objects": "\(objects.count)"])
        PerformanceLogger.shared.record("counting", ms)
        return tally
    }

    // MAD-based outlier rejection mask for counts
    public static func robustInliers(_ values: [Double], threshold: Double = 2.5) -> [Bool] {
        guard !values.isEmpty else { return [] }
        let m = median(values)
        let deviations = values.map { abs($0 - m) }
        let mad = median(deviations)
        guard mad > 0 else { return Array(repeating: true, count: values.count) }
        return values.map { val in
            let score = 0.6745 * (val - m) / mad
            return abs(score) <= threshold
        }
    }

    public static func meanCountPerLargeSquare(countsByIndex: [Int: Int], selectedLargeIndices: [Int] = [0, 2, 6, 8], outlierThreshold: Double? = 2.5) -> Double {
        let counts = selectedLargeIndices.compactMap { countsByIndex[$0] }.map(Double.init)
        guard !counts.isEmpty else { return 0 }
        if let t = outlierThreshold {
            let mask = robustInliers(counts, threshold: t)
            let filtered = zip(counts, mask).compactMap { $1 ? $0 : nil }
            let arr = filtered.isEmpty ? counts : filtered
            return arr.reduce(0, +) / Double(arr.count)
        } else {
            return counts.reduce(0, +) / Double(counts.count)
        }
    }

    public static func concentrationPerML(meanCountPerLargeSquare: Double, dilutionFactor: Double) -> Double {
        Hemocytometer.concentration(avgCellsPerSquare: meanCountPerLargeSquare, dilutionFactor: dilutionFactor)
    }

    public static func viabilityPercent(live: Int, dead: Int) -> Double { Hemocytometer.viability(live: live, dead: dead) }

    // Seeding calculator
    public static func seedingVolume(targetCells: Int,
                                     finalVolumeML: Double,
                                     concentrationPerML: Double,
                                     meanCountPerLargeSquare: Double,
                                     densityLimits: (min: Double, max: Double) = (10, 300)) -> (volumeToAddML: Double, guidance: String)
    {
        guard concentrationPerML > 0 else { return (0, "Concentration is zero; cannot compute volume.") }
        let vol = Double(targetCells) / concentrationPerML // mL to add
        var notes: [String] = []
        if meanCountPerLargeSquare > densityLimits.max {
            notes.append("Overcrowding detected (\(Int(meanCountPerLargeSquare))). Consider increasing dilution.")
        } else if meanCountPerLargeSquare < densityLimits.min {
            notes.append("Low density detected (\(Int(meanCountPerLargeSquare))). Consider reducing dilution.")
        }
        if vol > finalVolumeML {
            notes.append("Required volume (\(String(format: "%.2f", vol)) mL) exceeds final volume (\(String(format: "%.2f", finalVolumeML)) mL). Consider concentrating the sample.")
        }
        let guidance = notes.isEmpty ? "Proceed with \(String(format: "%.2f", vol)) mL into \(String(format: "%.2f", finalVolumeML)) mL." : notes.joined(separator: " ")
        return (vol, guidance)
    }

    // MARK: - Private helpers

    private static func median(_ xs: [Double]) -> Double {
        let n = xs.count
        if n == 0 { return 0 }
        let sorted = xs.sorted()
        if n % 2 == 1 { return sorted[n / 2] }
        return 0.5 * (sorted[n / 2 - 1] + sorted[n / 2])
    }
}
