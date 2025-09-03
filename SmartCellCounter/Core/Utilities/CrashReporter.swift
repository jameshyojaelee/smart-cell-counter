import Foundation
import MetricKit

final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    static let shared = CrashReporter()
    private override init() { super.init() }

    func start() {
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        for p in payloads {
            Logger.log("Received diagnostics: \(p)" )
        }
    }
}

