import Foundation
import SwiftUI
import CoreImage

struct DebugOverlayView: View {
    let debugImages: [String: UIImage]
    let kind: String
    let segmentation: SegmentationResult?

    var body: some View {
        switch kind {
        case "Segmentation Info":
            if let seg = segmentation {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Segmentation")
                        .font(.headline)
                    Text("Strategy: \(seg.usedStrategy.rawValue.capitalized)")
                    Text(String(format: "Downscale: %.2fx", seg.downscaleFactor))
                    Text("Polarity inverted: \(seg.polarityInverted ? "Yes" : "No")")
                    Text("Resolution: \(seg.width)×\(seg.height) → \(Int(seg.originalSize.width))×\(Int(seg.originalSize.height))")
                }
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            }
        default:
            if let img = pickImage() {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.65)
            }
        }
    }

    private func pickImage() -> UIImage? {
        switch kind {
        case "Blue Mask": return debugImages["08_blue_mask"]
        case "Grid Mask": return debugImages["05_grid_mask"]
        case "Illumination": return debugImages["03_illumination"]
        case "Segmentation Mask": return debugImages["00_segmentation_mask"]
        default: return debugImages["07_candidates"]
        }
    }
}

