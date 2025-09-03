import Foundation
import UIKit
import CoreImage

struct DetectionResult {
    let objects: [CellObject]
    let labeled: [CellObjectLabeled]
    let pxPerMicron: Double?
    let debugImages: [String: UIImage]
}

enum CellDetector {
    static func detect(on uiImage: UIImage,
                       roi: CGRect?,
                       pxPerMicron: Double?,
                       params p: DetectorParams) -> DetectionResult {
        let context = ImageContext.ciContext
        // Downscale for speed (process at ~2MP target), then scale detections back
        let originalCI = CIImage(image: uiImage) ?? CIImage(color: CIColor(color: .black)).cropped(to: CGRect(origin: .zero, size: uiImage.size))
        let maxSide: CGFloat = 1600
        let scaleFactor = min(1.0, maxSide / max(uiImage.size.width, uiImage.size.height))
        let baseCI = originalCI.transformed(by: CGAffineTransform(scaleX: scaleFactor, y: scaleFactor))
        let roiRectOriginal = roi ?? CGRect(origin: .zero, size: uiImage.size)
        let roiRect = CGRect(x: roiRectOriginal.origin.x * scaleFactor,
                             y: roiRectOriginal.origin.y * scaleFactor,
                             width: roiRectOriginal.size.width * scaleFactor,
                             height: roiRectOriginal.size.height * scaleFactor)
        let cropped = baseCI.cropped(to: roiRect.integral)
        var dbg: [String: UIImage] = [:]

        // 1) Normalize + luminance/HSV
        let linLuma = ColorSpaces.linearLuminance(cropped)
        let hsv = ColorSpaces.hsvImage(cropped)
        dbg["01_luminance"] = Debug.makePreview(ci: linLuma, context: context)
        dbg["02_hsv_value"] = Debug.makePreview(ci: hsv.value, context: context)

        // Focus check - logged only, UI decides to gate
        let focus = Metrics.varianceOfLaplacian(linLuma, context: context)
        Logger.log("Focus score (variance of Laplacian): \(focus)")

        // 2) Illumination correction + equalization
        let (illumination, flattened) = IlluminationCorrector.flatten(luminance: linLuma, context: context)
        let eq = IlluminationCorrector.equalize(flattened, context: context)
        dbg["03_illumination"] = Debug.makePreview(ci: illumination, context: context)
        dbg["04_flattened_eq"] = Debug.makePreview(ci: eq, context: context)

        // 3) Grid and texture suppression
        let gridMask: CIImage = p.enableGridSuppression ? GridSuppressor.estimateGridMask(from: eq, context: context) : CIImage(color: CIColor(color: .black)).cropped(to: eq.extent)
        let textureMask = TextureFilter.textureMask(from: eq, context: context)
        dbg["05_grid_mask"] = Debug.makeMaskPreview(ci: gridMask, context: context)
        dbg["06_texture_mask"] = Debug.makeMaskPreview(ci: textureMask, context: context)

        // 4) Candidates via multi-scale DoG
        let candidates = BlobDetector.detect(on: eq, textureMask: textureMask, gridMask: gridMask, context: context, params: p, pxPerMicron: pxPerMicron)
        dbg["07_candidates"] = Debug.drawCandidates(on: cropped, candidates: candidates, context: context)

        // Blue mask for dead classification
        let blueMask = BlueMask.mask(fromHSV: hsv, hueRange: p.blueHueMin...p.blueHueMax, minS: p.minBlueSaturation, maxV: 0.9, context: context)
        dbg["08_blue_mask"] = Debug.makeMaskPreview(ci: blueMask, context: context)

        // 5) Rule-based classification (+ optional ML stub)
        let labeledCandidates = Classifier.classify(candidates: candidates,
                                                    hsv: hsv,
                                                    blueMask: blueMask,
                                                    gridMask: gridMask,
                                                    eqLuma: eq,
                                                    context: context,
                                                    params: p)

        // 6) NMS
        let kept = NMS.suppress(labeledCandidates, iou: p.nmsIoU)

        // 7) ROI -> image coordinates
        // Map back to original image coordinates
        let invScale = 1.0 / scaleFactor
        let offset = CGPoint(x: roiRect.minX * invScale, y: roiRect.minY * invScale)
        let objects: [CellObject] = kept.enumerated().map { (idx, k) in
            let cScaled = CGPoint(x: k.center.x * invScale, y: k.center.y * invScale)
            let rScaled = k.radius * invScale
            let c = CGPoint(x: cScaled.x + offset.x, y: cScaled.y + offset.y)
            let areaPx = Double.pi * Double(rScaled * rScaled)
            let bbox = CGRect(x: c.x - rScaled, y: c.y - rScaled, width: rScaled*2, height: rScaled*2)
            return CellObject(id: idx, pixelCount: Int(areaPx), areaPx: areaPx, perimeterPx: Double(2 * .pi * rScaled), circularity: 1.0, solidity: 1.0, centroid: c, bbox: bbox)
        }
        let labels: [CellObjectLabeled] = objects.enumerated().map { (idx, obj) in
            let lc = kept[idx]
            let color = ColorSpaces.sampleHSVLab(ci: originalCI, at: obj.centroid, context: context)
            return CellObjectLabeled(id: obj.id, base: obj, color: color, label: lc.label, confidence: lc.confidence)
        }

        return DetectionResult(objects: objects, labeled: labels, pxPerMicron: pxPerMicron, debugImages: dbg)
    }
}

struct Debug {
    static func makePreview(ci: CIImage, context: CIContext) -> UIImage {
        let extent = ci.extent
        guard let cg = context.createCGImage(ci, from: extent) else { return UIImage() }
        return UIImage(cgImage: cg)
    }
    static func makeMaskPreview(ci: CIImage, context: CIContext) -> UIImage {
        let mono = ci.applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0, kCIInputContrastKey: 2])
        return makePreview(ci: mono, context: context)
    }
    static func drawCandidates(on base: CIImage, candidates: [Candidate], context: CIContext) -> UIImage {
        let ui = makePreview(ci: base, context: context)
        let r = UIGraphicsImageRenderer(size: ui.size)
        return r.image { ctx in
            ui.draw(in: CGRect(origin: .zero, size: ui.size))
            ctx.cgContext.setStrokeColor(UIColor.yellow.cgColor)
            ctx.cgContext.setLineWidth(2)
            for c in candidates {
                let rect = CGRect(x: CGFloat(c.center.x) - c.radius, y: CGFloat(c.center.y) - c.radius, width: c.radius*2, height: c.radius*2)
                ctx.cgContext.strokeEllipse(in: rect)
            }
        }
    }
}

public struct Candidate {
    public let center: CGPoint
    public let radius: CGFloat
    public let score: Double
}


