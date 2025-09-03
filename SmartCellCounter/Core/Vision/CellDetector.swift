import Foundation
import UIKit
import CoreImage

public struct DetectionResult {
    public let objects: [CellObject]
    public let labeled: [CellObjectLabeled]
    public let pxPerMicron: Double?
    public let debugImages: [String: UIImage]
}

public enum CellDetector {
    public static func detect(on uiImage: UIImage,
                              roi: CGRect?,
                              pxPerMicron: Double?,
                              settings: SettingsStore) -> DetectionResult {
        let context = ImageContext.ciContext
        let baseCI = CIImage(image: uiImage) ?? CIImage(color: .black).cropped(to: CGRect(origin: .zero, size: uiImage.size))
        let roiRect = roi ?? CGRect(origin: .zero, size: uiImage.size)
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
        let gridMask: CIImage = settings.enableGridSuppression ? GridSuppressor.estimateGridMask(from: eq, context: context) : CIImage(color: .black).cropped(to: eq.extent)
        let textureMask = TextureFilter.textureMask(from: eq, context: context)
        dbg["05_grid_mask"] = Debug.makeMaskPreview(ci: gridMask, context: context)
        dbg["06_texture_mask"] = Debug.makeMaskPreview(ci: textureMask, context: context)

        // 4) Candidates via multi-scale DoG
        let candidates = BlobDetector.detect(on: eq, textureMask: textureMask, gridMask: gridMask, context: context, settings: settings, pxPerMicron: pxPerMicron)
        dbg["07_candidates"] = Debug.drawCandidates(on: cropped, candidates: candidates, context: context)

        // Blue mask for dead classification
        let blueMask = BlueMask.mask(fromHSV: hsv, hueRange: settings.blueHueMin...settings.blueHueMax, minS: settings.minBlueSaturation, maxV: 0.9, context: context)
        dbg["08_blue_mask"] = Debug.makeMaskPreview(ci: blueMask, context: context)

        // 5) Rule-based classification (+ optional ML stub)
        let labeledCandidates = Classifier.classify(candidates: candidates,
                                                    hsv: hsv,
                                                    blueMask: blueMask,
                                                    gridMask: gridMask,
                                                    eqLuma: eq,
                                                    context: context,
                                                    settings: settings)

        // 6) NMS
        let kept = NMS.suppress(labeledCandidates, iou: settings.nmsIoU)

        // 7) ROI -> image coordinates
        let offset = CGPoint(x: roiRect.minX, y: roiRect.minY)
        let objects: [CellObject] = kept.enumerated().map { (idx, k) in
            let c = CGPoint(x: k.center.x + offset.x, y: k.center.y + offset.y)
            let areaPx = Double.pi * Double(k.radius * k.radius)
            let bbox = CGRect(x: c.x - k.radius, y: c.y - k.radius, width: k.radius*2, height: k.radius*2)
            return CellObject(id: idx, pixelCount: Int(areaPx), areaPx: areaPx, perimeterPx: Double(2 * .pi * k.radius), circularity: 1.0, solidity: 1.0, centroid: c, bbox: bbox)
        }
        let labels: [CellObjectLabeled] = objects.enumerated().map { (idx, obj) in
            let lc = kept[idx]
            let color = ColorSpaces.sampleHSVLab(ci: cropped, at: CGPoint(x: obj.centroid.x - offset.x, y: obj.centroid.y - offset.y), context: context)
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


