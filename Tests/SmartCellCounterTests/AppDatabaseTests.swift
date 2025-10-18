import XCTest
@testable import SmartCellCounter

final class AppDatabaseTests: XCTestCase {
    func testInsertAndFetchSample() async throws {
        let db = AppDatabase(databasePath: ":memory:")
        try await db.setup()

        let sampleId = UUID().uuidString
        let record = SampleRecord(
            id: sampleId,
            createdAt: Date(),
            operatorName: "Tester",
            project: "Unit",
            chamberType: "Neubauer",
            dilutionFactor: 1.0,
            stainType: "None",
            liveTotal: 120,
            deadTotal: 30,
            concentrationPerMl: 1.2e6,
            viabilityPercent: 80,
            squaresUsed: 4,
            rejectedSquares: "",
            focusScore: 0.5,
            glareRatio: 0.1,
            pxPerMicron: 1.0,
            imagePath: nil,
            maskPath: nil,
            pdfPath: nil,
            thumbnailPath: "/tmp/thumb.png",
            thumbnailWidth: 100,
            thumbnailHeight: 80,
            csvPath: "/tmp/summary.csv",
            notes: nil
        )

        let detections: [DetectionRecord] = [
            DetectionRecord(sampleId: sampleId, objectId: UUID().uuidString, x: 0, y: 0, areaPx: 10, circularity: 0.9, solidity: 0.95, isLive: true)
        ]

        try await db.insertSample(record, detections: detections)

        let fetched = try await db.fetchSamples()
        XCTAssertEqual(fetched.count, 1)
        let fetchedRecord = fetched[0]
        XCTAssertEqual(fetchedRecord.thumbnailWidth, 100)
        XCTAssertEqual(fetchedRecord.thumbnailHeight, 80)
        XCTAssertEqual(fetchedRecord.csvPath, "/tmp/summary.csv")

        let storedDetections = try await db.fetchDetections(for: sampleId)
        XCTAssertEqual(storedDetections.count, 1)
        XCTAssertTrue(storedDetections[0].isLive)
    }
}
