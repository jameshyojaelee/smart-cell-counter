import SwiftUI
import UIKit

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var dilution: Double = 1.0
    @Published var exportURL: URL?

    func compute(appState: AppState) -> (conc: Double, live: Int, dead: Int, squares: Int, viability: Double, overcrowded: Bool) {
        let live = appState.labeled.filter { $0.label == "live" }.count
        let dead = appState.labeled.filter { $0.label == "dead" }.count
        let squares = 4
        let pxPerMicron = appState.pxPerMicron ?? 1.0
        let geom = GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron)
        let tally = CountingService.tallyByLargeSquare(objects: appState.objects, geometry: geom)
        let mean = CountingService.meanCountPerLargeSquare(countsByIndex: tally)
        let conc = CountingService.concentrationPerML(meanCountPerLargeSquare: mean, dilutionFactor: dilution)
        let viability = CountingService.viabilityPercent(live: live, dead: dead)
        let overcrowded = mean > 300
        return (conc, live, dead, squares, viability, overcrowded)
    }

    func exportCSV(appState: AppState) {
        let metrics = compute(appState: appState)
        let rows = [["Sample ID","Timestamp","Concentration (cells/mL)","Viability (%)","Live","Dead"],
                    [UUID().uuidString, ISO8601DateFormatter().string(from: Date()),
                     String(format: "%.3e", metrics.conc),
                     String(format: "%.1f", metrics.viability),
                     "\(metrics.live)",
                     "\(metrics.dead)"]]
        let exporter = CSVExporter()
        if let url = try? exporter.export(rows: rows, filename: "results.csv") {
            exportURL = url
        }
    }

    func saveSample(appState: AppState) {
        let id = UUID().uuidString
        let header = ReportHeader(project: Settings.shared.project, operatorName: Settings.shared.operatorName, timestamp: Date())
        let original = appState.capturedImage
        let corrected = appState.correctedImage
        let overlay = corrected.map { PDFExporter.makeOverlayImage(base: $0, labeled: appState.labeled) }

        let pxPerMicron = appState.pxPerMicron ?? 1.0
        let geom = GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron)
        let tally = CountingService.tallyByLargeSquare(objects: appState.objects, geometry: geom)
        let exporter = PDFExporter()
        let params = ImagingParams()

        guard let folder = try? AppDatabase.shared.sampleFolder(id: id) else { return }
        var imagePath: String? = nil
        var maskPath: String? = nil
        var pdfPath: String? = nil
        if let corrected = corrected { imagePath = (try? AppDatabase.shared.save(image: corrected, name: "corrected.png", in: folder))?.path }
        if let seg = appState.segmentation, let maskImage = makeMaskImage(seg) {
            maskPath = (try? AppDatabase.shared.save(image: maskImage, name: "mask.png", in: folder))?.path
        }
        if let pdfURL = try? exporter.exportReport(header: header, images: ReportImages(original: original, corrected: corrected, overlay: overlay), tally: tally, params: params, watermark: true, filename: "report.pdf") { pdfPath = pdfURL.path }

        let m = compute(appState: appState)
        let srec = SampleRecord(id: id,
                                createdAt: Date(),
                                operatorName: Settings.shared.operatorName,
                                project: Settings.shared.project,
                                chamberType: Settings.shared.chamberType,
                                dilutionFactor: dilution,
                                stainType: Settings.shared.stainType,
                                liveTotal: m.live,
                                deadTotal: m.dead,
                                concentrationPerMl: m.conc,
                                viabilityPercent: m.viability,
                                squaresUsed: m.squares,
                                rejectedSquares: "",
                                focusScore: appState.focusScore,
                                glareRatio: appState.glareRatio,
                                pxPerMicron: pxPerMicron,
                                imagePath: imagePath,
                                maskPath: maskPath,
                                pdfPath: pdfPath,
                                notes: nil)

        var dets: [DetectionRecord] = []
        for item in appState.labeled {
            dets.append(DetectionRecord(sampleId: id,
                                        objectId: UUID().uuidString,
                                        x: Double(item.base.centroid.x),
                                        y: Double(item.base.centroid.y),
                                        areaPx: item.base.areaPx,
                                        circularity: item.base.circularity,
                                        solidity: item.base.solidity,
                                        isLive: item.label == "live"))
        }
        try? AppDatabase.shared.insertSample(srec, detections: dets)
    }

    private func makeMaskImage(_ seg: SegmentationResult) -> UIImage? {
        guard seg.width > 0, seg.height > 0 else { return nil }
        let size = CGSize(width: seg.width, height: seg.height)
        let r = UIGraphicsImageRenderer(size: size)
        return r.image { ctx in
            UIColor.clear.setFill(); ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.setFillColor(UIColor.red.withAlphaComponent(0.5).cgColor)
            for y in 0..<seg.height {
                for x in 0..<seg.width {
                    if seg.mask[y*seg.width + x] {
                        ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
                    }
                }
            }
        }
    }
}

