import SwiftUI
import UIKit

@MainActor
final class ResultsViewModel: ObservableObject {
    enum ExportKind: String, CaseIterable, Identifiable {
        case summaryCSV
        case detectionsCSV
        case pdf

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .summaryCSV: L10n.Results.exportCSV
            case .detectionsCSV: L10n.Results.exportDetectionsCSV
            case .pdf: L10n.Results.exportPDF
            }
        }

        var iconName: String {
            switch self {
            case .summaryCSV: "doc.text"
            case .detectionsCSV: "tablecells"
            case .pdf: "doc.richtext"
            }
        }

        var fileExtension: String {
            switch self {
            case .summaryCSV, .detectionsCSV: "csv"
            case .pdf: "pdf"
            }
        }

        var filenamePrefix: String {
            switch self {
            case .summaryCSV: "summary"
            case .detectionsCSV: "detections"
            case .pdf: "report"
            }
        }

        var requiresPro: Bool {
            switch self {
            case .summaryCSV:
                false
            case .detectionsCSV, .pdf:
                true
            }
        }
    }

    struct ExportRecord: Identifiable, Equatable {
        let id: UUID
        let kind: ExportKind
        let url: URL
        let createdAt: Date
        let metadata: ExportMetadata
        let sampleId: String

        var filename: String { url.lastPathComponent }

        var formattedDate: String {
            ExportRecord.dateFormatter.string(from: createdAt)
        }

        var metadataSummary: String {
            var parts: [String] = []
            let trimmedLab = metadata.labName.trimmingCharacters(in: .whitespacesAndNewlines)
            let trimmedStain = metadata.stain.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedLab.isEmpty { parts.append(trimmedLab) }
            if !trimmedStain.isEmpty { parts.append(trimmedStain) }
            parts.append(metadata.formattedDilution)
            return parts.joined(separator: " • ")
        }

        private static let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            formatter.timeStyle = .short
            return formatter
        }()
    }

    struct ExportAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let showsUpgrade: Bool
    }

    enum ExportStatus: Equatable {
        case idle
        case inProgress(kind: ExportKind, progress: Double, message: String?)
        case completed(kind: ExportKind, url: URL)
        case failed(kind: ExportKind, message: String)
    }

    @Published var dilution: Double
    @Published private(set) var exportStatus: ExportStatus = .idle
    @Published private(set) var exportHistory: [ExportRecord] = []
    @Published var alert: ExportAlert?

    private var exportTask: Task<Void, Never>?
    private let historyLimit = 6

    init(defaultDilution: Double? = nil) {
        if let defaultDilution {
            dilution = defaultDilution
        } else {
            dilution = SettingsStore.shared.dilutionFactor
        }
    }

    deinit {
        exportTask?.cancel()
    }

    var isExporting: Bool {
        if case .inProgress = exportStatus { return true }
        return false
    }

    var latestExportURL: URL? {
        exportHistory.first?.url
    }

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

    @discardableResult
    func performExport(_ kind: ExportKind, appState: AppState) -> Bool {
        guard canAccess(kind) else { return false }
        guard checkWritePermission() else { return false }
        exportTask?.cancel()
        exportTask = Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }
            await MainActor.run {
                self.updateProgress(kind: kind, progress: 0.05, message: L10n.Results.Export.preparing)
            }
            do {
                let payload = buildPayload(for: kind, appState: appState)
                try Task.checkCancellation()
                await MainActor.run {
                    self.updateProgress(kind: kind, progress: 0.35, message: L10n.Results.Export.writing)
                }
                let url = try await performExport(kind: kind, payload: payload)
                try Task.checkCancellation()
                await MainActor.run {
                    self.updateProgress(kind: kind, progress: 0.85, message: L10n.Results.Export.finishing)
                }
                await MainActor.run {
                    self.recordSuccess(kind: kind, url: url, payload: payload)
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.updateProgress(kind: kind, progress: 0, message: nil)
                }
            } catch {
                await MainActor.run {
                    self.recordFailure(kind: kind, error: error)
                }
            }
        }
        return true
    }

    func cancelExport() {
        exportTask?.cancel()
        exportTask = nil
        exportStatus = .idle
    }

    func saveSample(appState: AppState) async {
        let id = UUID().uuidString
        let now = Date()
        let header = ReportHeader(project: Settings.shared.project, operatorName: Settings.shared.operatorName, timestamp: now)
        let metadata = makeMetadata()
        let original = appState.capturedImage
        let corrected = appState.correctedImage
        let overlay = corrected.map { PDFExporter.makeOverlayImage(base: $0, labeled: appState.labeled) }

        let pxPerMicron = appState.pxPerMicron ?? 1.0
        let geom = GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron)
        let tally = CountingService.tallyByLargeSquare(objects: appState.objects, geometry: geom)
        let exporter = PDFExporter()
        let csvExporter = CSVExporter()
        let params = ImagingParams.from(SettingsStore.shared)

        guard let folder = try? await AppDatabase.shared.sampleFolder(id: id) else { return }
        var imagePath: String? = nil
        var maskPath: String? = nil
        var pdfPath: String? = nil
        var csvPath: String? = nil
        var thumbnailInfo: (path: String, size: CGSize)? = nil

        if let corrected {
            imagePath = await (try? AppDatabase.shared.save(image: corrected, name: "corrected.png", in: folder))?.path
        }
        if let seg = appState.segmentation, let maskImage = makeMaskImage(seg) {
            maskPath = await (try? AppDatabase.shared.save(image: maskImage, name: "mask.png", in: folder))?.path
        }
        if let pdfURL = try? exporter.exportReport(header: header,
                                                   metadata: metadata,
                                                   images: ReportImages(original: original, corrected: corrected, overlay: overlay),
                                                   tally: tally,
                                                   params: params,
                                                   watermark: true,
                                                   filename: "report.pdf") {
            pdfPath = pdfURL.path
        }

        if let baseImage = corrected ?? original,
           let (thumbnail, size) = makeThumbnail(from: baseImage) {
            let thumbURL = folder.appendingPathComponent("thumbnail.png")
            if let data = thumbnail.pngData() {
                try? data.write(to: thumbURL)
                thumbnailInfo = (thumbURL.path, size)
            }
        }

        let metrics = compute(appState: appState)
        if let summaryURL = try? csvExporter.exportSummary(sampleId: id,
                                                           timestamp: now,
                                                           operatorName: header.operatorName,
                                                           project: header.project,
                                                           metadata: metadata,
                                                           concentrationPerML: metrics.conc,
                                                           viabilityPercent: metrics.viability,
                                                           live: metrics.live,
                                                           dead: metrics.dead,
                                                           filename: L10n.Results.CSV.summaryFilename) {
            csvPath = summaryURL.path
        }

        let record = SampleRecord(id: id,
                                  createdAt: now,
                                  operatorName: Settings.shared.operatorName,
                                  project: Settings.shared.project,
                                  chamberType: Settings.shared.chamberType,
                                  dilutionFactor: dilution,
                                  stainType: Settings.shared.stainType,
                                  liveTotal: metrics.live,
                                  deadTotal: metrics.dead,
                                  concentrationPerMl: metrics.conc,
                                  viabilityPercent: metrics.viability,
                                  squaresUsed: metrics.squares,
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

        var detectionRecords: [DetectionRecord] = []
        for item in appState.labeled {
            detectionRecords.append(
                DetectionRecord(sampleId: id,
                                objectId: UUID().uuidString,
                                x: Double(item.base.centroid.x),
                                y: Double(item.base.centroid.y),
                                areaPx: item.base.areaPx,
                                circularity: item.base.circularity,
                                solidity: item.base.solidity,
                                isLive: item.label == "live")
            )
        }
        try? await AppDatabase.shared.insertSample(record, detections: detectionRecords)
    }

    private func buildPayload(for kind: ExportKind, appState: AppState) -> ExportPayload {
        let timestamp = Date()
        let metadata = makeMetadata()
        switch kind {
        case .summaryCSV:
            let metrics = compute(appState: appState)
            let payload = SummaryPayload(sampleId: UUID().uuidString,
                                         timestamp: timestamp,
                                         operatorName: Settings.shared.operatorName,
                                         project: Settings.shared.project,
                                         metadata: metadata,
                                         concentrationPerML: metrics.conc,
                                         viabilityPercent: metrics.viability,
                                         live: metrics.live,
                                         dead: metrics.dead,
                                         filename: makeFilename(prefix: kind.filenamePrefix, fileExtension: kind.fileExtension, timestamp: timestamp))
            return .summary(payload)
        case .detectionsCSV:
            let payload = DetectionsPayload(sampleId: UUID().uuidString,
                                            timestamp: timestamp,
                                            metadata: metadata,
                                            labeled: appState.labeled,
                                            filename: makeFilename(prefix: kind.filenamePrefix, fileExtension: kind.fileExtension, timestamp: timestamp))
            return .detections(payload)
        case .pdf:
            let header = ReportHeader(project: Settings.shared.project, operatorName: Settings.shared.operatorName, timestamp: timestamp)
            let corrected = appState.correctedImage
            let overlay = corrected.map { PDFExporter.makeOverlayImage(base: $0, labeled: appState.labeled) }
            let images = ReportImages(original: appState.capturedImage, corrected: corrected, overlay: overlay)
            let pxPerMicron = appState.pxPerMicron ?? 1.0
            let tally = CountingService.tallyByLargeSquare(objects: appState.objects,
                                                           geometry: GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron))
            let payload = PDFPayload(reportId: UUID().uuidString,
                                     timestamp: timestamp,
                                     metadata: metadata,
                                     header: header,
                                     images: images,
                                     tally: tally,
                                     params: ImagingParams.from(SettingsStore.shared),
                                     watermark: !PurchaseManager.shared.isPro,
                                     filename: makeFilename(prefix: kind.filenamePrefix, fileExtension: kind.fileExtension, timestamp: timestamp))
            return .pdf(payload)
        }
    }

    private func performExport(kind _: ExportKind, payload: ExportPayload) async throws -> URL {
        switch payload {
        case let .summary(summary):
            try await Task.detached(priority: .userInitiated) {
                let exporter = CSVExporter()
                return try exporter.exportSummary(sampleId: summary.sampleId,
                                                  timestamp: summary.timestamp,
                                                  operatorName: summary.operatorName,
                                                  project: summary.project,
                                                  metadata: summary.metadata,
                                                  concentrationPerML: summary.concentrationPerML,
                                                  viabilityPercent: summary.viabilityPercent,
                                                  live: summary.live,
                                                  dead: summary.dead,
                                                  filename: summary.filename)
            }.value
        case let .detections(detections):
            try await Task.detached(priority: .userInitiated) {
                let exporter = CSVExporter()
                return try exporter.exportDetections(sampleId: detections.sampleId,
                                                     labeled: detections.labeled,
                                                     metadata: detections.metadata,
                                                     filename: detections.filename)
            }.value
        case let .pdf(report):
            try await MainActor.run {
                let exporter = PDFExporter()
                return try exporter.exportReport(header: report.header,
                                                 metadata: report.metadata,
                                                 images: report.images,
                                                 tally: report.tally,
                                                 params: report.params,
                                                 watermark: report.watermark,
                                                 filename: report.filename)
            }
        }
    }

    @MainActor
    private func updateProgress(kind: ExportKind, progress: Double, message: String?) {
        let clamped = min(max(progress, 0), 1)
        exportStatus = .inProgress(kind: kind, progress: clamped, message: message)
    }

    @MainActor
    private func recordSuccess(kind: ExportKind, url: URL, payload: ExportPayload) {
        exportStatus = .completed(kind: kind, url: url)
        let record = ExportRecord(id: UUID(),
                                  kind: kind,
                                  url: url,
                                  createdAt: payload.timestamp,
                                  metadata: payload.metadata,
                                  sampleId: payload.sampleId)
        exportHistory.insert(record, at: 0)
        if exportHistory.count > historyLimit {
            exportHistory = Array(exportHistory.prefix(historyLimit))
        }
        Haptics.success()
    }

    @MainActor
    private func recordFailure(kind: ExportKind, error: Error) {
        let description = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        let message = description.isEmpty ? L10n.Results.Export.errorGeneric : description
        exportStatus = .failed(kind: kind, message: message)
        alert = ExportAlert(title: L10n.Results.Export.errorTitle, message: message, showsUpgrade: false)
        Haptics.error()
    }

    private func makeMetadata() -> ExportMetadata {
        ExportMetadata(labName: Settings.shared.labName,
                       stain: Settings.shared.stainType,
                       dilution: dilution)
    }

    private func canAccess(_ kind: ExportKind) -> Bool {
        if kind.requiresPro, !PurchaseManager.shared.isPro {
            alert = ExportAlert(title: L10n.Results.Export.lockedTitle,
                                message: L10n.Results.Export.proRequired(kind.displayName),
                                showsUpgrade: true)
            return false
        }
        return true
    }

    #if DEBUG
        func debugResetAlert() {
            alert = nil
        }

        func debugCanAccess(_ kind: ExportKind) -> Bool {
            canAccess(kind)
        }
    #endif

    private func makeFilename(prefix: String, fileExtension: String, timestamp: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withDashSeparatorInDate, .withFullTime]
        let raw = formatter.string(from: timestamp).replacingOccurrences(of: ":", with: "-")
        return "\(prefix)-\(raw).\(fileExtension)"
    }

    private func checkWritePermission() -> Bool {
        let directory = FileManager.default.temporaryDirectory
        if FileManager.default.isWritableFile(atPath: directory.path) {
            return true
        }
        let probeURL = directory.appendingPathComponent("write-test-\(UUID().uuidString)")
        do {
            try "test".write(to: probeURL, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(at: probeURL)
            return true
        } catch {
            alert = ExportAlert(title: L10n.Results.Export.errorTitle,
                                message: L10n.Results.Export.permissionDenied,
                                showsUpgrade: false)
            Haptics.error()
            return false
        }
    }

    private func makeMaskImage(_ seg: SegmentationResult) -> UIImage? {
        guard seg.width > 0, seg.height > 0 else { return nil }
        let size = CGSize(width: seg.width, height: seg.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        let base = renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.setFillColor(UIColor.red.withAlphaComponent(0.5).cgColor)
            for y in 0 ..< seg.height {
                for x in 0 ..< seg.width where seg.mask[y * seg.width + x] {
                    ctx.cgContext.fill(CGRect(x: x, y: y, width: 1, height: 1))
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

    private struct SummaryPayload {
        let sampleId: String
        let timestamp: Date
        let operatorName: String
        let project: String
        let metadata: ExportMetadata
        let concentrationPerML: Double
        let viabilityPercent: Double
        let live: Int
        let dead: Int
        let filename: String
    }

    private struct DetectionsPayload {
        let sampleId: String
        let timestamp: Date
        let metadata: ExportMetadata
        let labeled: [CellObjectLabeled]
        let filename: String
    }

    private struct PDFPayload {
        let reportId: String
        let timestamp: Date
        let metadata: ExportMetadata
        let header: ReportHeader
        let images: ReportImages
        let tally: [Int: Int]
        let params: ImagingParams
        let watermark: Bool
        let filename: String
    }

    private enum ExportPayload {
        case summary(SummaryPayload)
        case detections(DetectionsPayload)
        case pdf(PDFPayload)

        var metadata: ExportMetadata {
            switch self {
            case let .summary(payload): payload.metadata
            case let .detections(payload): payload.metadata
            case let .pdf(payload): payload.metadata
            }
        }

        var timestamp: Date {
            switch self {
            case let .summary(payload): payload.timestamp
            case let .detections(payload): payload.timestamp
            case let .pdf(payload): payload.timestamp
            }
        }

        var sampleId: String {
            switch self {
            case let .summary(payload): payload.sampleId
            case let .detections(payload): payload.sampleId
            case let .pdf(payload): payload.reportId
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
        let viabilityValue = L10n.Results.viabilityValue(metrics.viability)
        let concentrationValue = L10n.Results.concentrationValue(metrics.conc)
        let liveDeadValue = L10n.Results.liveDeadValue(live: metrics.live, dead: metrics.dead)

        ScrollView {
            VStack(spacing: DS.Spacing.lg) {
                AnimatedGradientHeader(title: L10n.Results.headerTitle, subtitle: L10n.Results.headerSubtitle)

                HStack(spacing: DS.Spacing.lg) {
                    ZStack {
                        StatCard(title: L10n.Results.viabilityTitle, value: viabilityValue, subtitle: nil, icon: "cross.case.fill", gradient: Theme.gradientSuccess)
                        RingGauge(progress: min(max(metrics.viability / 100.0, 0), 1),
                                  lineWidth: 10,
                                  gradient: Theme.gradientSuccess)
                            .frame(width: 110, height: 110)
                            .padding(.trailing, 12)
                            .opacity(0.25)
                    }
                    StatCard(title: L10n.Results.concentrationTitle, value: concentrationValue, subtitle: nil, icon: "chart.bar.fill", gradient: Theme.gradient1)
                }
                .frame(height: 140)

                StatCard(title: L10n.Results.liveDeadTitle, value: liveDeadValue, subtitle: nil, icon: "heart.text.square.fill", gradient: Theme.gradient2)
                    .frame(height: 120)

                VStack(spacing: DS.Spacing.sm) {
                    HStack {
                        Text(L10n.Results.squaresUsed).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Text(L10n.Results.countValue(metrics.squares)).foregroundColor(Theme.textPrimary)
                    }
                    if !metrics.selected.isEmpty {
                        HStack {
                            Text(L10n.Results.selectedSquares)
                                .foregroundColor(Theme.textSecondary)
                            Spacer()
                            Text(L10n.Results.selectedSquaresList(metrics.selected))
                                .foregroundColor(Theme.textPrimary)
                                .font(.caption)
                        }
                    }
                    HStack {
                        Text(L10n.Results.dilution).foregroundColor(Theme.textSecondary)
                        Spacer()
                        Stepper(value: $viewModel.dilution, in: 0.1 ... 100, step: 0.1) {
                            Text(L10n.Results.dilutionValue(viewModel.dilution))
                                .foregroundColor(Theme.textPrimary)
                        }
                    }
                }
                .cardStyle()

                VStack(spacing: 8) {
                    DisclosureGroup(L10n.Results.concentrationFAQ) {
                        Text(L10n.Results.concentrationExplanation)
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    DisclosureGroup(L10n.Results.viabilityFAQ) {
                        Text(L10n.Results.viabilityExplanation)
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .cardStyle()

                if appState.focusScore < 0.1 { QCRow(text: L10n.Results.qcLowFocus, color: .orange) }
                if appState.glareRatio > 0.1 { QCRow(text: L10n.Results.qcHighGlare, color: .orange) }
                if metrics.overcrowded { QCRow(text: L10n.Results.qcOvercrowded, color: .red) }

                VStack(spacing: DS.Spacing.sm) {
                    HStack(spacing: DS.Spacing.sm) {
                        Button {
                            _ = viewModel.performExport(.summaryCSV, appState: appState)
                        } label: {
                            Label {
                                Text(L10n.Results.exportCSV)
                            } icon: {
                                Image(systemName: ResultsViewModel.ExportKind.summaryCSV.iconName)
                            }
                        }
                        .disabled(viewModel.isExporting)
                        .accessibilityHint(L10n.Results.exportCSVHint)

                        Button {
                            _ = viewModel.performExport(.detectionsCSV, appState: appState)
                        } label: {
                            Label {
                                HStack(spacing: 4) {
                                    Text(L10n.Results.exportDetectionsCSV)
                                    if ResultsViewModel.ExportKind.detectionsCSV.requiresPro, !PurchaseManager.shared.isPro {
                                        ProBadge()
                                    }
                                }
                            } icon: {
                                Image(systemName: ResultsViewModel.ExportKind.detectionsCSV.iconName)
                            }
                        }
                        .disabled(viewModel.isExporting)
                        .accessibilityHint(L10n.Results.exportDetectionsHint)

                        Button {
                            _ = viewModel.performExport(.pdf, appState: appState)
                        } label: {
                            Label {
                                HStack(spacing: 4) {
                                    Text(L10n.Results.exportPDF)
                                    if ResultsViewModel.ExportKind.pdf.requiresPro, !PurchaseManager.shared.isPro {
                                        ProBadge()
                                    }
                                }
                            } icon: {
                                Image(systemName: ResultsViewModel.ExportKind.pdf.iconName)
                            }
                        }
                        .disabled(viewModel.isExporting)
                        .accessibilityHint(L10n.Results.exportPDFHint)

                        Spacer()

                        Button(L10n.Results.saveSample) {
                            Task {
                                await viewModel.saveSample(appState: appState)
                                Haptics.success()
                            }
                        }
                        .accessibilityHint(L10n.Results.saveSampleHint)

                        if let corrected = appState.correctedImage {
                            Button(L10n.Results.saveImage) {
                                UIImageWriteToSavedPhotosAlbum(corrected, nil, nil, nil)
                            }
                            .accessibilityHint(L10n.Results.saveImageHint)
                        }
                    }

                    if case let .inProgress(kind, progress, message) = viewModel.exportStatus {
                        ExportProgressView(kind: kind, progress: progress, message: message)
                    }

                    if viewModel.exportHistory.isEmpty {
                        Text(L10n.Results.Export.historyEmpty)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                            Text(L10n.Results.Export.historyTitle)
                                .font(.headline)
                            ForEach(viewModel.exportHistory) { record in
                                ExportHistoryRow(record: record)
                            }
                        }
                    }
                }
                .cardStyle()

                #if ADS
                    if !PurchaseManager.shared.isPro { BannerAdView().frame(height: 50) }
                #endif
            }
            .padding()
        }
        .navigationTitle(L10n.Results.navigationTitle)
        .modifier(ResultsNavigation(showPaywall: $showPaywall))
        .appBackground()
        .alert(item: $viewModel.alert) { alert in
            if alert.showsUpgrade {
                Alert(title: Text(alert.title),
                      message: Text(alert.message),
                      primaryButton: .default(Text(L10n.Results.Export.upgrade)) {
                          showPaywall = true
                      },
                      secondaryButton: .cancel(Text(L10n.Results.Export.dismiss)))
            } else {
                Alert(title: Text(alert.title),
                      message: Text(alert.message),
                      dismissButton: .default(Text(L10n.Results.Export.dismiss)))
            }
        }
    }
}

private struct ExportProgressView: View {
    let kind: ResultsViewModel.ExportKind
    let progress: Double
    let message: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Label(kind.displayName, systemImage: kind.iconName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text("\(Int(progress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: progress, total: 1)
            if let message {
                Text(message)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
    }
}

private struct ExportHistoryRow: View {
    let record: ResultsViewModel.ExportRecord

    var body: some View {
        HStack(alignment: .top, spacing: DS.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                Label(record.kind.displayName, systemImage: record.kind.iconName)
                    .font(.subheadline)
                Text(record.filename)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(record.metadataSummary)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(record.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            ShareLink(item: record.url) {
                Image(systemName: "square.and.arrow.up")
                    .padding(6)
                    .background(Color(.tertiarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .accessibilityHint(L10n.Results.shareHint)
        }
        .padding(8)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct ProBadge: View {
    var body: some View {
        Text("PRO")
            .font(.caption2)
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .foregroundColor(Theme.accent)
            .background(Theme.accent.opacity(0.15))
            .clipShape(Capsule())
            .accessibilityLabel(Text("Pro feature"))
    }
}

private struct QCRow: View {
    let text: String
    let color: Color

    var body: some View {
        Label(text, systemImage: "exclamationmark.triangle.fill")
            .foregroundStyle(color)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .accessibilityLabel(text)
    }
}

private extension View {
    func cardStyle() -> some View {
        padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

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
