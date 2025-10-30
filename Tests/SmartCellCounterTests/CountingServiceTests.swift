import CoreGraphics
@testable import SmartCellCounter
import XCTest

final class CountingServiceTests: XCTestCase {
    private func geom(pxPerMicron: Double = 1.0) -> GridGeometry {
        GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron)
    }

    private func makeObject(id: Int, x: CGFloat, y: CGFloat) -> CellObject {
        CellObject(id: id,
                   pixelCount: 10,
                   areaPx: 10,
                   perimeterPx: 10,
                   circularity: 1,
                   solidity: 1,
                   centroid: CGPoint(x: x, y: y),
                   bbox: CGRect(x: x, y: y, width: 1, height: 1))
    }

    func testGridIndexMappingInclusionRules() throws {
        let g = geom()
        // Top-left corner
        let idx0 = CountingService.mapCentroidToGrid(ptPx: CGPoint(x: 0, y: 0), geometry: g)
        XCTAssertEqual(idx0?.largeX, 0)
        XCTAssertEqual(idx0?.largeY, 0)
        XCTAssertEqual(idx0?.smallX, 0)
        XCTAssertEqual(idx0?.smallY, 0)

        // On vertical small-grid boundary at 50 µm should include left cell (smallX 0), not right
        let idxBoundary = CountingService.mapCentroidToGrid(ptPx: CGPoint(x: 50, y: 10), geometry: g)
        XCTAssertEqual(idxBoundary?.smallX, 0)

        // Rightmost border excluded
        let idxRight = CountingService.mapCentroidToGrid(ptPx: CGPoint(x: 3000, y: 1000), geometry: g)
        XCTAssertNil(idxRight)
        // Bottom border excluded
        let idxBottom = CountingService.mapCentroidToGrid(ptPx: CGPoint(x: 1000, y: 3000), geometry: g)
        XCTAssertNil(idxBottom)
    }

    func testTallyAndMADMean() throws {
        let g = geom()
        var objects: [CellObject] = []
        // Large 0: 100 cells
        for i in 0 ..< 100 {
            objects.append(makeObject(id: i, x: 100, y: 100))
        }
        // Large 2: 110 cells
        for i in 0 ..< 110 {
            objects.append(makeObject(id: 100 + i, x: 2100, y: 100))
        }
        // Large 6: 105 cells
        for i in 0 ..< 105 {
            objects.append(makeObject(id: 210 + i, x: 100, y: 2100))
        }
        // Large 8: outlier 500 cells
        for i in 0 ..< 500 {
            objects.append(makeObject(id: 315 + i, x: 2100, y: 2100))
        }

        let tally = CountingService.tallyByLargeSquare(objects: objects, geometry: g)
        let mean = CountingService.meanCountPerLargeSquare(countsByIndex: tally, selectedLargeIndices: [0, 2, 6, 8], outlierThreshold: 2.5)
        XCTAssertEqual(round(mean), 105, "Robust mean should ignore outlier and be ~105")
    }

    func testConcentrationViabilitySeeding() throws {
        // Mean count 100, dilution 2 -> 2e6 cells/mL
        let conc = CountingService.concentrationPerML(meanCountPerLargeSquare: 100, dilutionFactor: 2)
        XCTAssertEqual(conc, 2_000_000, accuracy: 0.001)

        let v = CountingService.viabilityPercent(live: 170, dead: 30)
        XCTAssertEqual(v, 85.0, accuracy: 0.0001)

        // target 1e6 cells at 2e6 cells/mL -> 0.5 mL
        let (vol, note) = CountingService.seedingVolume(targetCells: 1_000_000, finalVolumeML: 1.0, concentrationPerML: conc, meanCountPerLargeSquare: 100)
        XCTAssertEqual(vol, 0.5, accuracy: 1e-6)
        XCTAssertTrue(note.contains("Proceed"))
    }
}
