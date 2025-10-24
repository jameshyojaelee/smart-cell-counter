import Foundation
import CoreImage
import UIKit

enum ColorSpaces {
    static func linearLuminance(_ image: CIImage) -> CIImage {
        let linear = image.applyingFilter("CIGammaAdjust", parameters: ["inputPower": 2.2])
        let lumaKernel = "kernel vec4 luma(__sample s) { float y = dot(s.rgb, vec3(0.2126, 0.7152, 0.0722)); return vec4(y,y,y,1.0); }"
        guard let k = CIColorKernel(source: lumaKernel), let out = k.apply(extent: image.extent, arguments: [linear]) else { return linear }
        return out
    }

    static func hsvImage(_ image: CIImage) -> HSVImage {
        let kernel = """
        kernel vec4 rgb2hsv(__sample s) {
            float r = s.r, g = s.g, b = s.b;
            float maxv = max(max(r,g), b);
            float minv = min(min(r,g), b);
            float d = maxv - minv;
            float h = 0.0;
            if (d != 0.0) {
                if (maxv == r) { h = mod((g - b) / d, 6.0); }
                else if (maxv == g) { h = ((b - r) / d) + 2.0; }
                else { h = ((r - g) / d) + 4.0; }
                h = h / 6.0; if (h < 0.0) h += 1.0;
            }
            float s2 = maxv == 0.0 ? 0.0 : d / maxv;
            return vec4(h, s2, maxv, 1.0);
        }
        """
        guard let k = CIColorKernel(source: kernel), let hsv = k.apply(extent: image.extent, arguments: [image]) else {
            return HSVImage(h: image, s: image, value: image)
        }
        let h = hsv.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
                                                                 "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                                                                 "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)])
        let s = hsv.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0, y: 1, z: 0, w: 0),
                                                                 "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                                                                 "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)])
        let v = hsv.applyingFilter("CIColorMatrix", parameters: ["inputRVector": CIVector(x: 0, y: 0, z: 1, w: 0),
                                                                 "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
                                                                 "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0)])
        return HSVImage(h: h, s: s, value: v)
    }

    static func sampleHSVLab(ci: CIImage, at p: CGPoint, context: CIContext) -> ColorSampleStats {
        let r = CGRect(x: p.x-2, y: p.y-2, width: 5, height: 5)
        guard let cg = context.createCGImage(ci, from: r) else { return ColorSampleStats(hue: 0, saturation: 0, value: 0, L: 0, a: 0, b: 0) }
        guard let data = cg.dataProvider?.data as Data? else { return ColorSampleStats(hue: 0, saturation: 0, value: 0, L: 0, a: 0, b: 0) }
        var sumR=0.0, sumG=0.0, sumB=0.0, count=0.0
        let w = cg.width, h = cg.height, stride = cg.bytesPerRow
        data.withUnsafeBytes { (ptr: UnsafeRawBufferPointer) in
            let p0 = ptr.bindMemory(to: UInt8.self).baseAddress!
            for y in 0..<h {
                let line = p0 + y*stride
                for x in 0..<w {
                    let idx = x*4
                    sumR += Double(line[idx]) / 255.0
                    sumG += Double(line[idx+1]) / 255.0
                    sumB += Double(line[idx+2]) / 255.0
                    count += 1
                }
            }
        }
        let R = sumR/count, G = sumG/count, B = sumB/count
        let (hsvH, hsvS, hsvV) = ImagingPipeline.rgbToHsv(R, G, B)
        let (L, a, b) = ImagingPipeline.rgbToLab(R, G, B)
        return ColorSampleStats(hue: hsvH, saturation: hsvS, value: hsvV, L: L, a: a, b: b)
    }
}
