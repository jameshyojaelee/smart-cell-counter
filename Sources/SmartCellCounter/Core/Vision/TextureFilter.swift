import Foundation
import CoreImage

enum TextureFilter {
    static func textureMask(from image: CIImage, context: CIContext) -> CIImage {
        let kernel: [CGFloat] = [0,1,0, 1,-4,1, 0,1,0]
        let lap = CIFilter(name: "CIConvolution3X3", parameters: [kCIInputImageKey: image, "inputWeights": CIVector(values: kernel, count: 9), "inputBias": 0])?.outputImage ?? image
        let absLap = lap.applyingFilter("CIColorAbsoluteDifference", parameters: [kCIInputImageKey: lap,
                                                                                 "inputImage2": lap.applyingFilter("CIColorInvert")])
        let norm = absLap.applyingFilter("CIColorControls", parameters: [kCIInputContrastKey: 2.0])
        let thresh = norm.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 10, y: 0, z: 0, w: 0),
                                                                       "inputGVector": CIVector(x: 0, y: 10, z: 0, w: 0),
                                                                       "inputBVector": CIVector(x: 0, y: 0, z: 10, w: 0),
                                                                       "inputBiasVector": CIVector(x: -5, y: -5, z: -5, w: 0)])
        return thresh
    }
}


