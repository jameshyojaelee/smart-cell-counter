import Foundation
import UIKit
import Vision
import CoreImage
import CoreML
import Metal

public enum ImagingPipeline {
    // MARK: - Grid Detection
    public static func detectGrid(in image: UIImage) -> RectangleDetectionResult {
        guard let cg = image.cgImage else {
            return RectangleDetectionResult(found: false, corners: [], confidence: 0)
        }
        let handler = VNImageRequestHandler(cgImage: cg, options: [:])
        let request = VNDetectRectanglesRequest()
        request.minimumConfidence = 0.5
        request.minimumAspectRatio = 0.5
        request.maximumAspectRatio = 2.0
        request.minimumSize = 0.2
        request.quadratureTolerance = 20.0
        do {
            let start = Date()
            try handler.perform([request])
            if let obs = request.results?.first as? VNRectangleObservation {
                let corners = [obs.topLeft, obs.topRight, obs.bottomRight, obs.bottomLeft].map { p in
                    CGPoint(x: CGFloat(p.x) * CGFloat(cg.width), y: CGFloat(1 - p.y) * CGFloat(cg.height))
                }
                PerformanceLogger.shared.record("detectRectangle", Date().timeIntervalSince(start) * 1000)
                return RectangleDetectionResult(found: true, corners: corners, confidence: obs.confidence)
            }
            PerformanceLogger.shared.record("detectRectangle", Date().timeIntervalSince(start) * 1000)
            return RectangleDetectionResult(found: false, corners: [], confidence: 0)
        } catch {
            return RectangleDetectionResult(found: false, corners: [], confidence: 0)
        }
    }

    // MARK: - Perspective Correction
    public static func perspectiveCorrect(_ image: UIImage, corners: [CGPoint]) -> UIImage {
        guard corners.count == 4, let cg = image.cgImage else { return image }
        let ciImage = CIImage(cgImage: cg)
        let start = Date()
        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = ciImage
        filter.topLeft = corners[0]
        filter.topRight = corners[1]
        filter.bottomRight = corners[2]
        filter.bottomLeft = corners[3]
        let context = ImageContext.ciContext
        guard let output = filter.outputImage,
              let outCG = context.createCGImage(output, from: output.extent) else {
            return image
        }
        PerformanceLogger.shared.record("perspective", Date().timeIntervalSince(start) * 1000)
        return UIImage(cgImage: outCG)
    }

    // MARK: - Polarity Check
    public static func shouldInvertPolarity(for image: UIImage) -> Bool {
        // Simple heuristic: if average luminance is bright, invert so cells (dark) become foreground
        guard let cg = image.cgImage else { return false }
        let w = cg.width, h = cg.height
        let scale = max(1, max(w, h) / 64)
        let dw = w / scale, dh = h / scale
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        var data = [UInt8](repeating: 0, count: Int(dw * dh * 4))
        guard let ctx = CGContext(data: &data, width: dw, height: dh, bitsPerComponent: 8, bytesPerRow: dw * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue),
              let scaled = cg.copy() else {
            return false
        }
        ctx.interpolationQuality = .low
        ctx.draw(scaled, in: CGRect(x: 0, y: 0, width: dw, height: dh))
        var sum: Double = 0
        for i in stride(from: 0, to: data.count, by: 4) {
            let r = Double(data[i]) / 255.0
            let g = Double(data[i+1]) / 255.0
            let b = Double(data[i+2]) / 255.0
            // Perceptual luminance approximation
            let y = 0.2126*r + 0.7152*g + 0.0722*b
            sum += y
        }
        let mean = sum / Double(dw * dh)
        return mean > 0.5
    }

    // MARK: - Segmentation
    public static func segmentCells(in image: UIImage, params: ImagingParams) -> SegmentationResult {
        let input = resizedForProcessing(image, maxLongSide: 2048)
        // Try to load Core ML model; if not found, fallback
        if let _ = try? UNet256Loader.model() {
            // Placeholder: for now, use fallback until model is provided; keep API ready
            return classicalSegmentation(on: input, params: params)
        } else {
            return classicalSegmentation(on: input, params: params)
        }
    }

