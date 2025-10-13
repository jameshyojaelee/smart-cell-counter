import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("dilutionFactor") var dilutionFactor: Double = 1.0 {
        didSet { normalize(\.dilutionFactor) { max(0.1, $0) } }
    }
    @AppStorage("areaMinUm2") var areaMinUm2: Double = 50 {
        didSet { normalize(\.areaMinUm2) { min(max($0, 1), min(1_000_000, areaMaxUm2)) } }
    }
    @AppStorage("areaMaxUm2") var areaMaxUm2: Double = 50000 {
        didSet { normalize(\.areaMaxUm2) { min(1_000_000, max($0, areaMinUm2)) } }
    }
    // Cell size (µm) for detection constraints
    @AppStorage("minCellDiameterUm") var minCellDiameterUm: Double = 8 {
        didSet { normalize(\.minCellDiameterUm) { min(max($0, 1), maxCellDiameterUm) } }
    }
    @AppStorage("maxCellDiameterUm") var maxCellDiameterUm: Double = 30 {
        didSet { normalize(\.maxCellDiameterUm) { max(minCellDiameterUm, min($0, 200)) } }
    }
    // Color thresholds (HSV)
    @AppStorage("blueHueMin") var blueHueMin: Double = 200 {
        didSet { normalize(\.blueHueMin) { min(max($0, 0), min(360, blueHueMax)) } }
    }
    @AppStorage("blueHueMax") var blueHueMax: Double = 260 {
        didSet { normalize(\.blueHueMax) { max(blueHueMin, min($0, 360)) } }
    }
    @AppStorage("minBlueSaturation") var minBlueSaturation: Double = 0.30 {
        didSet { normalize(\.minBlueSaturation) { min(max($0, 0), 1) } }
    }
    // Detection thresholds
    @AppStorage("blobScoreThreshold") var blobScoreThreshold: Double = 0.5 {
        didSet { normalize(\.blobScoreThreshold) { min(max($0, 0), 1) } }
    }
    @AppStorage("nmsIoU") var nmsIoU: Double = 0.3 {
        didSet { normalize(\.nmsIoU) { min(max($0, 0), 1) } }
    }
    @AppStorage("focusMinLaplacian") var focusMinLaplacian: Double = 150 {
        didSet { normalize(\.focusMinLaplacian) { max($0, 0) } }
    }
    @AppStorage("enableGridSuppression") var enableGridSuppression: Bool = true
    @AppStorage("thresholdMethod") var thresholdMethodRaw: String = ThresholdMethod.adaptive.rawValue
    @AppStorage("blockSize") var blockSize: Int = 51 {
        didSet { normalize(\.blockSize) { max(31, min(101, $0 | 1)) } }
    }
    @AppStorage("thresholdC") var thresholdC: Int = 0 {
        didSet { normalize(\.thresholdC) { max(-10, min(10, $0)) } }
    }

    private init() {
        normalizeAll()
    }

    var thresholdMethod: ThresholdMethod {
        get { ThresholdMethod(rawValue: thresholdMethodRaw) ?? .adaptive }
        set { thresholdMethodRaw = newValue.rawValue }
    }

    private func normalizeAll() {
        normalize(\.dilutionFactor) { max(0.1, $0) }
        normalize(\.areaMinUm2) { min(max($0, 1), min(1_000_000, areaMaxUm2)) }
        normalize(\.areaMaxUm2) { min(1_000_000, max($0, areaMinUm2)) }
        normalize(\.minCellDiameterUm) { min(max($0, 1), maxCellDiameterUm) }
        normalize(\.maxCellDiameterUm) { max(minCellDiameterUm, min($0, 200)) }
        normalize(\.blueHueMin) { min(max($0, 0), min(360, blueHueMax)) }
        normalize(\.blueHueMax) { max(blueHueMin, min($0, 360)) }
        normalize(\.minBlueSaturation) { min(max($0, 0), 1) }
        normalize(\.blobScoreThreshold) { min(max($0, 0), 1) }
        normalize(\.nmsIoU) { min(max($0, 0), 1) }
        normalize(\.focusMinLaplacian) { max($0, 0) }
        normalize(\.blockSize) { max(31, min(101, $0 | 1)) }
        normalize(\.thresholdC) { max(-10, min(10, $0)) }
    }

    private func normalize<T: Equatable>(_ keyPath: ReferenceWritableKeyPath<SettingsStore, T>, transform: (T) -> T) {
        let current = self[keyPath: keyPath]
        let normalized = transform(current)
        if normalized != current {
            self[keyPath: keyPath] = normalized
        }
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
        normalizeAll()
    }
}
