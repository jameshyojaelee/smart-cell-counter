import UIKit
import CoreImage

public enum ViabilityClassifier {
    public static func label(objects: [CellObject], on image: UIImage) -> [CellObjectLabeled] {
        guard let cg = image.cgImage else { return objects.map { CellObjectLabeled(id: $0.id, base: $0, isDead: false, confidence: 0.5, hsv: (0,0,0), lab: (0,0,0)) } }
        let width = cg.width
        let height = cg.height
        guard let data = cg.dataProvider?.data as Data? else { return objects.map { CellObjectLabeled(id: $0.id, base: $0, isDead: false, confidence: 0.5, hsv: (0,0,0), lab: (0,0,0)) } }
        let bytes = [UInt8](data)
        // Compute global V median
        var vValues: [Double] = []
        vValues.reserveCapacity(width*height/16)
        let strideBytes = cg.bytesPerRow
        for y in stride(from: 0, to: height, by: 4) {
            for x in stride(from: 0, to: width, by: 4) {
                let i = y*strideBytes + x*4
                if i+3 < bytes.count {
                    let r = Double(bytes[i+0]) / 255.0
                    let g = Double(bytes[i+1]) / 255.0
                    let b = Double(bytes[i+2]) / 255.0
                    let (_,_,v) = rgb2hsv(r,g,b)
                    vValues.append(v)
                }
            }
        }
        let globalMedianV = median(of: vValues)

        // Per-object HSV sampling
        var labels: [CellObjectLabeled] = []
        var sAll: [Double] = []
        var perObjectHSV: [Int: (h: Double,s: Double,v: Double)] = [:]
        for obj in objects {
            let cx = Int(obj.centroid.x)
            let cy = Int(obj.centroid.y)
            var pixels: [(Double,Double,Double)] = []
            for dy in -2...2 {
                for dx in -2...2 {
                    let x = min(max(0, cx+dx), width-1)
                    let y = min(max(0, cy+dy), height-1)
                    let idx = y*strideBytes + x*4
                    if idx+3 < bytes.count {
                        let r = Double(bytes[idx+0]) / 255.0
                        let g = Double(bytes[idx+1]) / 255.0
                        let b = Double(bytes[idx+2]) / 255.0
                        pixels.append(rgb2hsv(r,g,b))
                    }
                }
            }
            let h = pixels.map{$0.0}.average()
            let s = pixels.map{$0.1}.average()
            let v = pixels.map{$0.2}.average()
            perObjectHSV[obj.id] = (h,s,v)
            sAll.append(s)
        }
        let sThreshold = percentile(sAll, p: 0.6)

        for obj in objects {
            let hsv = perObjectHSV[obj.id] ?? (0,0,0)
            let lab = rgb2labHSVProxy(hsv: hsv)
            let isBlueHue = hsv.h >= 200 && hsv.h <= 260
            let highS = hsv.s >= sThreshold
            let lowV = hsv.v <= globalMedianV
            let isDead = isBlueHue && highS && lowV
            let confidence = [isBlueHue, highS, lowV].map { $0 ? 1.0 : 0.0 }.average()
            labels.append(CellObjectLabeled(id: obj.id, base: obj, isDead: isDead, confidence: confidence, hsv: hsv, lab: lab))
        }
        return labels
    }

    private static func rgb2hsv(_ r: Double, _ g: Double, _ b: Double) -> (h: Double, s: Double, v: Double) {
        let maxV = max(r, max(g,b)); let minV = min(r, min(g,b))
        let v = maxV
        let d = maxV - minV
        let s = maxV == 0 ? 0 : d / maxV
        var h: Double = 0
        if d == 0 { h = 0 }
        else if maxV == r { h = 60 * fmod(((g - b) / d), 6) }
        else if maxV == g { h = 60 * (((b - r) / d) + 2) }
        else { h = 60 * (((r - g) / d) + 4) }
        if h < 0 { h += 360 }
        return (h,s,v)
    }

    private static func rgb2labHSVProxy(hsv: (h: Double,s: Double,v: Double)) -> (l: Double,a: Double,b: Double) {
        // Rough proxy: convert HSV back to sRGB then to Lab
        let rgb = hsv2rgb(hsv.h, hsv.s, hsv.v)
        return rgb2lab(rgb.r, rgb.g, rgb.b)
    }

    private static func hsv2rgb(_ h: Double, _ s: Double, _ v: Double) -> (r: Double,g: Double,b: Double) {
        let c = v * s
        let x = c * (1 - abs(fmod(h/60.0, 2) - 1))
        let m = v - c
        var (r,g,b) = (0.0,0.0,0.0)
        switch h {
        case 0..<60: (r,g,b) = (c,x,0)
        case 60..<120: (r,g,b) = (x,c,0)
        case 120..<180: (r,g,b) = (0,c,x)
        case 180..<240: (r,g,b) = (0,x,c)
        case 240..<300: (r,g,b) = (x,0,c)
        default: (r,g,b) = (c,0,x)
        }
        return (r+m,g+m,b+m)
    }

    private static func rgb2lab(_ r: Double,_ g: Double,_ b: Double) -> (l: Double,a: Double,b: Double) {
        func pivot(_ x: Double) -> Double { x > 0.008856 ? pow(x, 1.0/3.0) : (7.787 * x + 16.0/116.0) }
        // sRGB to XYZ
        func invGamma(_ u: Double) -> Double { u <= 0.04045 ? u/12.92 : pow((u+0.055)/1.055, 2.4) }
        let R = invGamma(r), G = invGamma(g), B = invGamma(b)
        let X = (0.4124*R + 0.3576*G + 0.1805*B) / 0.95047
        let Y = (0.2126*R + 0.7152*G + 0.0722*B) / 1.0
        let Z = (0.0193*R + 0.1192*G + 0.9505*B) / 1.08883
        let fx = pivot(X), fy = pivot(Y), fz = pivot(Z)
        let L = 116 * fy - 16
        let a = 500 * (fx - fy)
        let b = 200 * (fy - fz)
        return (L,a,b)
    }

    private static func median(of arr: [Double]) -> Double { guard !arr.isEmpty else { return 0 }; let s = arr.sorted(); let m = s.count/2; if s.count % 2 == 0 { return (s[m-1]+s[m])/2 } else { return s[m] } }
    private static func percentile(_ arr: [Double], p: Double) -> Double { guard !arr.isEmpty else { return 0 }; let s = arr.sorted(); let idx = min(max(0, Int(Double(s.count-1) * p)), s.count-1); return s[idx] }
}

extension Array where Element == Double {
    fileprivate func average() -> Double { if self.isEmpty { return 0 }; return self.reduce(0,+) / Double(self.count) }
}