    private static func classicalSegmentation(on image: UIImage, params: ImagingParams) -> SegmentationResult {
        guard let cg = image.cgImage else { return SegmentationResult(width: 0, height: 0, mask: []) }
        let width = cg.width
        let height = cg.height
        // Downscale for speed if very large
        let maxDim = 512
        let scale = max(1, max(width, height) / maxDim)
        let dw = width / scale
        let dh = height / scale
        let gray = grayscalePixels(from: cg, width: dw, height: dh)
        let invert = shouldInvertPolarity(for: image)
        var grayD = gray.map { Double($0)/255.0 }
        if invert { grayD = grayD.map { 1.0 - $0 } }
        let start = Date()
        let mask: [Bool]
        switch params.thresholdMethod {
        case .adaptive:
            mask = adaptiveThreshold(grayD, w: dw, h: dh, block: max(3, params.blockSize/scale | 1), C: Double(params.C)/255.0)
        case .otsu:
            let t = otsuThreshold(grayD)
            mask = grayD.map { $0 > t }
        }
        PerformanceLogger.shared.record("segmentation", Date().timeIntervalSince(start) * 1000)
        return SegmentationResult(width: dw, height: dh, mask: mask)
    }

    // MARK: - Object Features
    public static func objectFeatures(from seg: SegmentationResult, pxPerMicron: Double?) -> [CellObject] {
        let start = Date()
        let (labels, count) = connectedComponents(seg.mask, w: seg.width, h: seg.height)
        var objects: [CellObject] = []
        objects.reserveCapacity(count)
        var stats: [Int: (minX:Int, maxX:Int, minY:Int, maxY:Int, sumX:Double, sumY:Double, pix:Int, perimeter:Int)] = [:]
        for y in 0..<seg.height {
            for x in 0..<seg.width {
                let idx = y*seg.width + x
                let id = labels[idx]
                if id == 0 { continue }
                if stats[id] == nil {
                    stats[id] = (x,x,y,y,0,0,0,0)
                }
                var s = stats[id]!
                s.minX = min(s.minX, x)
                s.maxX = max(s.maxX, x)
                s.minY = min(s.minY, y)
                s.maxY = max(s.maxY, y)
                s.sumX += Double(x)
                s.sumY += Double(y)
                s.pix += 1
                // Perimeter increment if any 4-neighbor is background
                let neighbors = [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]
                for (nx,ny) in neighbors {
                    if nx < 0 || ny < 0 || nx >= seg.width || ny >= seg.height || !seg.mask[ny*seg.width + nx] {
                        s.perimeter += 1
                        break
                    }
                }
                stats[id] = s
            }
        }
        for (id, s) in stats.sorted(by: { $0.key < $1.key }) {
            let areaPx = Double(s.pix)
            let perimeterPx = Double(s.perimeter)
            let circularity = perimeterPx > 0 ? (4.0 * Double.pi * areaPx) / (perimeterPx * perimeterPx) : 0
            let centroid = CGPoint(x: s.sumX / Double(s.pix), y: s.sumY / Double(s.pix))
            let bbox = CGRect(x: s.minX, y: s.minY, width: s.maxX - s.minX + 1, height: s.maxY - s.minY + 1)
            let obj = CellObject(id: id,
                                  pixelCount: s.pix,
                                  areaPx: areaPx,
                                  perimeterPx: perimeterPx,
                                  circularity: circularity,
                                  solidity: 1.0,
                                  centroid: centroid,
                                  bbox: bbox)
            objects.append(obj)
        }
        PerformanceLogger.shared.record("features", Date().timeIntervalSince(start) * 1000)
        return objects
    }

