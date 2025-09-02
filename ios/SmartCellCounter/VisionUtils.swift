import Foundation
import UIKit
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

struct RectangleDetectionResult {
  let corners: [CGPoint]  // TL, TR, BR, BL
  let focusScore: Double
  let glareRatio: Double
}

final class VisionUtils {

  static func detectRectangle(in uiImage: UIImage,
                              completion: @escaping (RectangleDetectionResult?) -> Void) {
    guard let cgImage = uiImage.cgImage else { completion(nil); return }

    let request = VNDetectRectanglesRequest { req, err in
      if let err = err {
        completion(nil)
        return
      }
      guard let observations = req.results as? [VNRectangleObservation],
            let best = observations.max(by: { $0.confidence < $1.confidence }) else {
        completion(nil)
        return
      }

      let w = CGFloat(cgImage.width)
      let h = CGFloat(cgImage.height)
      let tl = CGPoint(x: best.topLeft.x * w, y: (1.0 - best.topLeft.y) * h)
      let tr = CGPoint(x: best.topRight.x * w, y: (1.0 - best.topRight.y) * h)
      let br = CGPoint(x: best.bottomRight.x * w, y: (1.0 - best.bottomRight.y) * h)
      let bl = CGPoint(x: best.bottomLeft.x * w, y: (1.0 - best.bottomLeft.y) * h)

      let focus = Self.laplacianVariance(uiImage: uiImage)
      let glare = Self.glareRatio(uiImage: uiImage, threshold: 0.98)

      completion(RectangleDetectionResult(corners: [tl, tr, br, bl],
                                          focusScore: focus,
                                          glareRatio: glare))
    }

    request.minimumAspectRatio = 0.6
    request.maximumAspectRatio = 1.4
    request.minimumSize = 0.2
    request.quadratureTolerance = 15.0

    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      try? handler.perform([request])
    }
  }

  static func laplacianVariance(uiImage: UIImage) -> Double {
    guard let ciImage = CIImage(image: uiImage) else { return 0.0 }
    let kernel = CIVector(values: [
      0,  1, 0,
      1, -4, 1,
      0,  1, 0
    ], count: 9)
    let filter = CIFilter.convolution3X3()
    filter.inputImage = ciImage
    filter.bias = 0
    filter.weights = kernel
    guard let out = filter.outputImage else { return 0.0 }
    let context = CIContext(options: nil)
    guard let bitmap = context.createCGImage(out, from: out.extent) else { return 0.0 }
    guard let data = bitmap.dataProvider?.data as Data? else { return 0.0 }
    let ptr = data.withUnsafeBytes { $0.bindMemory(to: UInt8.self).baseAddress! }
    let count = data.count
    var mean: Double = 0
    for i in stride(from: 0, to: count, by: 4) { mean += Double(ptr[i]) }
    mean /= Double(count / 4)
    var varSum: Double = 0
    for i in stride(from: 0, to: count, by: 4) {
      let v = Double(ptr[i])
      varSum += (v - mean) * (v - mean)
    }
    return varSum / Double(count / 4)
  }

  static func glareRatio(uiImage: UIImage, threshold: CGFloat) -> Double {
    guard let cg = uiImage.cgImage else { return 0.0 }
    let w = cg.width, h = cg.height
    guard let ctx = CGContext(data: nil, width: w, height: h, bitsPerComponent: 8,
                              bytesPerRow: w * 4, space: CGColorSpaceCreateDeviceRGB(),
                              bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    else { return 0.0 }

    ctx.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    guard let buf = ctx.data else { return 0.0 }
    let p = buf.bindMemory(to: UInt8.self, capacity: w*h*4)
    var bright = 0
    for i in stride(from: 0, to: w*h*4, by: 4) {
      let r = CGFloat(p[i]) / 255.0
      let g = CGFloat(p[i+1]) / 255.0
      let b = CGFloat(p[i+2]) / 255.0
      let v = max(r, max(g, b))
      if v > threshold { bright += 1 }
    }
    return Double(bright) / Double(w*h)
  }

  static func perspectiveCorrect(image: UIImage, corners: [CGPoint], outputSize: CGSize? = nil) -> UIImage? {
    guard corners.count == 4, let ciImage = CIImage(image: image) else { return nil }
    let tl = corners[0], tr = corners[1], br = corners[2], bl = corners[3]
    let filter = CIFilter.perspectiveCorrection()
    filter.inputImage = ciImage
    filter.topLeft = tl
    filter.topRight = tr
    filter.bottomRight = br
    filter.bottomLeft = bl
    guard var out = filter.outputImage else { return nil }

    if let size = outputSize {
      out = out.transformed(by: CGAffineTransform(scaleX: size.width / out.extent.width,
                                                  y: size.height / out.extent.height))
    }
    let ctx = CIContext()
    guard let cg = ctx.createCGImage(out, from: out.extent) else { return nil }
    return UIImage(cgImage: cg)
  }
}
