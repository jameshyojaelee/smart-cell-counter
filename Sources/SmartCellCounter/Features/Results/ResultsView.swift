import SwiftUI
import UIKit

@MainActor
final class ResultsViewModel: ObservableObject {
    @Published var dilution: Double = 1.0
    @Published var exportURL: URL?

    func compute(appState: AppState) -> (conc: Double, live: Int, dead: Int, squares: Int, viability: Double, overcrowded: Bool, selected: [Int], mean: Double) {
        let live = appState.labeled.filter { $0.label == "live" }.count
        let dead = appState.labeled.filter { $0.label == "dead" }.count
        let selectedSquares = appState.selectedLargeSquares.isEmpty ? [0, 2, 6, 8] : appState.selectedLargeSquares
        let squares = selectedSquares.count
        let pxPerMicron = appState.pxPerMicron ?? 1.0
        let geom = GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron)
        let tally = CountingService.tallyByLargeSquare(objects: appState.objects, geometry: geom)
        let mean = CountingService.meanCountPerLargeSquare(countsByIndex: tally, selectedLargeIndices: selectedSquares)
        let conc = CountingService.concentrationPerML(meanCountPerLargeSquare: mean, dilutionFactor: dilution)
        let viability = CountingService.viabilityPercent(live: live, dead: dead)
        let overcrowded = mean > 300
        return (conc, live, dead, squares, viability, overcrowded, selectedSquares, mean)
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

    func saveSample(appState: AppState) async {
        let id = UUID().uuidString
        let header = ReportHeader(project: Settings.shared.project, operatorName: Settings.shared.operatorName, timestamp: Date())
        let original = appState.capturedImage
        let corrected = appState.correctedImage
        let overlay = corrected.map { PDFExporter.makeOverlayImage(base: $0, labeled: appState.labeled) }

        let pxPerMicron = appState.pxPerMicron ?? 1.0
        let geom = GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron)
        let tally = CountingService.tallyByLargeSquare(objects: appState.objects, geometry: geom)
        let exporter = PDFExporter()
        let params = ImagingParams.from(SettingsStore.shared)

        guard let folder = try? await AppDatabase.shared.sampleFolder(id: id) else { return }
        var imagePath: String? = nil
        var maskPath: String? = nil
        var pdfPath: String? = nil
        var csvPath: String? = nil
        var thumbnailInfo: (path: String, size: CGSize)? = nil
        if let corrected = corrected { imagePath = (try? await AppDatabase.shared.save(image: corrected, name: "corrected.png", in: folder))?.path }
        if let seg = appState.segmentation, let maskImage = makeMaskImage(seg) {
            maskPath = (try? await AppDatabase.shared.save(image: maskImage, name: "mask.png", in: folder))?.path
        }
        if let pdfURL = try? exporter.exportReport(header: header, images: ReportImages(original: original, corrected: corrected, overlay: overlay), tally: tally, params: params, watermark: true, filename: "report.pdf") { pdfPath = pdfURL.path }

        if let baseImage = corrected ?? original,
           let (thumbnail, size) = makeThumbnail(from: baseImage) {
            let thumbURL = folder.appendingPathComponent("thumbnail.png")
            if let data = thumbnail.pngData() {
                try? data.write(to: thumbURL)
                thumbnailInfo = (thumbURL.path, size)
            }
        }

