import SwiftUI
import CoreGraphics

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var overlayPaths: [Int: Path] = [:] // selection per object id
    @Published var lassoPath: Path = Path()
    @Published var showDead: Set<Int> = [] // ids toggled to dead
    @Published var perSquare: [Int: Int] = [:]
    @Published var selectedLarge: [Int] = [0,2,6,8]
    @Published var isComputing = false
    @Published var lastDurationMs: Double = 0

    func recompute(on image: UIImage, appState: AppState) {
        isComputing = true
        Task.detached {
            let start = Date()
            let params = ImagingParams()
            let seg = ImagingPipeline.segmentCells(in: image, params: params)
            let objects = ImagingPipeline.objectFeatures(from: seg, pxPerMicron: nil)
            let labeled = ImagingPipeline.colorStatsAndLabels(for: objects, on: image)
            let pxPerMicron = min(Double(image.size.width)/3000.0, Double(image.size.height)/3000.0)
            let geom = GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron)
            let tally = CountingService.tallyByLargeSquare(objects: objects, geometry: geom)
            let ms = Date().timeIntervalSince(start) * 1000
            PerformanceLogger.shared.record("pipelineTotal", ms)
            await MainActor.run {
                appState.segmentation = seg
                appState.objects = objects
                appState.labeled = labeled
                appState.pxPerMicron = pxPerMicron
                self.perSquare = tally
                self.lastDurationMs = ms
                self.isComputing = false
            }
        }
    }

    func toggleLabel(for id: Int, in appState: AppState) {
        if let idx = appState.labeled.firstIndex(where: { $0.id == id }) {
            let cur = appState.labeled[idx]
            let newLabel = cur.label == "dead" ? "live" : "dead"
            appState.labeled[idx] = CellObjectLabeled(id: cur.id, base: cur.base, color: cur.color, label: newLabel, confidence: cur.confidence)
        }
    }

    func applyLassoErase(in appState: AppState) {
        let path = lassoPath
        appState.labeled.removeAll { obj in
            path.contains(obj.base.centroid)
        }
        lassoPath = Path()
    }
}

struct ReviewView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ReviewViewModel()
    @State private var goToResults = false
    @State private var drawingLasso = false

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                if let img = appState.correctedImage ?? appState.capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .overlay(DetectionOverlay(labeled: appState.labeled) { id in viewModel.toggleLabel(for: id, in: appState) })
                        .gesture(lassoGesture())
                } else {
                    Text("No image to review.").foregroundColor(.secondary)
                }
            }
            .overlay(alignment: .topLeading) {
                if viewModel.isComputing { ProgressView("Computing...") }
            }

            if !viewModel.perSquare.isEmpty {
                PerSquareTable(tally: viewModel.perSquare)
                    .frame(maxHeight: 120)
            }

            HStack {
                Button("Recompute") {
                    if let img = appState.correctedImage ?? appState.capturedImage { viewModel.recompute(on: img, appState: appState) }
                }
                Spacer()
                Button("Next") { goToResults = true }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
        }
        .navigationTitle("Review")
        .onAppear {
            if appState.labeled.isEmpty, let img = appState.correctedImage ?? appState.capturedImage {
                viewModel.recompute(on: img, appState: appState)
            }
        }
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { NavigationLink(destination: ResultsView(), isActive: $goToResults) { EmptyView() } } }
    }

    private func lassoGesture() -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                drawingLasso = true
                if viewModel.lassoPath.isEmpty { viewModel.lassoPath.move(to: value.location) }
                viewModel.lassoPath.addLine(to: value.location)
            }
            .onEnded { _ in
                drawingLasso = false
                viewModel.applyLassoErase(in: appState)
            }
    }
}

private struct DetectionOverlay: View {
    let labeled: [CellObjectLabeled]
    var onTap: (Int) -> Void
    var body: some View {
        Canvas { ctx, size in
            for item in labeled {
                let c = item.base.centroid
                let r: CGFloat = 6
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r*2, height: r*2)
                let color: Color = item.label == "dead" ? .red : .green
                ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .gesture(TapGesture().onEnded { _ in })
        .overlay( // Transparent buttons for taps near centroids
            ZStack {
                ForEach(labeled, id: \.id) { item in
                    Button(action: { onTap(item.id) }) { Color.clear }
                        .frame(width: 30, height: 30)
                        .position(item.base.centroid)
                }
            }
        )
    }
}

private struct PerSquareTable: View {
    let tally: [Int: Int]
    var body: some View {
        VStack(alignment: .leading) {
            Text("Per-Square Counts").font(.headline)
            HStack {
                ForEach(0..<9) { i in
                    let count = tally[i] ?? 0
                    Text("\(count)")
                        .frame(width: 32, height: 24)
                        .background(Color.gray.opacity(0.1))
                        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.gray.opacity(0.2)))
                }
            }
        }
    }
}
