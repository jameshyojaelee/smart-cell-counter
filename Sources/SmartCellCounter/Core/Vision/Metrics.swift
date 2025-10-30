import CoreGraphics
import Foundation
import UIKit

public struct LabeledPoint: Codable {
    public let x: CGFloat
    public let y: CGFloat
    public let r: CGFloat
    public let label: String // "live" or "dead"
}

enum Metrics {
    static func varianceOfLaplacian(_ ci: CIImage, context _: CIContext) -> Double {
        let kernel: [CGFloat] = [0, 1, 0, 1, -4, 1, 0, 1, 0]
        let lap = CIFilter(name: "CIConvolution3X3", parameters: [kCIInputImageKey: ci, "inputWeights": CIVector(values: kernel, count: 9), "inputBias": 0])?.outputImage ?? ci
        let mean = lap.applyingFilter("CIAreaAverage", parameters: [kCIInputExtentKey: CIVector(cgRect: ci.extent)])
        var rgba = [UInt8](repeating: 0, count: 4)
        let ctx = ImageContext.ciContext
        ctx.render(mean, toBitmap: &rgba, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: CGColorSpaceCreateDeviceRGB())
        return Double(rgba[0]) / 255.0
    }

    static func precisionRecallF1(pred: [CellObjectLabeled], truth: [LabeledPoint], iou: Double = 0.3) -> (p: Double, r: Double, f1: Double) {
        var tp = 0, fp = 0, fn = 0
        var matched = Set<Int>()
        for (i, pdet) in pred.enumerated() {
            let pr = CGFloat(sqrt(pdet.base.areaPx / .pi))
            var found = -1
            for (j, gt) in truth.enumerated() where !matched.contains(j) {
                if iouCircle(pdet.base.centroid, pr, CGPoint(x: gt.x, y: gt.y), gt.r) > iou, gt.label == pdet.label {
                    found = j; break
                }
            }
            if found >= 0 { tp += 1; matched.insert(found) } else { fp += 1 }
        }
        fn = max(0, truth.count - matched.count)
        let precision = tp == 0 ? 0 : Double(tp) / Double(tp + fp)
        let recall = tp == 0 ? 0 : Double(tp) / Double(tp + fn)
        let f1 = (precision + recall) == 0 ? 0 : 2 * precision * recall / (precision + recall)
        return (precision, recall, f1)
    }

    static func iouCircle(_ c1: CGPoint, _ r1: CGFloat, _ c2: CGPoint, _ r2: CGFloat) -> Double {
        let d = hypot(c1.x - c2.x, c1.y - c2.y)
        if d >= r1 + r2 { return 0 }
        if d <= abs(r1 - r2) { return Double(min(r1, r2) * min(r1, r2)) / Double(max(r1, r2) * max(r1, r2)) }
        let r1_2 = r1 * r1, r2_2 = r2 * r2
        let alpha = acos((r1_2 + d * d - r2_2) / (2 * r1 * d))
        let beta = acos((r2_2 + d * d - r1_2) / (2 * r2 * d))
        let inter = r1_2 * alpha + r2_2 * beta - 0.5 * sqrt(max(0, (-d + r1 + r2) * (d + r1 - r2) * (d - r1 + r2) * (d + r1 + r2)))
        let union = Double.pi * Double(r1_2 + r2_2) - Double(inter)
        return Double(inter) / union
    }
}
