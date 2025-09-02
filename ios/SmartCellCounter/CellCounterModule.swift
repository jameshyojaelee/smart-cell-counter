import Foundation
import UIKit

@objc(CellCounterModule)
final class CellCounterModule: NSObject {

  @objc
  static func requiresMainQueueSetup() -> Bool { false }

  @objc(detectGridAndCorners:resolver:rejecter:)
  func detectGridAndCorners(inputUri: NSString,
                            resolver: @escaping RCTPromiseResolveBlock,
                            rejecter: @escaping RCTPromiseRejectBlock) {
    guard let url = URL(string: inputUri as String),
          let data = try? Data(contentsOf: url),
          let img = UIImage(data: data) else {
      rejecter("io_error", "Cannot load image", nil); return
    }
    VisionUtils.detectRectangle(in: img) { result in
      guard let res = result else {
        rejecter("no_rectangle", "No rectangle detected", nil); return
      }
      let corners = res.corners.map { ["x": $0.x, "y": $0.y] }
      resolver([
        "corners": corners,
        "gridType": "neubauer",
        "pixelsPerMicron": NSNull(),
        "focusScore": res.focusScore,
        "glareRatio": res.glareRatio
      ])
    }
  }

  @objc(perspectiveCorrect:corners:resolver:rejecter:)
  func perspectiveCorrect(inputUri: NSString,
                          corners: NSArray,
                          resolver: @escaping RCTPromiseResolveBlock,
                          rejecter: @escaping RCTPromiseRejectBlock) {
    guard let url = URL(string: inputUri as String),
          let data = try? Data(contentsOf: url),
          let img = UIImage(data: data) else {
      rejecter("io_error", "Cannot load image", nil); return
    }
    let pts: [CGPoint] = corners.compactMap {
      if let dict = $0 as? NSDictionary,
         let x = dict["x"] as? CGFloat,
         let y = dict["y"] as? CGFloat { return CGPoint(x: x, y: y) }
      return nil
    }
    guard let corrected = VisionUtils.perspectiveCorrect(image: img, corners: pts) else {
      rejecter("perspective_error", "Perspective correction failed", nil); return
    }
    let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + ".jpg")
    guard let jpeg = corrected.jpegData(compressionQuality: 0.95) else {
      rejecter("encode_error", "Failed to encode corrected image", nil); return
    }
    do {
      try jpeg.write(to: tmp)
      resolver(tmp.absoluteString)
    } catch {
      rejecter("write_error", "Failed to write corrected image", error)
    }
  }

  @objc(runCoreMLSegmentation:resolver:rejecter:)
  func runCoreMLSegmentation(correctedImageUri: NSString,
                             resolver: @escaping RCTPromiseResolveBlock,
                             rejecter: @escaping RCTPromiseRejectBlock) {
    guard let url = URL(string: correctedImageUri as String),
          let data = try? Data(contentsOf: url),
          let img = UIImage(data: data) else {
      rejecter("io_error", "Cannot load corrected image", nil); return
    }
    SegmentationCoreML.shared.runSegmentation(image: img) { mask in
      guard let mask = mask else { resolver(NSNull()); return }
      let uiMask = UIImage(cgImage: mask)
      let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString + "_mask.png")
      guard let png = uiMask.pngData() else {
        rejecter("encode_error", "Failed to encode mask", nil); return
      }
      do {
        try png.write(to: tmp)
        resolver(tmp.absoluteString)
      } catch {
        rejecter("write_error", "Failed to write mask", error)
      }
    }
  }
}
