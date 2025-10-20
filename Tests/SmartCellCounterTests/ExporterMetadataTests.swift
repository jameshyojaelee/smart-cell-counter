import XCTest
import PDFKit
import CoreGraphics
@testable import SmartCellCounter

final class ExporterMetadataTests: XCTestCase {
    func testCSVSummaryIncludesMetadata() throws {
        let exporter = CSVExporter()
        let metadata = ExportMetadata(labName: "BioLab A", stain: "Trypan Blue", dilution: 2.5)
        let url = try exporter.exportSummary(sampleId: "sample-001",
                                             timestamp: Date(timeIntervalSince1970: 1_700_000_000),
                                             operatorName: "Operator",
                                             project: "Project X",
                                             metadata: metadata,
                                             concentrationPerML: 1.23e5,
                                             viabilityPercent: 96.4,
                                             live: 123,
                                             dead: 5,
                                             filename: "test-summary.csv")
        let contents = try String(contentsOf: url)
        XCTAssertTrue(contents.contains(metadata.labName))
        XCTAssertTrue(contents.contains(metadata.stain))
        XCTAssertTrue(contents.contains(metadata.formattedDilution))
    }

    func testDetectionsCSVIncludesMetadataRows() throws {
        let exporter = CSVExporter()
        let metadata = ExportMetadata(labName: "Lab B", stain: "Crystal Violet", dilution: 1.5)
        let sample = CellObject(id: 0,
                                pixelCount: 10,
                                areaPx: 100,
                                perimeterPx: 40,
                                circularity: 0.8,
                                solidity: 1,
                                centroid: CGPoint(x: 10, y: 12),
                                bbox: CGRect(x: 0, y: 0, width: 4, height: 4))
        let labeled = [CellObjectLabeled(id: 0,
                                         base: sample,
                                         color: ColorSampleStats(hue: 0, saturation: 0, value: 0, L: 0, a: 0, b: 0),
                                         label: "live",
                                         confidence: 0.9)]
        let url = try exporter.exportDetections(sampleId: "sample-002", labeled: labeled, metadata: metadata, filename: "test-detections.csv")
        let contents = try String(contentsOf: url)
        XCTAssertTrue(contents.contains(metadata.labName))
        XCTAssertTrue(contents.contains(metadata.stain))
        XCTAssertTrue(contents.contains(metadata.formattedDilution))
        XCTAssertTrue(contents.contains("sample-002"))
    }

    func testPDFReportIncludesMetadata() throws {
        let exporter = PDFExporter()
        let metadata = ExportMetadata(labName: "Central Lab", stain: "Live/Dead Green", dilution: 3.0)
        let header = ReportHeader(project: "Project Zebra", operatorName: "Dr. Lee", timestamp: Date(timeIntervalSince1970: 1_700_000_000))
        let url = try exporter.exportReport(header: header,
                                            metadata: metadata,
                                            images: ReportImages(original: nil, corrected: nil, overlay: nil),
                                            tally: [:],
                                            params: ImagingParams(),
                                            watermark: false,
                                            filename: "test-report.pdf")
        guard let document = PDFDocument(url: url),
              let pageText = document.page(at: 0)?.string else {
            XCTFail("Unable to read generated PDF.")
            return
        }
        XCTAssertTrue(pageText.contains(metadata.labName))
        XCTAssertTrue(pageText.contains(metadata.stain))
        XCTAssertTrue(pageText.contains(metadata.formattedDilution))
    }
}
