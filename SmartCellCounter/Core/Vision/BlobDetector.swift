import Foundation
import CoreImage

enum BlobDetector {
    static func detect(on luma: CIImage,
                       textureMask: CIImage,
                       gridMask: CIImage,
                       context: CIContext,
                       settings: SettingsStore,
                       pxPerMicron: Double?) -> [Candidate] {
        let sigmas: [CGFloat] = [1.5, 2.5, 3.5, 4.5]
        var responses: [CIImage] = []
        for s in sigmas {
            let g1 = luma.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: s]).cropped(to: luma.extent)
            let g2 = luma.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: s*1.6]).cropped(to: luma.extent)
            let dog = g2.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: g1.applyingFilter("CIColorInvert")])
            responses.append(dog)
        }

        var candidates: [Candidate] = []
        for (i, resp) in responses.enumerated() {
            let scale = sigmas[i]
            guard let cg = context.createCGImage(resp, from: resp.extent) else { continue }
            let w = cg.width, h = cg.height
            guard let data = cg.dataProvider?.data as Data? else { continue }
            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                let p = ptr.bindMemory(to: UInt8.self).baseAddress!
                let stride = cg.bytesPerRow
                let step = max(1, Int(min(w, h)/512))
                for y in stride(from: 2, to: h-2, by: step) {
                    let line = p + y*stride
                    for x in stride(from: 2, to: w-2, by: step) {
                        let idx = x*4
                        let v = Double(line[idx])
                        var isMax = true
                        for dy in -2...2 {
                            for dx in -2...2 {
                                if dx == 0 && dy == 0 { continue }
                                let nline = p + (y+dy)*stride
                                let nv = Double(nline[(x+dx)*4])
                                if nv > v { isMax = false; break }
                            }
                            if !isMax { break }
                        }
                        if !isMax { continue }
                        let score = v / 255.0
                        if score < settings.blobScoreThreshold { continue }
                        let radius = CGFloat(1.6 * scale)
                        let pt = CGPoint(x: CGFloat(x), y: CGFloat(y))
                        if MaskUtils.isMasked(gridMask, at: pt, context: context) { continue }
                        if !MaskUtils.isMasked(textureMask, at: pt, context: context) { continue }
                        candidates.append(Candidate(center: pt, radius: radius, score: score))
                    }
                }
            }
        }

        if let ppm = pxPerMicron {
            let minR = CGFloat((settings.minCellDiameterUm / 2.0) * ppm)
            let maxR = CGFloat((settings.maxCellDiameterUm / 2.0) * ppm)
            candidates = candidates.filter { $0.radius >= minR && $0.radius <= maxR }
        } else {
            candidates = candidates.filter { $0.radius >= 3 && $0.radius <= 50 }
        }

        return candidates
    }
}

enum MaskUtils {
    static func isMasked(_ mask: CIImage, at p: CGPoint, context: CIContext) -> Bool {
        if mask.extent.isEmpty { return false }
        let r = CGRect(x: p.x, y: p.y, width: 1, height: 1)
        guard let cg = context.createCGImage(mask, from: r) else { return false }
        guard let data = cg.dataProvider?.data as Data? else { return false }
        let v = data.first ?? 0
        return v > 127
    }
}


