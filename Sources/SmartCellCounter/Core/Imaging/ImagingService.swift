import Foundation
import Vision
import CoreImage
import CoreImage.CIFilterBuiltins

public protocol GridDetector {
    func detectGridCorners(in image: CIImage) async throws -> [CGPoint]
}

public protocol PerspectiveCorrector {
    func correct(image: CIImage, corners: [CGPoint]) -> CIImage
}

public protocol Segmenter {
    func segmentCells(in image: CIImage) async throws -> CIImage
}

public enum Imaging {}
