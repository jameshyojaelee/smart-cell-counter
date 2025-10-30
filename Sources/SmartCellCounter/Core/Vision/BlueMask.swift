import CoreImage
import Foundation

struct HSVImage {
    let h: CIImage
    let s: CIImage
    let value: CIImage
}

enum BlueMask {
    private static let hueBandKernel: CIColorKernel? = {
        let source = """
        kernel vec4 hueBand(__sample hueSample, float minHue, float maxHue) {
            float h = hueSample.r;
            float inRange = 0.0;
            if (minHue <= maxHue) {
                inRange = (h >= minHue && h <= maxHue) ? 1.0 : 0.0;
            } else {
                inRange = (h >= minHue || h <= maxHue) ? 1.0 : 0.0;
            }
            return vec4(inRange, inRange, inRange, 1.0);
        }
        """
        return CIColorKernel(source: source)
    }()

    static func mask(fromHSV hsv: HSVImage,
                     hueMin: Double,
                     hueMax: Double,
                     minS: Double,
                     maxV: Double,
                     context _: CIContext) -> CIImage {
        let hMin = hueMin / 360.0
        let hMax = hueMax / 360.0
        let sMin = minS
        let vMax = maxV

        let sPass = hsv.s.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 10, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 10, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 10, w: 0),
            "inputBiasVector": CIVector(x: -CGFloat(10 * sMin), y: -CGFloat(10 * sMin), z: -CGFloat(10 * sMin), w: 0)
        ])
        let vPass = hsv.value.applyingFilter("CIColorInvert").applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 10, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 10, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 10, w: 0),
            "inputBiasVector": CIVector(x: -CGFloat(10 * (1.0 - vMax)), y: -CGFloat(10 * (1.0 - vMax)), z: -CGFloat(10 * (1.0 - vMax)), w: 0)
        ])

        let hueMask: CIImage = {
            guard let kernel = hueBandKernel,
                  let image = kernel.apply(extent: hsv.h.extent, arguments: [hsv.h, CGFloat(hMin), CGFloat(hMax)])
            else {
                return CIImage(color: CIColor(red: 1, green: 1, blue: 1)).cropped(to: hsv.h.extent)
            }
            return image
        }()

        let combined = hueMask
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: sPass])
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: vPass])
        return combined
    }
}
