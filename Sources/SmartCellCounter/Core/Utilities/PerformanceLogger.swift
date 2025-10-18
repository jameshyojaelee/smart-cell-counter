import Foundation

public final class PerformanceLogger: ObservableObject {
    public static let shared = PerformanceLogger()
    @Published public private(set) var lastDurations: [String: Double] = [:]
    private var timings: [String: [Double]] = [:]
    private init() {}

    @discardableResult
    public func time<T>(_ label: String, _ block: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try block()
        let ms = Date().timeIntervalSince(start) * 1000
        record(label, ms)
        return result
    }

    public func record(_ label: String, _ ms: Double) {
        lastDurations[label] = ms
        timings[label, default: []].append(ms)
    }

    public func average(_ label: String) -> Double {
        let arr = timings[label] ?? []
        guard !arr.isEmpty else { return 0 }
        return arr.reduce(0,+) / Double(arr.count)
    }
}

