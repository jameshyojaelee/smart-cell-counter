import Foundation
import UIKit
import Vision
import CoreImage
import CoreML
import CoreVideo
import Metal

public enum ImagingPipeline {
    private static let unetLock = DispatchQueue(label: "com.smartcellcounter.unet.lock")
    private static var cachedUNetModel: MLModel?
    private static var unetLoadAttempted = false

    public static var isCoreMLSegmentationAvailable: Bool {
        loadUNetModel() != nil
    }

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
        let requested = params.strategy
        switch requested {
        case .classical:
            return classicalSegmentation(on: image, params: params, requested: requested)
        case .coreML, .automatic:
            if let model = loadUNetModel() {
                do {
                    return try coreMLSegmentation(on: image, params: params, model: model)
                } catch {
                    Logger.log("Core ML segmentation failed, falling back to classical. Error: \(error)")
                }
            } else if requested == .coreML {
                Logger.log("Core ML segmentation requested but UNet model not found. Reverting to classical path.")
            }
            return classicalSegmentation(on: image, params: params, requested: .classical)
        }
    }

    private static func classicalSegmentation(on image: UIImage, params: ImagingParams, requested: SegmentationStrategy) -> SegmentationResult {
        guard let cg = image.cgImage else {
            return SegmentationResult(width: 0, height: 0, mask: [], usedStrategy: .classical, originalSize: image.size)
        }
        let width = cg.width
        let height = cg.height
        // Downscale for speed if very large (tuned for responsiveness)
        let maxDim = 384
        let rawScale = max(1.0, Double(max(width, height)) / Double(maxDim))
        let dw = max(1, Int(round(Double(width) / rawScale)))
        let dh = max(1, Int(round(Double(height) / rawScale)))
        let scale = max(1.0, Double(width) / Double(dw))
        let gray = grayscalePixels(from: cg, width: dw, height: dh)
        let invert = shouldInvertPolarity(for: image)
        var grayD = gray.map { Double($0)/255.0 }
        if invert { grayD = grayD.map { 1.0 - $0 } }
        let start = Date()
        let mask: [Bool]
        switch params.thresholdMethod {
        case .adaptive:
            let adjustedBlock = max(3, Int(Double(params.blockSize) / scale)) | 1
            mask = adaptiveThreshold(grayD, w: dw, h: dh, block: adjustedBlock, C: Double(params.C)/255.0)
        case .otsu:
            let t = otsuThreshold(grayD)
            mask = grayD.map { $0 > t }
        }
        PerformanceLogger.shared.record("segmentation", Date().timeIntervalSince(start) * 1000)
        return SegmentationResult(width: dw,
                                  height: dh,
                                  mask: mask,
                                  downscaleFactor: scale,
                                  polarityInverted: invert,
                                  usedStrategy: .classical,
                                  originalSize: CGSize(width: width, height: height))
    }

    private static func coreMLSegmentation(on image: UIImage, params _: ImagingParams, model: MLModel) throws -> SegmentationResult {
        guard let cg = image.cgImage else {
            throw NSError(domain: "Segmentation", code: -2, userInfo: [NSLocalizedDescriptionKey: "Missing CGImage"])
        }
        let originalWidth = cg.width
        let originalHeight = cg.height
        let invert = shouldInvertPolarity(for: image)
        let start = Date()

        let description = model.modelDescription
        guard let (inputName, inputDescription) = description.inputDescriptionsByName.first else {
            throw NSError(domain: "Segmentation", code: -3, userInfo: [NSLocalizedDescriptionKey: "Model has no inputs"])
        }
        guard inputDescription.type == .image, let constraint = inputDescription.imageConstraint else {
            throw NSError(domain: "Segmentation", code: -4, userInfo: [NSLocalizedDescriptionKey: "Model input must be image"])
        }
        guard let pixelBuffer = pixelBuffer(from: image, width: constraint.pixelsWide, height: constraint.pixelsHigh) else {
            throw NSError(domain: "Segmentation", code: -5, userInfo: [NSLocalizedDescriptionKey: "Could not create pixel buffer"])
        }
        let provider = try MLDictionaryFeatureProvider(dictionary: [inputName: MLFeatureValue(pixelBuffer: pixelBuffer)])
        let output = try model.prediction(from: provider)

        guard let (mask, mw, mh) = extractMask(from: output, description: description) else {
            throw NSError(domain: "Segmentation", code: -6, userInfo: [NSLocalizedDescriptionKey: "Unsupported model output"])
        }

        PerformanceLogger.shared.record("segmentation", Date().timeIntervalSince(start) * 1000)
        let downscale = max(Double(originalWidth) / Double(max(1, mw)),
                            Double(originalHeight) / Double(max(1, mh)))

        return SegmentationResult(width: mw,
                                  height: mh,
                                  mask: mask,
                                  downscaleFactor: downscale,
                                  polarityInverted: invert,
                                  usedStrategy: .coreML,
                                  originalSize: CGSize(width: originalWidth, height: originalHeight))
    }

    private static func loadUNetModel() -> MLModel? {
        if let cached = cachedUNetModel { return cached }
        return unetLock.sync {
            if let cached = cachedUNetModel { return cached }
            if unetLoadAttempted { return nil }
            unetLoadAttempted = true
            do {
                let model = try UNet256Loader.model()
                cachedUNetModel = model
                return model
            } catch {
                Logger.log("UNet256 model unavailable: \(error)")
                return nil
            }
        }
    }

    private static func pixelBuffer(from image: UIImage, width: Int, height: Int) -> CVPixelBuffer? {
        let targetSize = CGSize(width: width, height: height)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let scaled = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: targetSize))
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        guard let cg = scaled.cgImage else { return nil }

        var buffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         attrs as CFDictionary,
                                         &buffer)
        guard status == kCVReturnSuccess, let pixelBuffer = buffer else { return nil }

        CVPixelBufferLockBaseAddress(pixelBuffer, [])
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }
        guard let base = CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
        guard let context = CGContext(data: base,
                                      width: width,
                                      height: height,
                                      bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(pixelBuffer),
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue) else {
            return nil
        }
        context.interpolationQuality = .high
        context.draw(cg, in: CGRect(origin: .zero, size: targetSize))
        return pixelBuffer
    }

    private static func extractMask(from output: MLFeatureProvider, description: MLModelDescription) -> ([Bool], Int, Int)? {
        for (name, desc) in description.outputDescriptionsByName {
            guard let value = output.featureValue(for: name) else { continue }
            switch desc.type {
            case .multiArray:
                if let array = value.multiArrayValue, let mask = mask(from: array) {
                    return mask
                }
            case .image:
                if let buffer = value.imageBufferValue, let mask = mask(from: buffer) {
                    return mask
                }
            default:
                continue
            }
        }
        return nil
    }

    private static func mask(from multiArray: MLMultiArray) -> ([Bool], Int, Int)? {
        let shape = multiArray.shape.map { Int(truncating: $0) }
        guard !shape.isEmpty else { return nil }

        var height = 0
        var width = 0
        if shape.count == 2 {
            height = shape[shape.startIndex]
            width = shape[shape.startIndex + 1]
        } else if shape.count >= 3 {
            // Collapse channel dimension if present
            let dims = shape.filter { $0 > 1 }
            guard dims.count >= 2 else { return nil }
            height = dims[dims.count - 2]
            width = dims[dims.count - 1]
        } else {
            return nil
        }
        if height <= 0 || width <= 0 { return nil }
        let elementCount = height * width
        var mask = [Bool](repeating: false, count: elementCount)

        switch multiArray.dataType {
        case .double:
            let pointer = multiArray.dataPointer.bindMemory(to: Double.self, capacity: multiArray.count)
            for i in 0..<elementCount {
                mask[i] = pointer[i] > 0.5
            }
        case .float32:
            let pointer = multiArray.dataPointer.bindMemory(to: Float32.self, capacity: multiArray.count)
            for i in 0..<elementCount {
                mask[i] = pointer[i] > 0.5
            }
        case .int32:
            let pointer = multiArray.dataPointer.bindMemory(to: Int32.self, capacity: multiArray.count)
            for i in 0..<elementCount {
                mask[i] = pointer[i] > 0
            }
        default:
            for i in 0..<elementCount {
                mask[i] = multiArray[i].doubleValue > 0.5
            }
        }
        return (mask, width, height)
    }

    private static func mask(from buffer: CVPixelBuffer) -> ([Bool], Int, Int)? {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        guard let base = CVPixelBufferGetBaseAddress(buffer) else { return nil }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
        var mask = [Bool](repeating: false, count: width * height)
        let ptr = base.assumingMemoryBound(to: UInt8.self)
        for y in 0..<height {
            let row = ptr.advanced(by: y * bytesPerRow)
            for x in 0..<width {
                mask[y*width + x] = row[x] > 127
            }
        }
        return (mask, width, height)
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
                // Perimeter increments for each background neighbor (4-connectivity)
                let neighbors = [(x-1,y),(x+1,y),(x,y-1),(x,y+1)]
                for (nx,ny) in neighbors {
                    if nx < 0 || ny < 0 || nx >= seg.width || ny >= seg.height || !seg.mask[ny*seg.width + nx] {
                        s.perimeter += 1
                    }
                }
                stats[id] = s
            }
        }
        let scale = max(seg.downscaleFactor, 1.0)
        let scaleSquared = scale * scale
        for (id, s) in stats.sorted(by: { $0.key < $1.key }) {
            guard s.pix > 0 else { continue }
            let areaPx = Double(s.pix) * scaleSquared
            let perimeterPx = Double(s.perimeter) * scale
            let circularity = perimeterPx > 0 ? (4.0 * Double.pi * areaPx) / (perimeterPx * perimeterPx) : 0
            let centroid = CGPoint(x: (s.sumX / Double(s.pix)) * scale,
                                   y: (s.sumY / Double(s.pix)) * scale)
            let bbox = CGRect(x: Double(s.minX) * scale,
                              y: Double(s.minY) * scale,
                              width: Double(s.maxX - s.minX + 1) * scale,
                              height: Double(s.maxY - s.minY + 1) * scale)
            let obj = CellObject(id: id,
                                  pixelCount: Int(round(areaPx)),
                                  areaPx: areaPx,
                                  perimeterPx: perimeterPx,
                                  circularity: circularity,
                                  solidity: 1.0,
                                  centroid: centroid,
                                  bbox: bbox.integral)
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

    private static var integralBuffer: [Double] = []
    private static func adaptiveThreshold(_ gray: [Double], w: Int, h: Int, block: Int, C: Double) -> [Bool] {
        // O(1) mean per pixel using an integral image (summed area table)
        // Build integral image with (w+1)*(h+1) to simplify boundary handling
        let iw = w + 1
        let ih = h + 1
        let needed = iw * ih
        if integralBuffer.count != needed { integralBuffer = [Double](repeating: 0, count: needed) }
        // Row 0 and col 0 remain zeros
        for y in 0..<h {
            var rowSum = 0.0
            let base = (y+1) * iw
            let prev = y * iw
            for x in 0..<w {
                rowSum += gray[y*w + x]
                integralBuffer[base + (x+1)] = integralBuffer[prev + (x+1)] + rowSum
            }
        }
        let r = max(1, block/2)
        var out = [Bool](repeating: false, count: w*h)
        @inline(__always) func sumRect(_ x0: Int, _ y0: Int, _ x1: Int, _ y1: Int) -> Double {
            let xa = x0, ya = y0, xb = x1 + 1, yb = y1 + 1
            return integralBuffer[yb*iw + xb] - integralBuffer[ya*iw + xb] - integralBuffer[yb*iw + xa] + integralBuffer[ya*iw + xa]
        }
        for y in 0..<h {
            let y0 = max(0, y - r)
            let y1 = min(h - 1, y + r)
            for x in 0..<w {
                let x0 = max(0, x - r)
                let x1 = min(w - 1, x + r)
                let count = Double((x1 - x0 + 1) * (y1 - y0 + 1))
                let mean = sumRect(x0, y0, x1, y1) / count
                out[y*w + x] = gray[y*w + x] > (mean - C)
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
