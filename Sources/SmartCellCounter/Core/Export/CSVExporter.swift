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
    func exportSummary(sampleId: String,
                       timestamp: Date,
                       operatorName: String,
                       project: String,
                       concentrationPerML: Double,
                       viabilityPercent: Double,
                       live: Int,
                       dead: Int,
                       dilution: Double,
                       filename: String? = nil) throws -> URL {
        let headers = L10n.Results.CSV.detailedHeaders
        let values = [
            sampleId,
            ISO8601DateFormatter().string(from: timestamp),
            operatorName,
            project,
            L10n.Results.concentrationNumeric(concentrationPerML),
            L10n.Results.viabilityNumeric(viabilityPercent),
            L10n.Results.countValue(live),
            L10n.Results.countValue(dead),
            L10n.Results.dilutionValue(dilution)
        ]
        return try export(rows: [headers, values], filename: filename ?? L10n.Results.CSV.summaryFilename)
    }

    func exportDetections(sampleId: String, labeled: [CellObjectLabeled], filename: String? = nil) throws -> URL {
        var rows: [[String]] = [L10n.Results.CSV.detectionsHeaders]
        for item in labeled {
            let b = item.base
            rows.append([
                sampleId,
                String(item.id),
                CSVExporter.coordinateFormatter.string(from: NSNumber(value: b.centroid.x)) ?? String(format: "%.1f", b.centroid.x),
                CSVExporter.coordinateFormatter.string(from: NSNumber(value: b.centroid.y)) ?? String(format: "%.1f", b.centroid.y),
                CSVExporter.integerFormatter.string(from: NSNumber(value: Int(b.areaPx))) ?? String(format: "%.0f", b.areaPx),
                CSVExporter.threeDecimalFormatter.string(from: NSNumber(value: b.circularity)) ?? String(format: "%.3f", b.circularity),
                CSVExporter.threeDecimalFormatter.string(from: NSNumber(value: b.solidity)) ?? String(format: "%.3f", b.solidity),
                item.label,
                CSVExporter.twoDecimalFormatter.string(from: NSNumber(value: item.confidence)) ?? String(format: "%.2f", item.confidence)
            ])
        }
        return try export(rows: rows, filename: filename ?? L10n.Results.CSV.detectionsFilename)
    }
}

private extension CSVExporter {
    static let coordinateFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let integerFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        return formatter
    }()

    static let threeDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 3
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    static let twoDecimalFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter
    }()
}
