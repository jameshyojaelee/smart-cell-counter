import Foundation
import CoreGraphics

enum NMS {
    static func suppress(_ items: [LabeledCandidate], iou: Double) -> [LabeledCandidate] {
        var sorted = items.sorted(by: { $0.confidence > $1.confidence })
        var kept: [LabeledCandidate] = []
        while !sorted.isEmpty {
            let best = sorted.removeFirst()
            kept.append(best)
            sorted.removeAll { cand in
                overlap(best, cand) > iou
            }
        }
        return kept
    }

    private static func overlap(_ a: LabeledCandidate, _ b: LabeledCandidate) -> Double {
        let ra = a.radius, rb = b.radius
        let d = hypot(a.center.x - b.center.x, a.center.y - b.center.y)
        if d >= ra + rb { return 0 }
        if d <= abs(ra - rb) {
            let minArea = Double.pi * Double(min(ra, rb) * min(ra, rb))
            let maxArea = Double.pi * Double(max(ra, rb) * max(ra, rb))
            return minArea / maxArea
        }
        let ra2 = ra*ra, rb2 = rb*rb
        let alpha = acos((ra2 + d*d - rb2) / (2*ra*d))
        let beta = acos((rb2 + d*d - ra2) / (2*rb*d))
        let inter = ra2*alpha + rb2*beta - 0.5*sqrt(max(0, (-d+ra+rb)*(d+ra-rb)*(d-ra+rb)*(d+ra+rb)))
        let union = Double.pi*Double(ra2 + rb2) - Double(inter)
        return Double(inter) / union
    }
}
