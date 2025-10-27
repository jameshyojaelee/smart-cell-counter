import CoreImage
import Foundation
import Metal

public enum ImageContext {
    public static let device: MTLDevice? = MTLCreateSystemDefaultDevice()
    public static let ciContext: CIContext = if let device {
        .init(mtlDevice: device, options: [
            .cacheIntermediates: true,
            .useSoftwareRenderer: false
        ])
    } else {
        .init(options: [
            .cacheIntermediates: true,
            .useSoftwareRenderer: false
        ])
    }
}
