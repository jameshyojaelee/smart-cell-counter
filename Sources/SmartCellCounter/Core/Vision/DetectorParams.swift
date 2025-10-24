import Foundation

struct DetectorParams {
    let enableGridSuppression: Bool
    let blueHueMin: Double
    let blueHueMax: Double
    let minBlueSaturation: Double
    let blobScoreThreshold: Double
    let nmsIoU: Double
    let minCellDiameterUm: Double
    let maxCellDiameterUm: Double
}

@MainActor
extension DetectorParams {
    static func from(_ s: SettingsStore) -> DetectorParams {
        DetectorParams(
            enableGridSuppression: s.enableGridSuppression,
            blueHueMin: s.blueHueMin,
            blueHueMax: s.blueHueMax,
            minBlueSaturation: s.minBlueSaturation,
            blobScoreThreshold: s.blobScoreThreshold,
            nmsIoU: s.nmsIoU,
            minCellDiameterUm: s.minCellDiameterUm,
            maxCellDiameterUm: s.maxCellDiameterUm
        )
    }
}
