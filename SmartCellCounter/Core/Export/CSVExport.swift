import Foundation

public enum CSVExport {
    public struct SummaryRow: Codable {
        public let id: String
        public let createdAt: String
        public let operatorName: String
        public let project: String
        public let concentrationPerMl: Double
        public let viabilityPercent: Double
        public let liveTotal: Int
        public let deadTotal: Int
    }

    public static func summaryCSV(_ rows: [SummaryRow]) -> Data {
        var out = "id,createdAt,operator,project,concentrationPerMl,viabilityPercent,liveTotal,deadTotal\n"
        for r in rows {
            out += "\(r.id),\(r.createdAt),\(r.operatorName),\(r.project),\(r.concentrationPerMl),\(r.viabilityPercent),\(r.liveTotal),\(r.deadTotal)\n"
        }
        return out.data(using: .utf8) ?? Data()
    }

    public static func detectionsCSV(sampleId: String, detections: [(objectId: String, x: Double, y: Double, areaPx: Int, circularity: Double, solidity: Double, isLive: Bool)]) -> Data {
        var out = "sampleId,objectId,x,y,areaPx,circularity,solidity,isLive\n"
        for d in detections {
            out += "\(sampleId),\(d.objectId),\(d.x),\(d.y),\(d.areaPx),\(d.circularity),\(d.solidity),\(d.isLive)\n"
        }
        return out.data(using: .utf8) ?? Data()
    }
}
