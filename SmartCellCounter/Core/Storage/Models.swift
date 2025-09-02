import Foundation
import GRDB

public struct Sample: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public var id: String
    public var createdAt: Date
    public var `operator`: String?
    public var project: String?
    public var chamberType: String
    public var dilutionFactor: Double
    public var stainType: String?
    public var liveTotal: Int
    public var deadTotal: Int
    public var concentrationPerMl: Double
    public var viabilityPercent: Double
    public var squaresUsed: Int
    public var rejectedSquares: Int
    public var focusScore: Double?
    public var glareRatio: Double?
    public var pxPerMicron: Double?
    public var imagePath: String?
    public var maskPath: String?
    public var pdfPath: String?
    public var notes: String?
}

public struct Detection: Codable, FetchableRecord, PersistableRecord, Identifiable {
    public var id: String { objectId }
    public var sampleId: String
    public var objectId: String
    public var x: Double
    public var y: Double
    public var areaPx: Int
    public var circularity: Double
    public var solidity: Double
    public var isLive: Bool
}

public enum SampleDAO {
    public static func insert(_ sample: Sample, detections: [Detection]) throws {
        try DatabaseManager.shared.dbQueue.write { db in
            try sample.insert(db)
            for d in detections { try d.insert(db) }
        }
    }

    public static func fetchAll(query: String? = nil) throws -> [Sample] {
        try DatabaseManager.shared.dbQueue.read { db in
            if let q = query, !q.isEmpty {
                return try Sample.fetchAll(db, sql: "SELECT * FROM sample WHERE project LIKE ? OR operator LIKE ? ORDER BY createdAt DESC", arguments: ["%\(q)%", "%\(q)%"])
            }
            return try Sample.fetchAll(db, sql: "SELECT * FROM sample ORDER BY createdAt DESC")
        }
    }

    public static func detections(for sampleId: String) throws -> [Detection] {
        try DatabaseManager.shared.dbQueue.read { db in
            try Detection.fetchAll(db, sql: "SELECT * FROM detection WHERE sampleId = ?", arguments: [sampleId])
        }
    }
}
