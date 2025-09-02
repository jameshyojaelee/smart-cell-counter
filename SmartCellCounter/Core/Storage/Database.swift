import Foundation
import GRDB

public final class DatabaseManager {
    public static let shared = DatabaseManager()
    public let dbQueue: DatabaseQueue

    private init() {
        let fileManager = FileManager.default
        let urls = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let baseURL = urls.first!.appendingPathComponent("SmartCellCounter", isDirectory: true)
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
        let dbURL = baseURL.appendingPathComponent("smartcellcounter.sqlite")
        dbQueue = try! DatabaseQueue(path: dbURL.path)
        migrate()
    }

    private func migrate() {
        var migrator = DatabaseMigrator()
        migrator.registerMigration("v1_create_tables") { db in
            try db.create(table: "sample") { t in
                t.column("id", .text).primaryKey() // UUID string
                t.column("createdAt", .datetime).notNull()
                t.column("operator", .text).indexed()
                t.column("project", .text).indexed()
                t.column("chamberType", .text).notNull()
                t.column("dilutionFactor", .double).notNull().defaults(to: 1.0)
                t.column("stainType", .text)
                t.column("liveTotal", .integer).notNull().defaults(to: 0)
                t.column("deadTotal", .integer).notNull().defaults(to: 0)
                t.column("concentrationPerMl", .double).notNull().defaults(to: 0)
                t.column("viabilityPercent", .double).notNull().defaults(to: 0)
                t.column("squaresUsed", .integer).notNull().defaults(to: 0)
                t.column("rejectedSquares", .integer).notNull().defaults(to: 0)
                t.column("focusScore", .double)
                t.column("glareRatio", .double)
                t.column("pxPerMicron", .double)
                t.column("imagePath", .text)
                t.column("maskPath", .text)
                t.column("pdfPath", .text)
                t.column("notes", .text)
            }
            try db.create(table: "detection") { t in
                t.column("sampleId", .text).notNull().indexed().references("sample", onDelete: .cascade)
                t.column("objectId", .text).notNull() // UUID string
                t.column("x", .double).notNull()
                t.column("y", .double).notNull()
                t.column("areaPx", .integer).notNull()
                t.column("circularity", .double).notNull()
                t.column("solidity", .double).notNull()
                t.column("isLive", .boolean).notNull().defaults(to: true)
                t.primaryKey(["sampleId", "objectId"], onConflict: .replace)
            }
        }
        try! migrator.migrate(dbQueue)
    }
}
