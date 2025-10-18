import Foundation
import CoreImage

enum BlobDetector {
    static func detect(on luma: CIImage,
                       textureMask: CIImage,
                       gridMask: CIImage,
                       context: CIContext,
                       params: DetectorParams,
                       pxPerMicron: Double?) -> [Candidate] {
        // Pick DoG scales based on expected radius range if calibration is known
        let sigmas: [CGFloat] = {
            if let ppm = pxPerMicron {
                let minR = CGFloat((params.minCellDiameterUm / 2.0) * ppm)
                let maxR = CGFloat((params.maxCellDiameterUm / 2.0) * ppm)
                var minSigma = max(0.8, minR / 1.6)
                var maxSigma = max(minSigma + 0.6, maxR / 1.6)
                // Clamp to reasonable bounds
                minSigma = min(minSigma, 12)
                maxSigma = min(maxSigma, 16)
                // Generate up to 4 evenly spaced sigma values in [minSigma, maxSigma]
                let count = max(2, min(4, Int(ceil((maxSigma - minSigma) / 1.5))))
                if count <= 2 { return [minSigma, maxSigma] }
                let step = (maxSigma - minSigma) / CGFloat(count - 1)
                return (0..<count).map { minSigma + CGFloat($0) * step }
            } else {
                return [1.5, 2.5, 3.5, 4.5]
            }
        }()
        var responses: [CIImage] = []
        responses.reserveCapacity(sigmas.count)
        for s in sigmas {
            let g1 = luma.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: s]).cropped(to: luma.extent)
            let g2 = luma.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: s*1.6]).cropped(to: luma.extent)
            let dog = g2.applyingFilter("CIAdditionCompositing", parameters: [kCIInputBackgroundImageKey: g1.applyingFilter("CIColorInvert")])
            responses.append(dog)
        }

        // Pre-render masks once for fast sampling
        let gridSampler = PixelSampler.from(ci: gridMask, context: context)
        let textureSampler = PixelSampler.from(ci: textureMask, context: context)

        var threadLocalResults = Array(repeating: [Candidate](), count: sigmas.count)
        DispatchQueue.concurrentPerform(iterations: sigmas.count) { i in
            let resp = responses[i]
            let scale = sigmas[i]
            guard let cg = context.createCGImage(resp, from: resp.extent) else { return }
            let w = cg.width, h = cg.height
            guard let data = cg.dataProvider?.data as Data? else { return }
            var local: [Candidate] = []
            data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
                let p = ptr.bindMemory(to: UInt8.self).baseAddress!
                let stride = cg.bytesPerRow
                // Use finer step for higher quality on smaller images, coarser on large images
                let step = max(1, Int(min(w, h) / 768))
                DispatchQueue.concurrentPerform(iterations: max(1, (h-4)/step)) { rowIndex in
                    let y = 2 + rowIndex * step
                    if y >= h-2 { return }
                    let line = p + y*stride
                    var rowLocal: [Candidate] = []
                    var x = 2
                    while x < (w-2) {
                        let idx = x*4
                        let v = Double(line[idx])
                        var isMax = true
                        var dy = -2
                        while dy <= 2 && isMax {
                            let nline = p + (y+dy)*stride
                            var dx = -2
                            while dx <= 2 {
                                if dx != 0 || dy != 0 {
                                    let nv = Double(nline[(x+dx)*4])
                                    if nv > v { isMax = false; break }
                                }
                                dx += 1
                            }
                            dy += 1
                        }
                        if isMax {
                            let score = v / 255.0
                            if score >= params.blobScoreThreshold {
                                let radius = CGFloat(1.6 * scale)
                                let pt = CGPoint(x: CGFloat(x), y: CGFloat(y))
                                if !(gridSampler?.isOn(Int(x), Int(y)) ?? false) && (textureSampler?.isOn(Int(x), Int(y)) ?? true) {
                                    rowLocal.append(Candidate(center: pt, radius: radius, score: score))
                                }
                            }
                        }
                        x += step
                    }
                    if !rowLocal.isEmpty {
                        // Append row results atomically into local vector
                        objc_sync_enter(self)
                        local.append(contentsOf: rowLocal)
                        objc_sync_exit(self)
                    }
                }
            }
            threadLocalResults[i] = local
        }

        var candidates = threadLocalResults.flatMap { $0 }

        if let ppm = pxPerMicron {
            let minR = CGFloat((params.minCellDiameterUm / 2.0) * ppm)
            let maxR = CGFloat((params.maxCellDiameterUm / 2.0) * ppm)
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

private struct PixelSampler {
    let width: Int
    let height: Int
    let stride: Int
    let data: Data

    func isOn(_ x: Int, _ y: Int) -> Bool {
        if x < 0 || y < 0 || x >= width || y >= height { return false }
        return data[y*stride + x*4] > 127
    }

    static func from(ci: CIImage, context: CIContext) -> PixelSampler? {
        if ci.extent.isEmpty { return nil }
        guard let cg = context.createCGImage(ci, from: ci.extent) else { return nil }
        guard let raw = cg.dataProvider?.data as Data? else { return nil }
        return PixelSampler(width: cg.width, height: cg.height, stride: cg.bytesPerRow, data: raw)
    }
}