    // MARK: - Color and Labels
    public static func colorStatsAndLabels(for objects: [CellObject], on image: UIImage) -> [CellObjectLabeled] {
        guard let cg = image.cgImage else { return [] }
        let start = Date()
        let data = rgbaPixels(from: cg)
        let w = cg.width
        // Compute global brightness median approx
        let sampleStep = max(1, (w * cg.height) / 4096)
        var vSamples: [Double] = []
        vSamples.reserveCapacity(4096)
        for i in stride(from: 0, to: data.count, by: 4*sampleStep) {
            let r = Double(data[i]) / 255.0
            let g = Double(data[i+1]) / 255.0
            let b = Double(data[i+2]) / 255.0
            let (_,_,v) = rgbToHsv(r, g, b)
            vSamples.append(v)
        }
        vSamples.sort()
        let imageMedianV = vSamples.isEmpty ? 0.5 : vSamples[vSamples.count/2]

        // Sample colors per object
        var labeled: [CellObjectLabeled] = []
        var satSamples: [Double] = []
        var perObjectStats: [(obj: CellObject, color: ColorSampleStats)] = []
        for obj in objects {
            let x = Int(obj.centroid.x)
            let y = Int(obj.centroid.y)
            let stats = sample5x5Stats(x: x, y: y, data: data, width: w)
            satSamples.append(stats.saturation)
            perObjectStats.append((obj, stats))
        }
        satSamples.sort()
        let satThreshold = satSamples.isEmpty ? 0.3 : satSamples[Int(Double(satSamples.count) * 0.6)]

        for (obj, stats) in perObjectStats {
            let hueInBlue = stats.hue >= 200 && stats.hue <= 260
            let highSat = stats.saturation >= satThreshold
            let lowV = stats.value <= imageMedianV
            let isDead = hueInBlue && highSat && lowV
            let conf = [hueInBlue ? 0.34 : 0, highSat ? 0.33 : 0, lowV ? 0.33 : 0].reduce(0,+)
            labeled.append(CellObjectLabeled(id: obj.id, base: obj, color: stats, label: isDead ? "dead" : "live", confidence: conf))
        }
        PerformanceLogger.shared.record("viability", Date().timeIntervalSince(start) * 1000)
        return labeled
    }