struct ResultsView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = ResultsViewModel()
    @State private var showPaywall = false

    var body: some View {
        let metrics = viewModel.compute(appState: appState)
        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                AnimatedGradientHeader(title: "Results", subtitle: "Final metrics and exports")
                HStack(spacing: DS.Spacing.lg) {
                    ZStack {
                        StatCard(title: "Viability", value: String(format: "%.1f%%", metrics.viability), subtitle: nil, icon: "cross.case.fill", gradient: Theme.gradientSuccess)
                        RingGauge(progress: min(max(metrics.viability/100.0, 0), 1), lineWidth: 10, gradient: Theme.gradientSuccess)
                            .frame(width: 110, height: 110)
                            .padding(.trailing, 12)
                            .opacity(0.25)
                    }
                    StatCard(title: "Concentration", value: String(format: "%.3e cells/mL", metrics.conc), subtitle: nil, icon: "chart.bar.fill", gradient: Theme.gradient1)
                }
                .frame(height: 140)
                StatCard(title: "Live / Dead", value: "\(metrics.live) / \(metrics.dead)", subtitle: nil, icon: "heart.text.square.fill", gradient: Theme.gradient2)
                    .frame(height: 120)
                VStack(spacing: DS.Spacing.sm) {
                    HStack { Text("Squares Used").foregroundColor(Theme.textSecondary); Spacer(); Text("4").foregroundColor(Theme.textPrimary) }
                    HStack { Text("Dilution").foregroundColor(Theme.textSecondary); Spacer(); Stepper(String(format: "%.1fx", viewModel.dilution), value: $viewModel.dilution, in: 0.1...100, step: 0.1) }
                }
                .cardStyle()

                if appState.focusScore < 0.1 { QCRow(text: "Low focus score", color: .orange) }
                if appState.glareRatio > 0.1 { QCRow(text: "High glare detected", color: .orange) }
                if metrics.overcrowded { QCRow(text: "Overcrowding detected", color: .red) }

                HStack {
                    Button("Export CSV") { viewModel.exportCSV(appState: appState) }
                    Button("Export Detections CSV") {
                        guard PurchaseManager.shared.isPro else { showPaywall = true; return }
                        let exporter = CSVExporter()
                        if let url = try? exporter.exportDetections(sampleId: UUID().uuidString, labeled: appState.labeled) {
                            viewModel.exportURL = url
                        }
                    }
                    if let url = viewModel.exportURL { ShareLink(item: url) { Text("Share") } }
                    Spacer()
                    Button("Save Sample") { viewModel.saveSample(appState: appState); Haptics.success() }
                    Button("Export PDF") {
                        let header = ReportHeader(project: Settings.shared.project, operatorName: Settings.shared.operatorName, timestamp: Date())
                        let tally = CountingService.tallyByLargeSquare(objects: appState.objects, geometry: GridGeometry(originPx: .zero, pxPerMicron: appState.pxPerMicron ?? 1.0))
                        let images = ReportImages(original: appState.capturedImage, corrected: appState.correctedImage, overlay: appState.correctedImage.map { PDFExporter.makeOverlayImage(base: $0, labeled: appState.labeled) })
                        let exporter = PDFExporter()
                        let watermark = !PurchaseManager.shared.isPro
                        if let url = try? exporter.exportReport(header: header, images: images, tally: tally, params: ImagingParams(), watermark: watermark, filename: "report.pdf") {
                            viewModel.exportURL = url
                            Haptics.success()
                        }
                    }
                    if let corrected = appState.correctedImage { Button("Save Image") { UIImageWriteToSavedPhotosAlbum(corrected, nil, nil, nil) } }
                }
                
                #if ADS
                if !PurchaseManager.shared.isPro { BannerAdView().frame(height: 50) }
                #endif
            }
            .padding()
        }
        .navigationTitle("Results")
        .toolbar { ToolbarItem(placement: .navigationBarTrailing) { NavigationLink(destination: PaywallView(), isActive: $showPaywall) { EmptyView() } } }
        .appBackground()
    }
}

private struct QCRow: View { let text: String; let color: Color; var body: some View { Label(text, systemImage: "exclamationmark.triangle.fill").foregroundStyle(color) .frame(maxWidth: .infinity, alignment: .leading).padding(8).background(color.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 8)) } }

private extension View { func card() -> some View { self.padding(12).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 8)) } }
