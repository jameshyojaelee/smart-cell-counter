import CryptoKit
import Foundation
import MetricKit

final class CrashReporter: NSObject, MXMetricManagerSubscriber {
    struct CrashDiagnosticSummary: Codable, Identifiable {
        let id: UUID
        let receivedAt: Date
        let payloadStart: Date
        let payloadEnd: Date
        let applicationVersion: String
        let buildVersion: String
        let osVersion: String
        let deviceType: String
        let regionFormat: String
        let architecture: String?
        let terminationReason: String?
        let exceptionType: Int?
        let exceptionCode: Int?
        let signal: Int?
        let callStackHash: String?
        let deviceInfo: PerformanceLogger.DeviceInfo
    }

    private struct CrashUploadEnvelope: Codable {
        let generatedAt: Date
        let diagnosticsCount: Int
        let device: PerformanceLogger.DeviceInfo
        let diagnostics: [CrashDiagnosticSummary]
    }

    static let shared = CrashReporter()

    private let fileManager = FileManager.default
    private let workQueue = DispatchQueue(label: "com.smartcellcounter.crashReporter.queue", qos: .utility)
    private let uploadQueue = DispatchQueue(label: "com.smartcellcounter.crashReporter.upload", qos: .utility)
    private var uploadWorkItem: DispatchWorkItem?
    private var cachedStorageDirectory: URL?
    private var uploadsEnabled = false

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    override private init() {
        super.init()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .withoutEscapingSlashes]
        decoder.dateDecodingStrategy = .iso8601
    }

    func start() {
        _ = ensureStorageDirectory()
        MXMetricManager.shared.add(self)
    }

    func stop() {
        MXMetricManager.shared.remove(self)
        uploadWorkItem?.cancel()
        uploadWorkItem = nil
    }

    func setUploadsEnabled(_ enabled: Bool) {
        uploadsEnabled = enabled
        if enabled {
            scheduleUpload(after: 2)
        } else {
            uploadWorkItem?.cancel()
            uploadWorkItem = nil
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        workQueue.async { [weak self] in
            guard let self else { return }
            let summaries = payloads.flatMap(self.extractSummaries)
            guard !summaries.isEmpty else { return }
            self.persist(summaries)
            Logger.log("CrashReporter stored \(summaries.count) crash diagnostic(s).")
            if self.uploadsEnabled {
                self.scheduleUpload(after: 5)
            }
        }
    }

    func pendingSummaries(limit: Int? = nil) -> [CrashDiagnosticSummary] {
        workQueue.sync {
            guard let directory = ensureStorageDirectory(),
                  let files = try? fileManager.contentsOfDirectory(at: directory,
                                                                   includingPropertiesForKeys: [.creationDateKey],
                                                                   options: [.skipsHiddenFiles])
            else {
                return []
            }
            let sorted = files.sorted { $0.lastPathComponent < $1.lastPathComponent }
            let selected = limit.map { Array(sorted.prefix($0)) } ?? sorted
            return selected.compactMap { url in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(CrashDiagnosticSummary.self, from: data)
            }
        }
    }

    func purge(summaryWithID id: UUID) {
        workQueue.async { [weak self] in
            guard let self, let url = self.fileURL(for: id), self.fileManager.fileExists(atPath: url.path) else { return }
            do {
                try self.fileManager.removeItem(at: url)
            } catch {
                Logger.log("CrashReporter purge error: \(error)")
            }
        }
    }

    // MARK: - Private helpers

    private func extractSummaries(from payload: MXDiagnosticPayload) -> [CrashDiagnosticSummary] {
        guard let diagnostics = payload.crashDiagnostics, !diagnostics.isEmpty else { return [] }
        let deviceInfo = PerformanceLogger.shared.deviceInfo
        return diagnostics.map { diagnostic in
            let meta = diagnostic.metaData
            let architecture: String?
            if #available(iOS 14.0, *) {
                architecture = meta.platformArchitecture
            } else {
                architecture = nil
            }
            return CrashDiagnosticSummary(
                id: UUID(),
                receivedAt: Date(),
                payloadStart: payload.timeStampBegin,
                payloadEnd: payload.timeStampEnd,
                applicationVersion: diagnostic.applicationVersion,
                buildVersion: meta.applicationBuildVersion,
                osVersion: meta.osVersion,
                deviceType: meta.deviceType,
                regionFormat: meta.regionFormat,
                architecture: architecture,
                terminationReason: diagnostic.terminationReason,
                exceptionType: diagnostic.exceptionType?.intValue,
                exceptionCode: diagnostic.exceptionCode?.intValue,
                signal: diagnostic.signal?.intValue,
                callStackHash: hashCallStackTree(diagnostic.callStackTree),
                deviceInfo: deviceInfo
            )
        }
    }

    private func persist(_ summaries: [CrashDiagnosticSummary]) {
        guard let directory = ensureStorageDirectory() else { return }
        for summary in summaries {
            do {
                let data = try encoder.encode(summary)
                let url = directory.appendingPathComponent("\(summary.id.uuidString).json")
                try data.write(to: url, options: .atomic)
            } catch {
                Logger.log("CrashReporter persist error: \(error)")
            }
        }
    }

    private func ensureStorageDirectory() -> URL? {
        if let cachedStorageDirectory { return cachedStorageDirectory }
        guard let base = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            Logger.log("CrashReporter unable to locate application support directory.")
            return nil
        }
        let directory = base.appendingPathComponent("CrashDiagnostics", isDirectory: true)
        do {
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            cachedStorageDirectory = directory
            return directory
        } catch {
            Logger.log("CrashReporter directory error: \(error)")
            return nil
        }
    }

    private func fileURL(for id: UUID) -> URL? {
        ensureStorageDirectory()?.appendingPathComponent("\(id.uuidString).json")
    }

    private func scheduleUpload(after delay: TimeInterval) {
        guard uploadsEnabled else { return }
        uploadWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.performStubUpload()
        }
        uploadWorkItem = work
        uploadQueue.asyncAfter(deadline: .now() + delay, execute: work)
    }

    private func performStubUpload() {
        let summaries = pendingSummaries()
        guard !summaries.isEmpty else { return }
        let envelope = CrashUploadEnvelope(
            generatedAt: Date(),
            diagnosticsCount: summaries.count,
            device: PerformanceLogger.shared.deviceInfo,
            diagnostics: summaries
        )
        guard let data = try? encoder.encode(envelope),
              let json = String(data: data, encoding: .utf8)
        else {
            return
        }
        Logger.log("CrashReporter upload stub (disabled): \(json)")
    }

    private func hashCallStackTree(_ tree: MXCallStackTree) -> String? {
        let digest = SHA256.hash(data: tree.jsonRepresentation())
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}
