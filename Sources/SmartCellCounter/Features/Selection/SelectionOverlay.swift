import SwiftUI

struct SelectionOverlay: View {
    @Binding var rect: CGRect // in view space
    let bounds: CGRect
    let minSize: CGSize
    let fixedAspect: CGFloat? // width/height if provided

    @State private var dragOffset: CGSize = .zero
    @State private var activeHandle: Int? = nil // 0..3 tl,tr,br,bl
    @State private var startRect: CGRect? = nil
    @State private var history: [CGRect] = []

    var body: some View {
        ZStack {
            // Main rectangle
            Path { p in p.addRoundedRect(in: rect, cornerSize: CGSize(width: 8, height: 8)) }
                .stroke(Theme.accent, lineWidth: 2)
                .background(Color.clear)
                .contentShape(Rectangle())
                .gesture(dragGesture())
                .accessibilityLabel(L10n.Selection.overlayLabel)
                .accessibilityHint(L10n.Selection.overlayHint)
                .accessibilityValue(L10n.Selection.areaValue(width: rect.width, height: rect.height))
            // Handles
            ForEach(0..<4) { i in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 18, height: 18)
                    .position(handlePosition(i))
                    .contentShape(Rectangle().inset(by: -10)) // hit-test expansion
                    .gesture(resizeGesture(i))
                    .accessibilityLabel(L10n.Selection.handleLabel)
            }

            // Undo button near top-left of the selection
            if !history.isEmpty {
                Button(action: undo) {
                    Image(systemName: "arrow.uturn.left")
                        .font(.system(size: 14, weight: .medium))
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
                .position(undoButtonPosition())
                .accessibilityLabel(L10n.Selection.undoLabel)
                .accessibilityHint(L10n.Selection.undoHint)
            }
        }
        .flipsForRightToLeftLayoutDirection(false)
    }

    private func handlePosition(_ i: Int) -> CGPoint {
        switch i {
        case 0: return CGPoint(x: rect.minX, y: rect.minY)
        case 1: return CGPoint(x: rect.maxX, y: rect.minY)
        case 2: return CGPoint(x: rect.maxX, y: rect.maxY)
        default: return CGPoint(x: rect.minX, y: rect.maxY)
        }
    }

    private func dragGesture() -> some Gesture {
        DragGesture()
            .onChanged { g in
                if startRect == nil { startRect = rect }
                var r = rect
                r.origin.x += g.translation.width
                r.origin.y += g.translation.height
                r = GeometryUtils.clamp(r, to: bounds)
                if r.width < minSize.width || r.height < minSize.height { return }
                rect = r
            }
            .onEnded { _ in
                if let start = startRect, start != rect { history.append(start) }
                startRect = nil
            }
    }

    private func resizeGesture(_ index: Int) -> some Gesture {
        DragGesture()
            .onChanged { g in
                if startRect == nil { startRect = rect }
                var r = rect
                switch index {
                case 0: // TL
                    r.origin.x += g.translation.width
                    r.origin.y += g.translation.height
                    r.size.width -= g.translation.width
                    r.size.height -= g.translation.height
                case 1: // TR
                    r.origin.y += g.translation.height
                    r.size.width += g.translation.width
                    r.size.height -= g.translation.height
                case 2: // BR
                    r.size.width += g.translation.width
                    r.size.height += g.translation.height
                case 3: // BL
                    r.origin.x += g.translation.width
                    r.size.width -= g.translation.width
                    r.size.height += g.translation.height
                default: break
                }
                if let aspect = fixedAspect {
                    // enforce aspect by adjusting height based on width
                    r.size.height = r.size.width / aspect
                }
                if r.size.width < minSize.width { r.size.width = minSize.width }
                if r.size.height < minSize.height { r.size.height = minSize.height }
                r = GeometryUtils.clamp(r, to: bounds)
                rect = r
            }
            .onEnded { _ in
                if let start = startRect, start != rect { history.append(start) }
                startRect = nil
            }
    }

    private func undo() {
        guard let prev = history.popLast() else { return }
        rect = GeometryUtils.clamp(prev, to: bounds)
    }

    private func undoButtonPosition() -> CGPoint {
        // Place slightly above top-left corner, clamped within bounds
        let x = max(bounds.minX + 16, min(rect.minX, bounds.maxX - 16))
        let y = max(bounds.minY + 16, min(rect.minY - 20, bounds.maxY - 16))
        return CGPoint(x: x, y: y)
    }
}
