import Foundation
import CoreImage

struct HSVImage {
    let h: CIImage
    let s: CIImage
    let value: CIImage
}

enum BlueMask {
    static func mask(fromHSV hsv: HSVImage,
                     hueRange: ClosedRange<Double>,
                     minS: Double,
                     maxV: Double,
                     context: CIContext) -> CIImage {
        let hMin = hueRange.lowerBound/360.0
        let hMax = hueRange.upperBound/360.0
        let sMin = minS
        let vMax = maxV

        let sPass = hsv.s.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 10, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 10, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 10, w: 0),
            "inputBiasVector": CIVector(x: -CGFloat(10*sMin), y: -CGFloat(10*sMin), z: -CGFloat(10*sMin), w: 0)
        ])
        let vPass = hsv.value.applyingFilter("CIColorInvert").applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 10, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 10, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 10, w: 0),
            "inputBiasVector": CIVector(x: -CGFloat(10*(1.0 - vMax)), y: -CGFloat(10*(1.0 - vMax)), z: -CGFloat(10*(1.0 - vMax)), w: 0)
        ])

        // Approximate hue band test: wrap around by duplicating bands if needed
        let hScaled = hsv.h
        let lower = hScaled.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 10, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 10, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 10, w: 0),
            "inputBiasVector": CIVector(x: -CGFloat(10*hMin), y: -CGFloat(10*hMin), z: -CGFloat(10*hMin), w: 0)
        ])
        let band = lower // soft thresholding

        let combined = band.applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: sPass])
            .applyingFilter("CIMultiplyCompositing", parameters: [kCIInputBackgroundImageKey: vPass])
        return combined
    }
}


