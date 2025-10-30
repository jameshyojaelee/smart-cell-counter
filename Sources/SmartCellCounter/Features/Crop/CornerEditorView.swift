import CoreGraphics
import SwiftUI

struct CornerEditorView: View {
    @Binding var image: UIImage
    @Binding var corners: [CGPoint] // TL, TR, BR, BL
    @State private var scale: CGFloat = 1
    @State private var offset: CGSize = .zero
    private let handleSize: CGFloat = 28

    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            ZStack {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .scaleEffect(scale)
                    .offset(offset)
                    .gesture(magnification)
                    .gesture(pan)

                Path { path in
                    guard corners.count == 4 else { return }
                    let pts = transformedCorners(rect: rect)
                    path.move(to: pts[0])
                    path.addLines([pts[1], pts[2], pts[3], pts[0]])
                }
                .stroke(Color.yellow, lineWidth: 2)

                ForEach(0 ..< 4, id: \.self) { i in
                    Handle(position: transformedCorners(rect: rect)[i], size: handleSize)
                        .gesture(dragHandle(index: i, rect: rect))
                }
            }
            .contentShape(Rectangle())
            .clipped()
        }
    }

    private func transformedCorners(rect: CGRect) -> [CGPoint] {
        // Map image-space corners through scale/offset into view space
        let imgSize = fittedImageSize(in: rect, image: image)
        let origin = CGPoint(x: rect.midX - imgSize.width / 2 + offset.width, y: rect.midY - imgSize.height / 2 + offset.height)
        func map(_ p: CGPoint) -> CGPoint {
            let x = origin.x + p.x * (imgSize.width / image.size.width) * scale
            let y = origin.y + p.y * (imgSize.height / image.size.height) * scale
            return CGPoint(x: x, y: y)
        }
        return corners.map(map)
    }

    private var magnification: some Gesture {
        MagnificationGesture().onChanged { value in
            scale = max(0.5, min(4.0, value))
        }
    }

    private var pan: some Gesture {
        DragGesture().onChanged { g in
            offset = g.translation
        }
        .onEnded { _ in }
    }

    private func dragHandle(index: Int, rect: CGRect) -> some Gesture {
        DragGesture()
            .onChanged { g in
                var new = corners
                // Convert drag in view space back to image space
                let imgSize = fittedImageSize(in: rect, image: image)
                let sx = (image.size.width / imgSize.width) / scale
                let sy = (image.size.height / imgSize.height) / scale
                new[index].x += g.translation.width * sx
                new[index].y += g.translation.height * sy
                new[index].x = min(max(0, new[index].x), image.size.width)
                new[index].y = min(max(0, new[index].y), image.size.height)
                // Snap: align x or y with adjacent points if within threshold
                let th: CGFloat = 6
                let adj = [(3, 1), (0, 2), (1, 3), (2, 0)][index]
                if abs(new[index].x - new[adj.0].x) < th { new[index].x = new[adj.0].x }
                if abs(new[index].x - new[adj.1].x) < th { new[index].x = new[adj.1].x }
                if abs(new[index].y - new[adj.0].y) < th { new[index].y = new[adj.0].y }
                if abs(new[index].y - new[adj.1].y) < th { new[index].y = new[adj.1].y }
                // Prevent self intersection by enforcing ordering TL,TR,BR,BL
                corners = enforceOrdering(points: new)
            }
    }

    private func enforceOrdering(points: [CGPoint]) -> [CGPoint] {
        guard points.count == 4 else { return points }
        // Sort by y then x to find approximate TL, TR, BR, BL
        let sorted = points.sorted { a, b in a.y == b.y ? a.x < b.x : a.y < b.y }
        let top = Array(sorted.prefix(2)).sorted { $0.x < $1.x }
        let bottom = Array(sorted.suffix(2)).sorted { $0.x < $1.x }
        return [top[0], top[1], bottom[1], bottom[0]]
    }

    private func fittedImageSize(in rect: CGRect, image: UIImage) -> CGSize {
        let ar = image.size.width / image.size.height
        let rw = rect.width
        let rh = rect.height
        if rw / rh > ar {
            let h = rh
            return CGSize(width: h * ar, height: h)
        } else {
            let w = rw
            return CGSize(width: w, height: w / ar)
        }
    }
}

private struct Handle: View {
    let position: CGPoint
    let size: CGFloat
    var body: some View {
        Circle()
            .fill(.blue.opacity(0.8))
            .frame(width: size, height: size)
            .position(position)
            .shadow(radius: 2)
    }
}
