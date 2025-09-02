import Foundation
import UIKit
import CoreML
import Vision
import VideoToolbox

final class SegmentationCoreML {
  static let shared = SegmentationCoreML()
  private var model: VNCoreMLModel?

  private init() {
    if let url = Bundle.main.url(forResource: "UNet256", withExtension: "mlmodelc") {
      do {
        let compiledModel = try MLModel(contentsOf: url)
        self.model = try VNCoreMLModel(for: compiledModel)
      } catch {
        self.model = nil
      }
    } else {
      self.model = nil
    }
  }

  func runSegmentation(image: UIImage, completion: @escaping (_ mask: CGImage?) -> Void) {
    guard let cgImage = image.cgImage, let vnModel = self.model else {
      completion(nil); return
    }
    let request = VNCoreMLRequest(model: vnModel) { req, _ in
      guard let results = req.results as? [VNPixelBufferObservation],
            let obs = results.first else {
        completion(nil); return
      }
      var cg: CGImage?
      VTCreateCGImageFromCVPixelBuffer(obs.pixelBuffer, options: nil, imageOut: &cg)
      completion(cg)
    }
    request.imageCropAndScaleOption = .scaleFill
    let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
    DispatchQueue.global(qos: .userInitiated).async {
      try? handler.perform([request])
    }
  }
}
