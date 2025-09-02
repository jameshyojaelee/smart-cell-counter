import SwiftUI

struct HelpView: View {
    @StateObject private var viewModel = HelpViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Counting Rules").font(.title2)
                Text("Include top and left borders; exclude bottom and right. Count only centroids within included boundaries.")
                InclusionDiagram().frame(height: 180)
                Text("Tips").font(.title2)
                Text("• Ensure good focus and even lighting.\n• Avoid glare; tilt the plate slightly if needed.\n• Use 4 corner squares by default; exclude outliers if debris present.")
            }
            .padding()
        }
        .navigationTitle("Help")
    }
}

private struct InclusionDiagram: View {
    var body: some View {
        GeometryReader { geo in
            let rect = geo.frame(in: .local)
            let step = min(rect.width, rect.height)/3
            Path { p in
                for i in 0...3 {
                    p.move(to: CGPoint(x: rect.minX + CGFloat(i)*step, y: rect.minY))
                    p.addLine(to: CGPoint(x: rect.minX + CGFloat(i)*step, y: rect.minY + 3*step))
                    p.move(to: CGPoint(x: rect.minX, y: rect.minY + CGFloat(i)*step))
                    p.addLine(to: CGPoint(x: rect.minX + 3*step, y: rect.minY + CGFloat(i)*step))
                }
            }.stroke(Color.gray)
            // Highlight inclusion edges
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 3*step))
            }.stroke(Color.green, lineWidth: 3)
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX + 3*step, y: rect.minY))
            }.stroke(Color.green, lineWidth: 3)
            Path { p in
                p.move(to: CGPoint(x: rect.minX + 3*step, y: rect.minY))
                p.addLine(to: CGPoint(x: rect.minX + 3*step, y: rect.minY + 3*step))
            }.stroke(Color.red, lineWidth: 3)
            Path { p in
                p.move(to: CGPoint(x: rect.minX, y: rect.minY + 3*step))
                p.addLine(to: CGPoint(x: rect.minX + 3*step, y: rect.minY + 3*step))
            }.stroke(Color.red, lineWidth: 3)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

final class HelpViewModel: ObservableObject {}
