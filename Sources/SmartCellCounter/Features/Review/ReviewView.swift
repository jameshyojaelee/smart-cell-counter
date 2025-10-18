import SwiftUI
import CoreGraphics
import UIKit

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
        Task.detached(priority: .userInitiated) {
            let start = Date()
            let settings = await MainActor.run { SettingsStore.shared }
            let detectionParams = await MainActor.run { DetectorParams.from(settings) }
            let imagingParams = await MainActor.run { ImagingParams.from(settings) }
            let segmentation = ImagingPipeline.segmentCells(in: image, params: imagingParams)
            let pxPerMicronSnapshot = await MainActor.run { appState.pxPerMicron }
            let det = CellDetector.detect(on: image, roi: nil, pxPerMicron: pxPerMicronSnapshot, params: detectionParams)
            let pxPerMicron = det.pxPerMicron ?? min(Double(image.size.width)/3000.0, Double(image.size.height)/3000.0)
            let geom = GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron)
            let tally = CountingService.tallyByLargeSquare(objects: det.objects, geometry: geom)
            let ms = Date().timeIntervalSince(start) * 1000
            PerformanceLogger.shared.record("pipelineTotal", ms)

            var debugImages = det.debugImages

            await MainActor.run {
                if let mask = Self.makeSegmentationPreview(segmentation) {
                    debugImages["00_segmentation_mask"] = mask
                }
                appState.segmentation = segmentation
                appState.objects = det.objects
                appState.labeled = det.labeled
                appState.pxPerMicron = pxPerMicron
                appState.debugImages = debugImages
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

    @MainActor
    private static func makeSegmentationPreview(_ seg: SegmentationResult) -> UIImage? {
        guard seg.width > 0, seg.height > 0 else { return nil }
        let size = CGSize(width: seg.width, height: seg.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.setFillColor(UIColor.systemPink.withAlphaComponent(0.45).cgColor)
            for idx in 0..<seg.mask.count where seg.mask[idx] {
                let x = idx % seg.width
                let y = idx / seg.width
                ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
            }
        }
    }
}

struct ReviewView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ReviewViewModel()
    @State private var goToResults = false
    @State private var drawingLasso = false
    @State private var filter: String = "All" // All, Live, Dead
    @State private var showOverlays = false
    @State private var overlayKind = "Candidates" // Candidates, Blue Mask, Grid Mask, Illumination, Segmentation Mask, Segmentation Info

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                if let img = appState.correctedImage ?? appState.capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .overlay(DetectionOverlay(labeled: filteredLabeled()) { id in
                            viewModel.toggleLabel(for: id, in: appState)
                            Haptics.impact(.light)
                        })
                        .overlay(alignment: .topTrailing) {
                            Menu {
                                Toggle("Show Overlays", isOn: $showOverlays)
                                Picker("Overlay", selection: $overlayKind) {
                                    Text("Candidates").tag("Candidates")
                                    Text("Blue Mask").tag("Blue Mask")
                                    Text("Grid Mask").tag("Grid Mask")
                                    Text("Illumination").tag("Illumination")
                                    Text("Segmentation Mask").tag("Segmentation Mask")
                                    Text("Segmentation Info").tag("Segmentation Info")
                                }
                            } label: {
                                Image(systemName: "eye").padding(8)
                            }
                        }
                        .overlay {
                            if showOverlays {
                                DebugOverlayView(debugImages: appState.debugImages,
                                                 kind: overlayKind,
                                                 segmentation: appState.segmentation)
                            }
                        }
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
                    .frame(maxHeight: 140)
                    .cardStyle()
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

            Picker("Filter", selection: $filter) {
                Text("All").tag("All")
                Text("Live").tag("Live")
                Text("Dead").tag("Dead")
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)
        }
        .navigationTitle("Review")
        .onAppear {
            if appState.labeled.isEmpty, let img = appState.correctedImage ?? appState.capturedImage {
                viewModel.recompute(on: img, appState: appState)
            }
        }
        .modifier(ReviewNavigation(goToResults: $goToResults))
        .appBackground()
    }

    private func filteredLabeled() -> [CellObjectLabeled] {
        switch filter {
        case "Live": return appState.labeled.filter { $0.label == "live" }
        case "Dead": return appState.labeled.filter { $0.label == "dead" }
        default: return appState.labeled
        }
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

// MARK: - Navigation modernization
private struct ReviewNavigation: ViewModifier {
    @Binding var goToResults: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .navigationDestination(isPresented: $goToResults) { ResultsView() }
        } else {
            content
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: ResultsView(), isActive: $goToResults) { EmptyView() }
                    }
                }
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Per-Square Counts").font(.headline).foregroundColor(Theme.textPrimary)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                ForEach(0..<9) { i in
                    let count = tally[i] ?? 0
                    ZStack {
                        RoundedRectangle(cornerRadius: 8).fill(Theme.surface)
                        Text("\(count)").foregroundColor(Theme.textPrimary)
                    }
                    .frame(height: 36)
                }
            }
        }
    }
}
