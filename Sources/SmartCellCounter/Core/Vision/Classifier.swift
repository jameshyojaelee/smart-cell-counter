import Foundation
import CoreImage

public struct LabeledCandidate {
    public let center: CGPoint
    public let radius: CGFloat
    public let label: String // "live" or "dead"
    public let confidence: Double
}

enum Classifier {
    static func classify(candidates: [Candidate],
                         hsv: HSVImage,
                         blueMask: CIImage,
                         gridMask: CIImage,
                         eqLuma: CIImage,
                         context: CIContext,
                         params: DetectorParams) -> [LabeledCandidate] {
        var out: [LabeledCandidate] = []
        for c in candidates {
            let pt = c.center
            let isBlue = MaskUtils.isMasked(blueMask, at: pt, context: context)
            let brightBlob = c.score
            var label = "live"
            var conf = 0.0

            if isBlue {
                label = "dead"
                conf = min(1.0, 0.6 + 0.4 * brightBlob)
            } else if brightBlob >= params.blobScoreThreshold {
                label = "live"
                conf = min(1.0, brightBlob)
            } else {
                continue
            }
            out.append(LabeledCandidate(center: pt, radius: c.radius, label: label, confidence: conf))
        }

        if TinyMLClassifier.isEnabled {
            // Optional refinement stub
        }

        return out
    }
}

enum TinyMLClassifier {
    static var isEnabled: Bool { false }
}