    // MARK: - Helpers
    private static var grayBuffer: [UInt8] = []
    private static func grayscalePixels(from cg: CGImage, width: Int, height: Int) -> [UInt8] {
        let colorSpace = CGColorSpaceCreateDeviceGray()
        if grayBuffer.count != width * height { grayBuffer = [UInt8](repeating: 0, count: width * height) }
        var data = grayBuffer
        if let ctx = CGContext(data: &data, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width, space: colorSpace, bitmapInfo: 0) {
            ctx.interpolationQuality = .low
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return data
    }

    private static var rgbaBuffer: [UInt8] = []
    private static func rgbaPixels(from cg: CGImage) -> [UInt8] {
        let w = cg.width, h = cg.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let count = Int(w*h*4)
        if rgbaBuffer.count != count { rgbaBuffer = [UInt8](repeating: 0, count: count) }
        var data = rgbaBuffer
        if let ctx = CGContext(data: &data, width: w, height: h, bitsPerComponent: 8, bytesPerRow: w*4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) {
            ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
        }
        return data
    }

    private static func adaptiveThreshold(_ gray: [Double], w: Int, h: Int, block: Int, C: Double) -> [Bool] {
        let r = max(1, block/2)
        var out = [Bool](repeating: false, count: w*h)
        for y in 0..<h {
            for x in 0..<w {
                var sum = 0.0
                var count = 0
                for j in max(0,y-r)...min(h-1,y+r) {
                    for i in max(0,x-r)...min(w-1,x+r) {
                        sum += gray[j*w+i]
                        count += 1
                    }
                }
                let mean = sum / Double(count)
                out[y*w+x] = gray[y*w+x] > (mean - C)
            }
        }
        return out
    }

    private static func otsuThreshold(_ gray: [Double]) -> Double {
        let n = gray.count
        if n == 0 { return 0.5 }
        var hist = [Int](repeating: 0, count: 256)
        for v in gray { hist[min(255, max(0, Int(v * 255.0)))] += 1 }
        let total = Double(n)
        var sum: Double = 0
        for t in 0..<256 { sum += Double(t) * Double(hist[t]) }
        var sumB: Double = 0
        var wB: Double = 0
        var varMax: Double = 0
        var threshold: Int = 0
        for t in 0..<256 {
            wB += Double(hist[t])
            if wB == 0 { continue }
            let wF = total - wB
            if wF == 0 { break }
            sumB += Double(t) * Double(hist[t])
            let mB = sumB / wB
            let mF = (sum - sumB) / wF
            let between = wB * wF * (mB - mF) * (mB - mF)
            if between > varMax {
                varMax = between
                threshold = t
            }
        }
        return Double(threshold) / 255.0
    }

    private static func connectedComponents(_ mask: [Bool], w: Int, h: Int) -> ([Int], Int) {
        var labels = [Int](repeating: 0, count: w*h)
        var current = 0
        var queue: [(Int,Int)] = []
        for y in 0..<h {
            for x in 0..<w {
                let idx = y*w + x
                if !mask[idx] || labels[idx] != 0 { continue }
                current += 1
                labels[idx] = current
                queue.removeAll(keepingCapacity: true)
                queue.append((x,y))
                while !queue.isEmpty {
                    let (cx, cy) = queue.removeLast()
                    let neighbors = [(cx-1,cy),(cx+1,cy),(cx,cy-1),(cx,cy+1)]
                    for (nx,ny) in neighbors {
                        if nx < 0 || ny < 0 || nx >= w || ny >= h { continue }
                        let nidx = ny*w + nx
                        if mask[nidx] && labels[nidx] == 0 {
                            labels[nidx] = current
                            queue.append((nx,ny))
                        }
                    }
                }
            }
        }
        return (labels, current)
    }

    private static func sample5x5Stats(x: Int, y: Int, data: [UInt8], width: Int) -> ColorSampleStats {
        var sumR=0.0,sumG=0.0,sumB=0.0,count=0.0
        let height = max(1, data.count / (4*width))
        for j in (y-2)...(y+2) {
            for i in (x-2)...(x+2) {
                let xi = max(0, min(width-1, i))
                let yi = max(0, min(height - 1, j))
                let idx = (yi*width + xi)*4
                sumR += Double(data[idx])
                sumG += Double(data[idx+1])
                sumB += Double(data[idx+2])
                count += 1
            }
        }
        let r = (sumR/count)/255.0
        let g = (sumG/count)/255.0
        let b = (sumB/count)/255.0
        let (h,s,v) = rgbToHsv(r, g, b)
        let (L, a, bLab) = rgbToLab(r, g, b)
        return ColorSampleStats(hue: h, saturation: s, value: v, L: L, a: a, b: bLab)
    }

    // MARK: - Color conversions
    static func rgbToHsv(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        let maxv = max(r,max(g,b))
        let minv = min(r,min(g,b))
        let delta = maxv - minv
        var h: Double = 0
        if delta != 0 {
            if maxv == r { h = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6)) }
            else if maxv == g { h = 60 * (((b - r) / delta) + 2) }
            else { h = 60 * (((r - g) / delta) + 4) }
            if h < 0 { h += 360 }
        }
        let s = maxv == 0 ? 0 : delta / maxv
        return (h, s, maxv)
    }

    static func rgbToLab(_ r: Double, _ g: Double, _ b: Double) -> (Double, Double, Double) {
        func pivot(_ t: Double) -> Double { return t > 0.04045 ? pow((t + 0.055)/1.055, 2.4) : t/12.92 }
        let R = pivot(r), G = pivot(g), B = pivot(b)
        // sRGB D65
        let X = (0.4124*R + 0.3576*G + 0.1805*B) / 0.95047
        let Y = (0.2126*R + 0.7152*G + 0.0722*B) / 1.00000
        let Z = (0.0193*R + 0.1192*G + 0.9505*B) / 1.08883
        func f(_ t: Double) -> Double { return t > 0.008856 ? pow(t, 1.0/3.0) : (7.787*t + 16.0/116.0) }
        let fx = f(X), fy = f(Y), fz = f(Z)
        let L = (116*fy - 16)
        let a = 500*(fx - fy)
        let b = 200*(fy - fz)
        return (L, a, b)
    }

    // MARK: - Resize for processing
    private static func resizedForProcessing(_ image: UIImage, maxLongSide: Int) -> UIImage {
        let w = Int(image.size.width), h = Int(image.size.height)
        let longSide = max(w, h)
        guard longSide > maxLongSide else { return image }
        let scale = Double(longSide) / Double(maxLongSide)
        let nw = Int(Double(w) / scale)
        let nh = Int(Double(h) / scale)
        let r = UIGraphicsImageRenderer(size: CGSize(width: nw, height: nh))
        return r.image { _ in image.draw(in: CGRect(x: 0, y: 0, width: nw, height: nh)) }
    }
}

// MARK: - UNet Loader Stub
enum UNet256Loader {
    static func model() throws -> MLModel {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: "UNet256", withExtension: "mlmodelc") ?? bundle.url(forResource: "UNet256", withExtension: "mlmodel") else {
            throw NSError(domain: "UNet", code: -1)
        }
        if url.pathExtension == "mlmodelc" {
            return try MLModel(contentsOf: url)
        } else {
            let compiled = try MLModel.compileModel(at: url)
            return try MLModel(contentsOf: compiled)
        }
    }
}
