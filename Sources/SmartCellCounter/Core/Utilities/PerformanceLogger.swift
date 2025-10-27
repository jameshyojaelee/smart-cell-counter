import Combine
import Foundation
#if canImport(UIKit)
    import UIKit
#endif

public final class PerformanceLogger: ObservableObject {
    public struct DeviceInfo: Codable, Equatable {
        public let deviceModel: String
        public let systemName: String
        public let systemVersion: String
        public let appVersion: String
        public let localeIdentifier: String
        public let hardwareIdentifier: String

        public static func current() -> DeviceInfo {
            let model: String
            let systemName: String
            let systemVersion: String
            let hardware: String

            #if canImport(UIKit)
                let device = UIDevice.current
                model = device.model
                systemName = device.systemName
                systemVersion = device.systemVersion
                hardware = PerformanceLogger.hardwareIdentifier() ?? device.model
            #else
                let process = ProcessInfo.processInfo
                model = process.hostName
                systemName = process.operatingSystemVersionString
                systemVersion = "\(process.operatingSystemVersion.majorVersion).\(process.operatingSystemVersion.minorVersion).\(process.operatingSystemVersion.patchVersion)"
                hardware = PerformanceLogger.hardwareIdentifier() ?? process.hostName
            #endif

            let bundle = Bundle.main
            let shortVersion = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String
            let buildVersion = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
            let version: String = if let shortVersion, let buildVersion {
                "\(shortVersion) (\(buildVersion))"
            } else if let shortVersion {
                shortVersion
            } else if let buildVersion {
                buildVersion
            } else {
                "unknown"
            }

            return DeviceInfo(
                deviceModel: model,
                systemName: systemName,
                systemVersion: systemVersion,
                appVersion: version,
                localeIdentifier: Locale.current.identifier,
                hardwareIdentifier: hardware
            )
        }
    }

    public enum Stage: String, CaseIterable, Identifiable, Codable {
        case capture = "pipeline.capture"
        case correction = "pipeline.correction"
        case segmentation = "pipeline.segmentation"
        case counting = "pipeline.counting"
        case total = "pipeline.total"

        public var id: String { rawValue }

        public var displayName: String {
            switch self {
            case .capture:
                "Capture"
            case .correction:
                "Correction"
            case .segmentation:
                "Segmentation"
            case .counting:
                "Counting"
            case .total:
                "Pipeline Total"
            }
        }
    }

    public struct PerformanceSample: Identifiable, Codable, Equatable {
        public let id: UUID
        public let timestamp: Date
        public let label: String
        public let durationMs: Double
        public let stage: Stage?
        public let deviceInfo: DeviceInfo
        public let metadata: [String: String]
    }

    public struct PerformanceMetric: Identifiable, Equatable {
        public var id: String { label }
        public let label: String
        public let last: Double
        public let rollingAverage: Double
        public let overallAverage: Double
        public let sampleCount: Int
        public let recentSampleCount: Int
        public let recentMin: Double
        public let recentMax: Double
    }

    public struct PerformanceDashboard: Equatable {
        public let deviceInfo: DeviceInfo
        public let metrics: [PerformanceMetric]
    }

    private struct RollingStats {
        var recentValues: [Double] = []
        var totalSum: Double = 0
        var totalCount: Int = 0

        mutating func add(_ value: Double, windowSize: Int) {
            recentValues.append(value)
            if recentValues.count > windowSize {
                recentValues.removeFirst(recentValues.count - windowSize)
            }
            totalSum += value
            totalCount += 1
        }

        var rollingAverage: Double {
            guard !recentValues.isEmpty else { return 0 }
            return recentValues.reduce(0, +) / Double(recentValues.count)
        }

        var overallAverage: Double {
            guard totalCount > 0 else { return 0 }
            return totalSum / Double(totalCount)
        }

        var recentMin: Double { recentValues.min() ?? 0 }
        var recentMax: Double { recentValues.max() ?? 0 }
    }

    public static let defaultWindowSize = 30
    public static let sampleRetentionLimit = 200
    public static let shared = PerformanceLogger()

    @Published public private(set) var lastDurations: [String: Double] = [:]
    @Published public private(set) var dashboard: PerformanceDashboard

    public let windowSize: Int
    public let deviceInfo: DeviceInfo

    private let deviceInfoProvider: () -> DeviceInfo
    private let queue = DispatchQueue(label: "com.smartcellcounter.performanceLogger", attributes: .concurrent)
    private var stats: [String: RollingStats] = [:]

