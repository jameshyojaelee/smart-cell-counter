import UIKit
import AVFoundation
@testable import SmartCellCounter

enum TestFixtures {
    enum Error: Swift.Error {
        case pixelBufferCreation
        case sampleBufferCreation
        case ciImageCreation
    }

    static func solidImage(color: UIColor, size: CGSize = CGSize(width: 32, height: 32)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            color.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
        }
    }

    static func circleImage(size: CGSize, circleRect: CGRect, fill: UIColor, background: UIColor = .white) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            background.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            fill.setFill()
            ctx.cgContext.fillEllipse(in: circleRect)
        }
    }

    static func constantCIImage(value: CGFloat, size: CGSize) -> CIImage {
        let rect = CGRect(origin: .zero, size: size)
        return CIImage(color: CIColor(red: value, green: value, blue: value, alpha: 1)).cropped(to: rect)
    }

    static func ciImage(from image: UIImage) throws -> CIImage {
        guard let ciImage = CIImage(image: image) else { throw Error.ciImageCreation }
        return ciImage
    }

    static func maskCIImage(size: CGSize, highlighted points: [CGPoint]) throws -> CIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        let img = renderer.image { ctx in
            UIColor.black.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            UIColor.white.setFill()
            for point in points {
                let y = size.height - point.y - 1
                ctx.fill(CGRect(x: point.x, y: y, width: 2, height: 2))
            }
        }
        return try ciImage(from: img)
    }

    static func sampleBuffer(width: Int, height: Int, color: UIColor) throws -> CMSampleBuffer {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [CFString: Any] = [
            kCVPixelBufferCGImageCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true
        ]
        let status = CVPixelBufferCreate(kCFAllocatorDefault,
                                         width,
                                         height,
                                         kCVPixelFormatType_32BGRA,
                                         attrs as CFDictionary,
                                         &pixelBuffer)
        guard status == kCVReturnSuccess, let pb = pixelBuffer else { throw Error.pixelBufferCreation }

        CVPixelBufferLockBaseAddress(pb, [])
        defer { CVPixelBufferUnlockBaseAddress(pb, []) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(pb) else { throw Error.pixelBufferCreation }
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pb)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        let red = UInt8(r * 255)
        let green = UInt8(g * 255)
        let blue = UInt8(b * 255)
        let alpha = UInt8(a * 255)

        for y in 0..<height {
            var pointer = baseAddress.advanced(by: y * bytesPerRow).bindMemory(to: UInt8.self, capacity: width * 4)
            for _ in 0..<width {
                pointer[0] = blue
                pointer[1] = green
                pointer[2] = red
                pointer[3] = alpha
                pointer = pointer.advanced(by: 4)
            }
        }

        var format: CMFormatDescription?
        guard CMVideoFormatDescriptionCreateForImageBuffer(allocator: kCFAllocatorDefault, imageBuffer: pb, formatDescriptionOut: &format) == noErr,
              let formatDescription = format else {
            throw Error.sampleBufferCreation
        }

        var timing = CMSampleTimingInfo(duration: .invalid,
                                        presentationTimeStamp: .zero,
                                        decodeTimeStamp: .invalid)
        var sampleBuffer: CMSampleBuffer?
        let createStatus = CMSampleBufferCreateReadyWithImageBuffer(allocator: kCFAllocatorDefault,
                                                                    imageBuffer: pb,
                                                                    formatDescription: formatDescription,
                                                                    sampleTiming: &timing,
                                                                    sampleBufferOut: &sampleBuffer)
        guard createStatus == noErr, let buffer = sampleBuffer else { throw Error.sampleBufferCreation }
        return buffer
    }

    static func cellObject(id: Int, centroid: CGPoint, pixelCount: Int = 12) -> CellObject {
        CellObject(id: id,
                   pixelCount: pixelCount,
                   areaPx: Double(pixelCount),
                   perimeterPx: Double(pixelCount),
                   circularity: 0.9,
                   solidity: 0.95,
                   centroid: centroid,
                   bbox: CGRect(x: centroid.x - 1, y: centroid.y - 1, width: 2, height: 2))
    }
}
