import Foundation
import CoreImage
import Metal

public enum ImageContext {
    public static let device: MTLDevice? = MTLCreateSystemDefaultDevice()
    public static let ciContext: CIContext = {
        if let device = device {
            return CIContext(mtlDevice: device, options: [
                .cacheIntermediates: true,
                .useSoftwareRenderer: false
            ])
        } else {
            return CIContext(options: [
                .cacheIntermediates: true,
                .useSoftwareRenderer: false
            ])
        }
    }()
}