    private var metricsMap: [String: PerformanceMetric] = [:]
    private var sampleHistory: [PerformanceSample] = []

    public init(windowSize: Int = PerformanceLogger.defaultWindowSize,
                deviceInfoProvider: @escaping () -> DeviceInfo = DeviceInfo.current) {
        self.windowSize = max(1, windowSize)
        self.deviceInfoProvider = deviceInfoProvider
        let info = deviceInfoProvider()
        deviceInfo = info
        dashboard = PerformanceDashboard(deviceInfo: info, metrics: [])
    }

    @discardableResult
    public func time<T>(_ label: String, _ block: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try block()
        let ms = Date().timeIntervalSince(start) * 1000
        record(label, ms)
        return result
    }

    @discardableResult
    public func time<T>(stage: Stage, _ block: () throws -> T) rethrows -> T {
        let start = Date()
        let result = try block()
        let ms = Date().timeIntervalSince(start) * 1000
        record(stage: stage, duration: ms)
        return result
    }

    public func record(_ label: String, _ ms: Double) {
        record(label: label, duration: ms, stage: nil, metadata: [:])
    }

    public func record(stage: Stage, duration ms: Double, metadata: [String: String] = [:]) {
        record(label: stage.rawValue, duration: ms, stage: stage, metadata: metadata)
    }

    private func record(label: String, duration ms: Double, stage: Stage?, metadata: [String: String]) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            var stat = stats[label] ?? RollingStats()
            stat.add(ms, windowSize: windowSize)
            stats[label] = stat

            let metric = PerformanceMetric(
                label: label,
                last: ms,
                rollingAverage: stat.rollingAverage,
                overallAverage: stat.overallAverage,
                sampleCount: stat.totalCount,
                recentSampleCount: stat.recentValues.count,
                recentMin: stat.recentMin,
                recentMax: stat.recentMax
            )
            metricsMap[label] = metric
            if let stage {
                let sample = PerformanceSample(
                    id: UUID(),
                    timestamp: Date(),
                    label: label,
                    durationMs: ms,
                    stage: stage,
                    deviceInfo: deviceInfo,
                    metadata: metadata
                )
                sampleHistory.append(sample)
                if sampleHistory.count > PerformanceLogger.sampleRetentionLimit {
                    sampleHistory.removeFirst(sampleHistory.count - PerformanceLogger.sampleRetentionLimit)
                }
            }
            let metrics = metricsMap.values.sorted { $0.label < $1.label }
            DispatchQueue.main.async {
                self.lastDurations[label] = ms
                self.dashboard = PerformanceDashboard(deviceInfo: self.deviceInfo, metrics: metrics)
            }
        }
    }

    public func average(_ label: String) -> Double {
        queue.sync {
            guard let stat = stats[label], stat.totalCount > 0 else { return 0 }
            return stat.overallAverage
        }
    }

    public func rollingAverage(_ label: String) -> Double {
        queue.sync {
            stats[label]?.rollingAverage ?? 0
        }
    }

    public func metricsSnapshot() -> PerformanceDashboard {
        queue.sync {
            let metrics = metricsMap.values.sorted { $0.label < $1.label }
            return PerformanceDashboard(deviceInfo: deviceInfo, metrics: metrics)
        }
    }

    public func recentSamples(limit: Int? = nil) -> [PerformanceSample] {
        queue.sync {
            guard let limit else { return sampleHistory }
            return Array(sampleHistory.suffix(limit))
        }
    }

    public func reset() {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            stats.removeAll()
            metricsMap.removeAll()
            sampleHistory.removeAll()
            DispatchQueue.main.async {
                self.lastDurations = [:]
                self.dashboard = PerformanceDashboard(deviceInfo: self.deviceInfo, metrics: [])
            }
        }
    }

    private static func hardwareIdentifier() -> String? {
        #if os(iOS) || os(tvOS) || os(watchOS)
            var sysinfo = utsname()
            uname(&sysinfo)
            let mirror = Mirror(reflecting: sysinfo.machine)
            let identifier = mirror.children.reduce(into: "") { identifier, element in
                guard let value = element.value as? Int8, value != 0 else { return }
                identifier.append(String(UnicodeScalar(UInt8(value))))
            }
            return identifier.isEmpty ? nil : identifier
        #else
            return nil
        #endif
    }
}
