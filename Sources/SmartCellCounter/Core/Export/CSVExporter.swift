import Foundation

public protocol CSVExporting {
    func export(rows: [[String]], filename: String) throws -> URL
}

public final class CSVExporter: CSVExporting {
    public init() {}
    public func export(rows: [[String]], filename: String) throws -> URL {
        let csv = rows.map { $0.joined(separator: ",") }.joined(separator: "\n")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try csv.data(using: .utf8)?.write(to: url)
        return url
    }
}

public enum Export {}

public extension CSVExporter {
    func exportSummary(sampleId: String, timestamp: Date, operatorName: String, project: String, concentrationPerML: Double, viabilityPercent: Double, live: Int, dead: Int, dilution: Double, filename: String = "summary.csv") throws -> URL {
        let rows = [["Sample ID","Timestamp","Operator","Project","Concentration (cells/mL)","Viability (%)","Live","Dead","Dilution"],
                    [sampleId, ISO8601DateFormatter().string(from: timestamp), operatorName, project,
                     String(format: "%.3e", concentrationPerML), String(format: "%.1f", viabilityPercent), "\(live)", "\(dead)", String(format: "%.1f", dilution)]]
        return try export(rows: rows, filename: filename)
    }

    func exportDetections(sampleId: String, labeled: [CellObjectLabeled], filename: String = "detections.csv") throws -> URL {
        var rows: [[String]] = [["Sample ID","Object ID","x","y","areaPx","circularity","solidity","label","confidence"]]
        for item in labeled {
            let b = item.base
            rows.append([sampleId, String(item.id), String(format: "%.1f", b.centroid.x), String(format: "%.1f", b.centroid.y), String(format: "%.0f", b.areaPx), String(format: "%.3f", b.circularity), String(format: "%.3f", b.solidity), item.label, String(format: "%.2f", item.confidence)])
        }
        return try export(rows: rows, filename: filename)
    }
}
