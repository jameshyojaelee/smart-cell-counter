import Foundation
import UIKit
import GRDB

public protocol Storage {
    func setup() async throws
}

// MARK: - Records
public struct SampleRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "sample"
    var id: String
    var createdAt: Date
    var operatorName: String
    var project: String
    var chamberType: String
    var dilutionFactor: Double
    var stainType: String
    var liveTotal: Int
    var deadTotal: Int
    var concentrationPerMl: Double
    var viabilityPercent: Double
    var squaresUsed: Int
    var rejectedSquares: String // comma-separated indices
    var focusScore: Double
    var glareRatio: Double
    var pxPerMicron: Double
    var imagePath: String?
    var maskPath: String?
    var pdfPath: String?
    var thumbnailPath: String?
    var thumbnailWidth: Double = 0
    var thumbnailHeight: Double = 0
    var csvPath: String?
    var notes: String?

    enum CodingKeys: String, CodingKey {
        case id, createdAt
        case operatorName = "operator"
        case project, chamberType, dilutionFactor, stainType, liveTotal, deadTotal, concentrationPerMl, viabilityPercent, squaresUsed, rejectedSquares, focusScore, glareRatio, pxPerMicron, imagePath, maskPath, pdfPath, thumbnailPath, thumbnailWidth, thumbnailHeight, csvPath, notes
    }
}

public struct DetectionRecord: Codable, FetchableRecord, MutablePersistableRecord, TableRecord {
    public static let databaseTableName = "detection"
    var sampleId: String
    var objectId: String
    var x: Double
    var y: Double
    var areaPx: Double
    var circularity: Double
    var solidity: Double
    var isLive: Bool
}

// MARK: - App Database
public actor AppDatabase: Storage {
    public static let shared = AppDatabase()

    private var dbQueue: DatabaseQueue?
    private let databasePath: String?
    private var configuration: Configuration

    public init(databasePath: String? = nil, configuration: Configuration = Configuration()) {
        self.databasePath = databasePath
        self.configuration = configuration
        self.configuration.prepareDatabase { db in
            db.trace(options: .statement) { event in
                Logger.log("SQL: \(event)")
            }
        }
    }

    public func setup() async throws {
        guard dbQueue == nil else { return }
        if let databasePath {
            dbQueue = try DatabaseQueue(path: databasePath, configuration: configuration)
        } else {
            let baseDir = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
            let dbURL = baseDir.appendingPathComponent("smartcellcounter.sqlite")
            dbQueue = try DatabaseQueue(path: dbURL.path, configuration: configuration)
        }
        try migrate()
    }

    private func migrate() throws {
        guard let dbQueue else { return }
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1") { db in
            try db.create(table: "sample") { t in
                t.column("id", .text).primaryKey()
                t.column("createdAt", .datetime).notNull()
                t.column("operator", .text).notNull()
                t.column("project", .text).notNull().defaults(to: "")
                t.column("chamberType", .text).notNull()
                t.column("dilutionFactor", .double).notNull().defaults(to: 1.0)
                t.column("stainType", .text).notNull()
                t.column("liveTotal", .integer).notNull()
                t.column("deadTotal", .integer).notNull()
                t.column("concentrationPerMl", .double).notNull()
                t.column("viabilityPercent", .double).notNull()
                t.column("squaresUsed", .integer).notNull()
                t.column("rejectedSquares", .text).notNull().defaults(to: "")
                t.column("focusScore", .double).notNull().defaults(to: 0)
                t.column("glareRatio", .double).notNull().defaults(to: 0)
                t.column("pxPerMicron", .double).notNull().defaults(to: 0)
                t.column("imagePath", .text)
                t.column("maskPath", .text)
                t.column("pdfPath", .text)
                t.column("notes", .text)
            }
            try db.create(table: "detection") { t in
                t.column("sampleId", .text).notNull().indexed().references("sample", onDelete: .cascade)
                t.column("objectId", .text).notNull()
                t.column("x", .double).notNull()
                t.column("y", .double).notNull()
                t.column("areaPx", .double).notNull()
                t.column("circularity", .double).notNull()
                t.column("solidity", .double).notNull()
                t.column("isLive", .boolean).notNull()
            }
        }
        migrator.registerMigration("v2_add_metadata") { db in
            try db.alter(table: "sample") { t in
                t.add(column: "thumbnailPath", .text)
                t.add(column: "thumbnailWidth", .double).defaults(to: 0)
                t.add(column: "thumbnailHeight", .double).defaults(to: 0)
                t.add(column: "csvPath", .text)
            }
        }
        try migrator.migrate(dbQueue)
    }

    // MARK: - DAO
    public func insertSample(_ record: SampleRecord, detections: [DetectionRecord]) async throws {
        guard let dbQueue else { throw NSError(domain: "DB", code: -1) }
        try await dbQueue.write { db in
            var rec = record
            try rec.insert(db)
            for det in detections {
                var d = det
                try d.insert(db)
            }
        }
    }

    public func fetchSamples(matching query: String? = nil, limit: Int = 100) async throws -> [SampleRecord] {
        guard let dbQueue else { return [] }
        return try await dbQueue.read { db in
            if let q = query, !q.isEmpty {
                return try SampleRecord
                    .filter(sql: "project LIKE ? OR \"operator\" LIKE ?", arguments: ["%\(q)%", "%\(q)%"])
                    .order(sql: "createdAt DESC")
                    .limit(limit)
                    .fetchAll(db)
            } else {
                return try SampleRecord
                    .order(sql: "createdAt DESC")
                    .limit(limit)
                    .fetchAll(db)
            }
        }
    }

    public func fetchDetections(for sampleId: String) async throws -> [DetectionRecord] {
        guard let dbQueue else { return [] }
        return try await dbQueue.read { db in
            try DetectionRecord.filter(Column("sampleId") == sampleId).fetchAll(db)
        }
    }

    public func updateSamplePaths(sampleId: String, csvPath: String?) async throws {
        guard let dbQueue else { return }
        try await dbQueue.write { db in
            try db.execute(sql: "UPDATE sample SET csvPath = ? WHERE id = ?", arguments: [csvPath, sampleId])
        }
    }

    // MARK: - Filesystem helpers
    public func sampleFolder(id: String) throws -> URL {
        let base = try FileManager.default.url(for: .applicationSupportDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        let dir = base.appendingPathComponent("SmartCellCounter/Samples/\(id)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    public func save(image: UIImage, name: String, in folder: URL) throws -> URL {
        let url = folder.appendingPathComponent(name)
        if let data = image.pngData() { try data.write(to: url) }
        return url
    }
}
