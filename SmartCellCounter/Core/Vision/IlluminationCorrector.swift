import Foundation
import CoreImage
import Accelerate

enum IlluminationCorrector {
    static func flatten(luminance: CIImage, context: CIContext) -> (illumination: CIImage, flattened: CIImage) {
        let bg = luminance.clampedToExtent().applyingFilter("CIGaussianBlur", parameters: [kCIInputRadiusKey: 30])
            .cropped(to: luminance.extent)
        let epsilon: CGFloat = 1e-3
        let l1 = luminance.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputBiasVector": CIVector(x: epsilon, y: epsilon, z: epsilon, w: 0)
        ])
        let flat = l1.applyingFilter("CIDivideBlendMode", parameters: [kCIInputBackgroundImageKey: bg])
        return (bg, flat)
    }

    static func equalize(_ luminance: CIImage, context: CIContext) -> CIImage {
        let scale: CGFloat = 0.5
        let small = luminance.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        guard let cg = context.createCGImage(small, from: small.extent) else { return luminance }
        var src = vImage_Buffer()
        var fmt = vImage_CGImageFormat(bitsPerComponent: 8, bitsPerPixel: 32, colorSpace: nil, bitmapInfo: CGBitmapInfo.byteOrder32Big.union(.premultipliedLast), version: 0, decode: nil, renderingIntent: .defaultIntent)
        defer { free(src.data) }
        var error = vImageBuffer_InitWithCGImage(&src, &fmt, nil, cg, vImage_Flags(kvImageNoFlags))
        if error != kvImageNoError { return luminance }
        vImageEqualization_ARGB8888(&src, &src, vImage_Flags(kvImageNoFlags))
        guard let outCG = vImageCreateCGImageFromBuffer(&src, &fmt, nil, nil, vImage_Flags(kvImageNoAllocate), &error)?.takeRetainedValue(), error == kvImageNoError else { return luminance }
        let out = CIImage(cgImage: outCG).transformed(by: CGAffineTransform(scaleX: 1/scale, y: 1/scale)).cropped(to: luminance.extent)
        return out
    }
}


