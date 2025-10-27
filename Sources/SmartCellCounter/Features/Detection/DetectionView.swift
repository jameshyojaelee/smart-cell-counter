import SwiftUI

struct DetectionView: View {
    @EnvironmentObject private var appState: AppState
    @State private var showOverlays = true
    @State private var overlayKind: DetectionOverlayKind = .candidates

    var body: some View {
        VStack {
            if let img = appState.correctedImage ?? appState.capturedImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .flipsForRightToLeftLayoutDirection(false)
                    .overlay(
                        DebugOverlayView(debugImages: appState.debugImages,
                                         kind: overlayKind,
                                         segmentation: appState.segmentation)
                            .opacity(showOverlays ? 1 : 0)
                    )
                    .accessibilityHidden(true)
                HStack {
                    Toggle(L10n.Detection.toggleLabel, isOn: $showOverlays)
                        .toggleStyle(.switch)
                        .accessibilityHint(L10n.Detection.toggleHint)
                        .accessibilityValue(L10n.Detection.toggleValue(isVisible: showOverlays))

                    Picker(L10n.Detection.pickerLabel, selection: $overlayKind) {
                        ForEach(DetectionOverlayKind.allCases) { kind in
                            Text(kind.displayName).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)
                    .accessibilityHint(L10n.Detection.toggleHint)
                }
                .padding()
            } else {
                Text(L10n.Detection.emptyState).foregroundColor(.secondary)
            }
        }
        .navigationTitle(L10n.Detection.navigationTitle)
    }
}

enum DetectionOverlayKind: String, CaseIterable, Identifiable {
    case candidates
    case blueMask
    case gridMask
    case illumination
    case segmentationMask
    case segmentationInfo

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .candidates: L10n.Detection.Overlay.candidates
        case .blueMask: L10n.Detection.Overlay.blueMask
        case .gridMask: L10n.Detection.Overlay.gridMask
        case .illumination: L10n.Detection.Overlay.illumination
        case .segmentationMask: L10n.Detection.Overlay.segmentationMask
        case .segmentationInfo: L10n.Detection.Overlay.segmentationInfo
        }
    }
}
