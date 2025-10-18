import Foundation

@MainActor
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
