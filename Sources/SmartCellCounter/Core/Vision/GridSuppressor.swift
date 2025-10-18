import Foundation
import CoreImage
import UIKit

enum GridSuppressor {
    static func estimateGridMask(from image: CIImage, context: CIContext) -> CIImage {
        // Edge map
        let edges = image.applyingFilter("CIEdges", parameters: [kCIInputIntensityKey: 1.0])
            .applyingFilter("CIColorControls", parameters: [kCIInputSaturationKey: 0])
        guard let cg = context.createCGImage(edges, from: edges.extent) else { return CIImage(color: .black).cropped(to: image.extent) }
        let w = cg.width, h = cg.height
        guard let data = cg.dataProvider?.data as Data? else { return CIImage(color: .black).cropped(to: image.extent) }
        var rowSum = [Double](repeating: 0, count: h)
        var colSum = [Double](repeating: 0, count: w)
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let p = ptr.bindMemory(to: UInt8.self).baseAddress!
            let stride = cg.bytesPerRow
            for y in 0..<h {
                var r = 0.0
                let line = p + y*stride
                for x in 0..<w { r += Double(line[x*4]) }
                rowSum[y] = r
            }
            for x in 0..<w {
                var c = 0.0
                for y in 0..<h {
                    let line = p + y*stride
                    c += Double(line[x*4])
                }
                colSum[x] = c
            }
        }
        func peaks(_ arr: [Double], win: Int, k: Int) -> [Int] {
            let n = arr.count
            var scores: [(Double,Int)] = []
            for i in 0..<n {
                let a = max(0, i-win)...min(n-1, i+win)
                let localMean = a.map { arr[$0] }.reduce(0,+)/Double(a.count)
                let s = arr[i] - localMean
                scores.append((s, i))
            }
            scores.sort(by: { $0.0 > $1.0 })
            return scores.prefix(k).map { $0.1 }
        }
        let rPeaks = peaks(rowSum, win: max(1, h/40), k: 20)
        let cPeaks = peaks(colSum, win: max(1, w/40), k: 20)
        let scaleX = image.extent.width / CGFloat(w)
        let scaleY = image.extent.height / CGFloat(h)
        let mask = UIGraphicsImageRenderer(size: CGSize(width: image.extent.width, height: image.extent.height)).image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: CGSize(width: image.extent.width, height: image.extent.height)))
            ctx.cgContext.setFillColor(UIColor.white.cgColor)
            for y in rPeaks {
                let ry = CGFloat(y) * scaleY
                ctx.cgContext.fill(CGRect(x: 0, y: ry-2, width: image.extent.width, height: 4))
            }
            for x in cPeaks {
                let rx = CGFloat(x) * scaleX
                ctx.cgContext.fill(CGRect(x: rx-2, y: 0, width: 4, height: image.extent.height))
            }
        }
        return CIImage(image: mask) ?? CIImage(color: .black).cropped(to: image.extent)
    }
}


