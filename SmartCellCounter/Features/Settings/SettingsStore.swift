import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("dilutionFactor") var dilutionFactor: Double = 1.0 { didSet { clamp() } }
    @AppStorage("areaMinUm2") var areaMinUm2: Double = 50 { didSet { clamp() } }
    @AppStorage("areaMaxUm2") var areaMaxUm2: Double = 50000 { didSet { clamp() } }
    // Cell size (µm) for detection constraints
    @AppStorage("minCellDiameterUm") var minCellDiameterUm: Double = 8 { didSet { clamp() } }
    @AppStorage("maxCellDiameterUm") var maxCellDiameterUm: Double = 30 { didSet { clamp() } }
    // Color thresholds (HSV)
    @AppStorage("blueHueMin") var blueHueMin: Double = 200 { didSet { clamp() } }
    @AppStorage("blueHueMax") var blueHueMax: Double = 260 { didSet { clamp() } }
    @AppStorage("minBlueSaturation") var minBlueSaturation: Double = 0.30 { didSet { clamp() } }
    // Detection thresholds
    @AppStorage("blobScoreThreshold") var blobScoreThreshold: Double = 0.5 { didSet { clamp() } }
    @AppStorage("nmsIoU") var nmsIoU: Double = 0.3 { didSet { clamp() } }
    @AppStorage("focusMinLaplacian") var focusMinLaplacian: Double = 150 { didSet { clamp() } }
    @AppStorage("enableGridSuppression") var enableGridSuppression: Bool = true
    @AppStorage("thresholdMethod") var thresholdMethodRaw: String = ThresholdMethod.adaptive.rawValue
    @AppStorage("blockSize") var blockSize: Int = 51 { didSet { blockSize = max(31, min(101, blockSize | 1)) } }
    @AppStorage("thresholdC") var thresholdC: Int = 0 { didSet { thresholdC = max(-10, min(10, thresholdC)) } }

    var thresholdMethod: ThresholdMethod {
        get { ThresholdMethod(rawValue: thresholdMethodRaw) ?? .adaptive }
        set { thresholdMethodRaw = newValue.rawValue }
    }

    private func clamp() {
        dilutionFactor = max(0.1, dilutionFactor)
        if areaMinUm2 > areaMaxUm2 { areaMinUm2 = areaMaxUm2 }
        areaMinUm2 = max(1, areaMinUm2)
        areaMaxUm2 = min(1_000_000, max(areaMaxUm2, areaMinUm2))
        if minCellDiameterUm > maxCellDiameterUm { minCellDiameterUm = maxCellDiameterUm }
        minCellDiameterUm = max(1, minCellDiameterUm)
        maxCellDiameterUm = max(maxCellDiameterUm, minCellDiameterUm)
        if blueHueMin > blueHueMax { blueHueMin = blueHueMax }
        blueHueMin = max(0, min(360, blueHueMin))
        blueHueMax = max(0, min(360, blueHueMax))
        minBlueSaturation = max(0, min(1, minBlueSaturation))
        blobScoreThreshold = max(0, min(1, blobScoreThreshold))
        nmsIoU = max(0, min(1, nmsIoU))
        focusMinLaplacian = max(0, focusMinLaplacian)
    }

    func reset() {
        dilutionFactor = 1.0
        areaMinUm2 = 50
        areaMaxUm2 = 50000
        minCellDiameterUm = 8
        maxCellDiameterUm = 30
        blueHueMin = 200
        blueHueMax = 260
        minBlueSaturation = 0.30
        blobScoreThreshold = 0.5
        nmsIoU = 0.3
        focusMinLaplacian = 150
        enableGridSuppression = true
        thresholdMethod = .adaptive
        blockSize = 51
        thresholdC = 0
    }
}
