import CoreGraphics
import UIKit

public enum GeometryUtils {
    public static func clamp(_ rect: CGRect, to bounds: CGRect) -> CGRect {
        var r = rect
        if r.width > bounds.width { r.size.width = bounds.width }
        if r.height > bounds.height { r.size.height = bounds.height }
        if r.minX < bounds.minX { r.origin.x = bounds.minX }
        if r.minY < bounds.minY { r.origin.y = bounds.minY }
        if r.maxX > bounds.maxX { r.origin.x = bounds.maxX - r.width }
        if r.maxY > bounds.maxY { r.origin.y = bounds.maxY - r.height }
        return r
    }

    public static func scale(rect: CGRect, from src: CGSize, to dst: CGSize) -> CGRect {
        let sx = dst.width / src.width
        let sy = dst.height / src.height
        return CGRect(x: rect.origin.x * sx,
                      y: rect.origin.y * sy,
                      width: rect.size.width * sx,
                      height: rect.size.height * sy)
    }

    public static func crop(image: UIImage, to rect: CGRect) -> UIImage? {
        guard let cg = image.cgImage else { return nil }
        let scaleRect = CGRect(x: rect.origin.x * image.scale,
                               y: rect.origin.y * image.scale,
                               width: rect.size.width * image.scale,
                               height: rect.size.height * image.scale).integral
        guard let cropped = cg.cropping(to: scaleRect) else { return nil }
        return UIImage(cgImage: cropped, scale: image.scale, orientation: image.imageOrientation)
    }
}
