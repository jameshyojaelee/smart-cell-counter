import Foundation
import PDFKit
import UIKit

public protocol PDFExporting {
    func export(text: String, filename: String) throws -> URL
    func exportReport(header: ReportHeader,
                      metadata: ExportMetadata,
                      images: ReportImages,
                      tally: [Int: Int],
                      params: ImagingParams,
                      watermark: Bool,
                      filename: String) throws -> URL
}

public struct ReportHeader {
    public let project: String
    public let operatorName: String
    public let timestamp: Date
}

public struct ReportImages {
    public let original: UIImage?
    public let corrected: UIImage?
    public let overlay: UIImage?
}

public final class PDFExporter: PDFExporting {
    public init() {}

    public func export(text: String, filename: String) throws -> URL {
        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: 612, height: 792))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
            text.draw(in: CGRect(x: 36, y: 36, width: 540, height: 720), withAttributes: attrs)
        }
        return url
    }

    public func exportReport(header: ReportHeader,
                             metadata: ExportMetadata,
                             images: ReportImages,
                             tally: [Int: Int],
                             params: ImagingParams,
                             watermark: Bool,
                             filename: String = "report.pdf") throws -> URL
    {
        let pageRect = CGRect(x: 0, y: 0, width: 612, height: 792)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        let renderer = UIGraphicsPDFRenderer(bounds: pageRect)
        try renderer.writePDF(to: url) { ctx in
            ctx.beginPage()
            drawHeader(header, metadata: metadata)
            var y: CGFloat = 90
            y = drawImages(images, atY: y)
            y = drawTallyTable(tally, startY: y + 12)
            y = drawFormulas(params: params, startY: y + 12)
            if watermark { drawWatermark("WATERMARK", in: pageRect) }
        }
        return url
    }

    private func drawHeader(_ header: ReportHeader, metadata: ExportMetadata) {
        let titleAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 18)]
        let bodyAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
        "Smart Cell Counter Report".draw(at: CGPoint(x: 36, y: 24), withAttributes: titleAttrs)
        "Project: \(header.project)".draw(at: CGPoint(x: 36, y: 48), withAttributes: bodyAttrs)
        "Operator: \(header.operatorName)".draw(at: CGPoint(x: 246, y: 48), withAttributes: bodyAttrs)
        if !metadata.labName.isEmpty {
            "Lab: \(metadata.labName)".draw(at: CGPoint(x: 36, y: 66), withAttributes: bodyAttrs)
        }
        if !metadata.stain.isEmpty {
            "Stain: \(metadata.stain)".draw(at: CGPoint(x: 246, y: 66), withAttributes: bodyAttrs)
        }
        "Timestamp: \(ISO8601DateFormatter().string(from: header.timestamp))".draw(at: CGPoint(x: 36, y: metadata.stain.isEmpty && metadata.labName.isEmpty ? 66 : 84), withAttributes: bodyAttrs)
        "Dilution: \(metadata.formattedDilution)".draw(at: CGPoint(x: 246, y: metadata.stain.isEmpty && metadata.labName.isEmpty ? 66 : 84), withAttributes: bodyAttrs)
    }

    private func drawImages(_ images: ReportImages, atY y: CGFloat) -> CGFloat {
        var curY = y
        let labelAttrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12)]
        let imgRect = CGRect(x: 36, y: curY, width: 160, height: 120)
        if let orig = images.original { orig.draw(in: imgRect) }
        "Original".draw(at: CGPoint(x: 36, y: curY + 124), withAttributes: labelAttrs)
        let rect2 = imgRect.offsetBy(dx: 180, dy: 0)
        if let corr = images.corrected { corr.draw(in: rect2) }
        "Corrected".draw(at: CGPoint(x: 216, y: curY + 124), withAttributes: labelAttrs)
        let rect3 = imgRect.offsetBy(dx: 360, dy: 0)
        if let ov = images.overlay { ov.draw(in: rect3) }
        "Overlay".draw(at: CGPoint(x: 396, y: curY + 124), withAttributes: labelAttrs)
        curY += 150
        return curY
    }

    private func drawTallyTable(_ tally: [Int: Int], startY: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.boldSystemFont(ofSize: 12)]
        "Per-Square Counts".draw(at: CGPoint(x: 36, y: startY), withAttributes: attrs)
        let y0 = startY + 18
        let cellSize = CGSize(width: 48, height: 18)
        for r in 0 ..< 3 {
            for c in 0 ..< 3 {
                let idx = r * 3 + c
                let count = tally[idx] ?? 0
                let rect = CGRect(x: 36 + CGFloat(c) * cellSize.width, y: y0 + CGFloat(r) * cellSize.height, width: cellSize.width - 2, height: cellSize.height - 2)
                UIColor(white: 0.95, alpha: 1).setFill(); UIRectFill(rect)
                "\(count)".draw(in: rect.insetBy(dx: 4, dy: 2), withAttributes: [.font: UIFont.systemFont(ofSize: 11)])
            }
        }
        return y0 + cellSize.height * 3
    }

    private func drawFormulas(params: ImagingParams, startY: CGFloat) -> CGFloat {
        let attrs: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 11)]
        let text = "Concentration (cells/mL) = mean per large square × 1e4 × dilution\nViability (%) = (Live / (Live + Dead)) × 100\nParameters: threshold=\(params.thresholdMethod.rawValue), blockSize=\(params.blockSize), C=\(params.C), useWatershed=\(params.useWatershed)"
        text.draw(in: CGRect(x: 36, y: startY, width: 540, height: 200), withAttributes: attrs)
        return startY + 60
    }

    private func drawWatermark(_ text: String, in rect: CGRect) {
        let attrs: [NSAttributedString.Key: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 64),
            .foregroundColor: UIColor(white: 0.9, alpha: 0.6),
        ]
        let size = text.size(withAttributes: attrs)
        let context = UIGraphicsGetCurrentContext()
        context?.saveGState()
        context?.translateBy(x: rect.midX, y: rect.midY)
        context?.rotate(by: -.pi / 6)
        text.draw(at: CGPoint(x: -size.width / 2, y: -size.height / 2), withAttributes: attrs)
        context?.restoreGState()
    }
}

public extension PDFExporter {
    static func makeOverlayImage(base: UIImage, labeled: [CellObjectLabeled]) -> UIImage {
        let r = UIGraphicsImageRenderer(size: base.size)
        let start = Date()
        let img = r.image { ctx in
            base.draw(at: .zero)
            for item in labeled {
                let c = item.base.centroid
                let color: UIColor = item.label == "dead" ? .red : .green
                color.setStroke()
                ctx.cgContext.setLineWidth(2)
                ctx.cgContext.strokeEllipse(in: CGRect(x: c.x - 6, y: c.y - 6, width: 12, height: 12))
            }
        }
        PerformanceLogger.shared.record("renderOverlay", Date().timeIntervalSince(start) * 1000)
        return img
    }
}
