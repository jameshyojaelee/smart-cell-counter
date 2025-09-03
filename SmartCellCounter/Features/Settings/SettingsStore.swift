import SwiftUI

@MainActor
final class SettingsStore: ObservableObject {
    static let shared = SettingsStore()

    @AppStorage("dilutionFactor") var dilutionFactor: Double = 1.0 { didSet { clamp() } }
    @AppStorage("areaMinUm2") var areaMinUm2: Double = 50 { didSet { clamp() } }
    @AppStorage("areaMaxUm2") var areaMaxUm2: Double = 50000 { didSet { clamp() } }
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
    }

    func reset() {
        dilutionFactor = 1.0
        areaMinUm2 = 50
        areaMaxUm2 = 50000
        thresholdMethod = .adaptive
        blockSize = 51
        thresholdC = 0
    }
}

