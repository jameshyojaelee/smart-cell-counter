import Foundation

public final class Settings: ObservableObject {
    public static let shared = Settings()
    private init() {}

    @Published public var useWatershed: Bool = true
    @Published public var chamberType: String = "Neubauer Improved"
    @Published public var stainType: String = "Trypan Blue"
    @Published public var operatorName: String = ""
    @Published public var project: String = ""
    @Published public var defaultDilution: Double = 1.0
    @Published public var thresholdMethod: ThresholdMethod = .adaptive
    @Published public var blockSize: Int = 51
    @Published public var C: Int = 0
    @Published public var minAreaUm2: Double = 50
    @Published public var maxAreaUm2: Double = 5000
    @Published public var enableMLRefine: Bool = false
    @Published public var personalizedAds: Bool = false
}
