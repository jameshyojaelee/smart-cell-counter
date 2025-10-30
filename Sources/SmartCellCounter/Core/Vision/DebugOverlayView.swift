import CoreImage
import Foundation
import SwiftUI

struct DebugOverlayView: View {
    let debugImages: [String: UIImage]
    let kind: DetectionOverlayKind
    let segmentation: SegmentationResult?

    var body: some View {
        switch kind {
        case .segmentationInfo:
            if let seg = segmentation {
                segmentationInfoView(seg)
            }
        default:
            if let img = pickImage(for: kind) {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.65)
                    .accessibilityHidden(true)
                    .flipsForRightToLeftLayoutDirection(false)
            }
        }
    }

    @ViewBuilder
    private func segmentationInfoView(_ seg: SegmentationResult) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L10n.Detection.Segmentation.heading)
                .font(.headline)
            Text(L10n.Detection.Segmentation.strategy(seg.usedStrategy.localizedName))
            Text(L10n.Detection.Segmentation.downscale(seg.downscaleFactor))
            Text(L10n.Detection.Segmentation.polarity(seg.polarityInverted))
            Text(
                L10n.Detection.Segmentation.resolution(
                    width: seg.width,
                    height: seg.height,
                    originalWidth: Int(seg.originalSize.width),
                    originalHeight: Int(seg.originalSize.height)
                )
            )
        }
        .padding(8)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Detection.Overlay.segmentationInfo)
    }

    private func pickImage(for kind: DetectionOverlayKind) -> UIImage? {
        switch kind {
        case .blueMask: debugImages["08_blue_mask"]
        case .gridMask: debugImages["05_grid_mask"]
        case .illumination: debugImages["03_illumination"]
        case .segmentationMask: debugImages["00_segmentation_mask"]
        case .candidates: debugImages["07_candidates"]
        case .segmentationInfo: nil
        }
    }
}

private extension SegmentationStrategy {
    var localizedName: String {
        switch self {
        case .automatic: L10n.Settings.SegmentationStrategy.automatic
        case .classical: L10n.Settings.SegmentationStrategy.classical
        case .coreML: L10n.Settings.SegmentationStrategy.coreML
        }
    }
}
