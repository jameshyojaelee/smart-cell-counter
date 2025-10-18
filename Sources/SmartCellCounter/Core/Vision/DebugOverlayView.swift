import Foundation
import SwiftUI
import CoreImage

struct DebugOverlayView: View {
    let debugImages: [String: UIImage]
    let kind: String
    var body: some View {
        if let img = pick() {
            Image(uiImage: img).resizable().scaledToFit().opacity(0.65)
        }
    }
    private func pick() -> UIImage? {
        switch kind {
        case "Blue Mask": return debugImages["08_blue_mask"]
        case "Grid Mask": return debugImages["05_grid_mask"]
        case "Illumination": return debugImages["03_illumination"]
        default: return debugImages["07_candidates"]
        }
    }
}