        let m = compute(appState: appState)
        let dateFormatter = ISO8601DateFormatter()
        let dilutionString = String(format: "%.1f", self.dilution)
        let concentrationString = String(format: "%.3e", m.conc)
        let csvRows = [
            "Project,Operator,Date,Live,Dead,Dilution,Concentration",
            "\(header.project),\(header.operatorName),\(dateFormatter.string(from: Date())),\(m.live),\(m.dead),\(dilutionString),\(concentrationString)"
        ]
        let summaryURL = folder.appendingPathComponent("summary.csv")
        try? csvRows.joined(separator: "\n").write(to: summaryURL, atomically: true, encoding: String.Encoding.utf8)
        csvPath = summaryURL.path

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
                                thumbnailPath: thumbnailInfo?.path,
                                thumbnailWidth: Double(thumbnailInfo?.size.width ?? 0),
                                thumbnailHeight: Double(thumbnailInfo?.size.height ?? 0),
                                csvPath: csvPath,
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
        try? await AppDatabase.shared.insertSample(srec, detections: dets)
    }

    private func makeMaskImage(_ seg: SegmentationResult) -> UIImage? {
        guard seg.width > 0, seg.height > 0 else { return nil }
        let size = CGSize(width: seg.width, height: seg.height)
        let r = UIGraphicsImageRenderer(size: size)
        let base = r.image { ctx in
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
        let targetSize = seg.originalSize == .zero ? CGSize(width: seg.width, height: seg.height) : seg.originalSize
        guard targetSize != size else { return base }
        let upscale = UIGraphicsImageRenderer(size: targetSize)
        return upscale.image { _ in
            base.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }

    private func makeThumbnail(from image: UIImage) -> (UIImage, CGSize)? {
        let maxDimension: CGFloat = 120
        let originalSize = image.size
        guard originalSize.width > 0, originalSize.height > 0 else { return nil }
        let scale = max(originalSize.width, originalSize.height) / maxDimension
        let ratio = max(scale, 1)
        let targetSize = CGSize(width: originalSize.width / ratio, height: originalSize.height / ratio)
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        let reduced = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
        return (reduced, targetSize)
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
                AnimatedGradientHeader(title: LocalizedStringKey("Results"), subtitle: LocalizedStringKey("Final metrics and exports"))
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
                    HStack {
                        Text(LocalizedStringKey("Squares Used")).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text("\(metrics.squares)").foregroundColor(Theme.textPrimary)
                    }
                    if !metrics.selected.isEmpty {
                        HStack {
                            Text(LocalizedStringKey("Selected Squares"))
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(metrics.selected.map(String.init).joined(separator: ", "))
                                .foregroundColor(Theme.textPrimary)
                                .font(.caption)
                        }
                    }
                    HStack {
                        Text(LocalizedStringKey("Dilution")).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Stepper(value: $viewModel.dilution, in: 0.1...100, step: 0.1) {
                            Text(String(format: "%.1fx", viewModel.dilution))
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                }
                .cardStyle()

                VStack(spacing: 8) {
                    DisclosureGroup(LocalizedStringKey("How is concentration calculated?")) {
                        Text(LocalizedStringKey("Cells/mL = average cells per large square × 10⁴ × dilution factor."))
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    DisclosureGroup(LocalizedStringKey("How is viability calculated?")) {
                        Text(LocalizedStringKey("Viability (%) = live cells ÷ total cells × 100."))
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .cardStyle()

                if appState.focusScore < 0.1 { QCRow(text: LocalizedStringKey("Low focus score"), color: .orange) }
                if appState.glareRatio > 0.1 { QCRow(text: LocalizedStringKey("High glare detected"), color: .orange) }
                if metrics.overcrowded { QCRow(text: LocalizedStringKey("Overcrowding detected"), color: .red) }

                HStack {
                    Button(LocalizedStringKey("Export CSV")) { viewModel.exportCSV(appState: appState) }
                    Button(LocalizedStringKey("Export Detections CSV")) {
                        guard PurchaseManager.shared.isPro else { showPaywall = true; return }
                        let exporter = CSVExporter()
                        if let url = try? exporter.exportDetections(sampleId: UUID().uuidString, labeled: appState.labeled) {
                            viewModel.exportURL = url
                        }
                    }
                    if let url = viewModel.exportURL { ShareLink(item: url) { Text(LocalizedStringKey("Share")) } }
                    Spacer()
                    Button(LocalizedStringKey("Save Sample")) {
                        Task {
                            await viewModel.saveSample(appState: appState)
                            Haptics.success()
                        }
                    }
                    Button(LocalizedStringKey("Export PDF")) {
                        let header = ReportHeader(project: Settings.shared.project, operatorName: Settings.shared.operatorName, timestamp: Date())
                        let tally = CountingService.tallyByLargeSquare(objects: appState.objects, geometry: GridGeometry(originPx: .zero, pxPerMicron: appState.pxPerMicron ?? 1.0))
                        let images = ReportImages(original: appState.capturedImage, corrected: appState.correctedImage, overlay: appState.correctedImage.map { PDFExporter.makeOverlayImage(base: $0, labeled: appState.labeled) })
                        let exporter = PDFExporter()
                        let watermark = !PurchaseManager.shared.isPro
                        if let url = try? exporter.exportReport(header: header,
                                                                images: images,
                                                                tally: tally,
                                                                params: ImagingParams.from(SettingsStore.shared),
                                                                watermark: watermark,
                                                                filename: "report.pdf") {
                            viewModel.exportURL = url
                            Haptics.success()
                        }
                    }
                    if let corrected = appState.correctedImage { Button(LocalizedStringKey("Save Image")) { UIImageWriteToSavedPhotosAlbum(corrected, nil, nil, nil) } }
                }

                #if ADS
                if !PurchaseManager.shared.isPro { BannerAdView().frame(height: 50) }
                #endif
            }
            .padding()
        }
        .navigationTitle(LocalizedStringKey("Results"))
        .modifier(ResultsNavigation(showPaywall: $showPaywall))
        .appBackground()
    }
}

private struct QCRow: View {
    let text: LocalizedStringKey
    let color: Color

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

private extension View { func card() -> some View { self.padding(12).background(Color(.secondarySystemBackground)).clipShape(RoundedRectangle(cornerRadius: 8)) } }

// MARK: - Navigation modernization
private struct ResultsNavigation: ViewModifier {
    @Binding var showPaywall: Bool
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content
                .navigationDestination(isPresented: $showPaywall) { PaywallView() }
        } else {
            content
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        NavigationLink(destination: PaywallView(), isActive: $showPaywall) { EmptyView() }
                    }
                }
        }
    }
}
