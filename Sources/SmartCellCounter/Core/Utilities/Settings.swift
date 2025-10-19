import Foundation

final class AnalyticsLogger {
    static let shared = AnalyticsLogger()
    var isEnabled: Bool = false

    private init() {}

    func log(event: String, metadata: [String: String] = [:]) {
        guard isEnabled else { return }
        let payload = metadata.map { "\($0.key)=\($0.value)" }.joined(separator: ",")
        Logger.log("Analytics event: \(event) \(payload)")
    }
}

public final class Settings: ObservableObject {
    public static let shared = Settings()

    private let defaults: UserDefaults

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
    @Published public var personalizedAds: Bool {
        didSet { defaults.set(personalizedAds, forKey: Keys.personalizedAds) }
    }
    @Published public var crashReportingEnabled: Bool {
        didSet {
            defaults.set(crashReportingEnabled, forKey: Keys.crashReporting)
            crashReportingEnabled ? CrashReporter.shared.start() : CrashReporter.shared.stop()
        }
    }
    @Published public var analyticsEnabled: Bool {
        didSet {
            defaults.set(analyticsEnabled, forKey: Keys.analytics)
            AnalyticsLogger.shared.isEnabled = analyticsEnabled
        }
    }

    private enum Keys {
        static let personalizedAds = "settings.personalizedAds"
        static let crashReporting = "settings.crashReporting"
        static let analytics = "settings.analytics"
    }

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.personalizedAds = defaults.bool(forKey: Keys.personalizedAds)
        self.crashReportingEnabled = defaults.bool(forKey: Keys.crashReporting)
        self.analyticsEnabled = defaults.bool(forKey: Keys.analytics)
        AnalyticsLogger.shared.isEnabled = analyticsEnabled
        if crashReportingEnabled {
            CrashReporter.shared.start()
        }
    }
}
