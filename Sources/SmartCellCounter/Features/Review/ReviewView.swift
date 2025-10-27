import CoreGraphics
import SwiftUI
import UIKit

@MainActor
final class ReviewViewModel: ObservableObject {
    struct ReviewStats {
        var liveCount: Int = 0
        var deadCount: Int = 0
        var averagePerSquare: Double = 0
        var selectedSquareCount: Int = 0
        var outlierCount: Int = 0

        var totalCount: Int { liveCount + deadCount }
        var formattedAverage: String {
            guard averagePerSquare.isFinite else { return "--" }
            return ReviewViewModel.averageFormatter.string(from: NSNumber(value: averagePerSquare)) ?? "--"
        }
    }

    enum OverlayOption: CaseIterable, Identifiable {
        case detections
        case segmentationMask
        case blueMask
        case gridMask
        case candidates
        case tallies

        var id: Self { self }

        static var defaultStates: [OverlayOption: Bool] = [
            .detections: true,
            .segmentationMask: false,
            .blueMask: false,
            .gridMask: false,
            .candidates: false,
            .tallies: true
        ]

        var title: String {
            switch self {
            case .detections: L10n.Review.Overlay.detections
            case .segmentationMask: L10n.Review.Overlay.segmentationMask
            case .blueMask: L10n.Review.Overlay.blueMask
            case .gridMask: L10n.Review.Overlay.gridMask
            case .candidates: L10n.Review.Overlay.candidates
            case .tallies: L10n.Review.Overlay.tallies
            }
        }

        var iconName: String {
            switch self {
            case .detections: "viewfinder"
            case .segmentationMask: "square.dashed"
            case .blueMask: "drop.fill"
            case .gridMask: "square.grid.3x3"
            case .candidates: "circle.hexagonpath"
            case .tallies: "number.square"
            }
        }

        var tint: Color {
            switch self {
            case .detections: Theme.accent
            case .segmentationMask: .pink
            case .blueMask: .blue
            case .gridMask: .yellow
            case .candidates: .orange
            case .tallies: Theme.textSecondary
            }
        }
    }

    @Published var lassoPath: Path = .init()
    @Published var perSquare: [Int: Int] = [:]
    @Published var selectedLarge: [Int] = [0, 2, 6, 8]
    @Published var isComputing = false
    @Published var lastDurationMs: Double = 0
    @Published var stats = ReviewStats()
    @Published var overlayStates: [OverlayOption: Bool] = OverlayOption.defaultStates
    @Published var pendingRemovalIDs: Set<Int> = []
    @Published var showLassoConfirmation = false
    @Published var undoAvailable = false

    private var undoStack: [[CellObjectLabeled]] = []
    private static let averageFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 0
        return formatter
    }()

    func isOverlayEnabled(_ option: OverlayOption) -> Bool {
        overlayStates[option, default: false]
    }

    func toggleOverlay(_ option: OverlayOption) {
        overlayStates[option, default: false].toggle()
    }

    var showTallies: Bool { overlayStates[.tallies, default: true] }

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
            let pxPerMicron = det.pxPerMicron ?? min(Double(image.size.width) / 3000.0, Double(image.size.height) / 3000.0)
            let geom = GridGeometry(originPx: .zero, pxPerMicron: pxPerMicron)
            let tally = CountingService.tallyByLargeSquare(objects: det.objects, geometry: geom)
            let ms = Date().timeIntervalSince(start) * 1000
            PerformanceLogger.shared.record(stage: .total, duration: ms)
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
                self.refreshStats(appState: appState, countsByIndex: tally)
            }
        }
    }

    func toggleLabel(for id: Int, in appState: AppState) {
        if let idx = appState.labeled.firstIndex(where: { $0.id == id }) {
            let cur = appState.labeled[idx]
            let newLabel = cur.label == "dead" ? "live" : "dead"
            appState.labeled[idx] = CellObjectLabeled(id: cur.id, base: cur.base, color: cur.color, label: newLabel, confidence: cur.confidence)
            refreshStats(appState: appState)
        }
    }

    func toggleSquare(_ index: Int, appState: AppState) {
        var updated = selectedLarge
        if let existingIndex = updated.firstIndex(of: index) {
            if updated.count > 1 {
                updated.remove(at: existingIndex)
            }
        } else {
            updated.append(index)
        }
        selectedLarge = Array(Set(updated)).sorted()
        refreshStats(appState: appState)
    }

    func prepareLassoConfirmation(in appState: AppState) {
        let ids = appState.labeled
            .filter { lassoPath.contains($0.base.centroid) }
            .map(\.id)
        pendingRemovalIDs = Set(ids)
        showLassoConfirmation = !ids.isEmpty
        if ids.isEmpty {
            lassoPath = Path()
        }
    }

    func cancelLassoSelection() {
        pendingRemovalIDs.removeAll()
        showLassoConfirmation = false
        lassoPath = Path()
    }

    func confirmLassoRemoval(in appState: AppState) {
        guard !pendingRemovalIDs.isEmpty else {
            cancelLassoSelection()
            return
        }
        undoStack.append(appState.labeled)
        appState.labeled.removeAll { pendingRemovalIDs.contains($0.id) }
        undoAvailable = !undoStack.isEmpty
        cancelLassoSelection()
        refreshStats(appState: appState)
    }

    func undoLastRemoval(in appState: AppState) {
        guard let previous = undoStack.popLast() else { return }
        appState.labeled = previous
        undoAvailable = !undoStack.isEmpty
        refreshStats(appState: appState)
    }

    func refreshStats(appState: AppState, countsByIndex: [Int: Int]? = nil) {
        let tally = countsByIndex ?? perSquare
        appState.selectedLargeSquares = selectedLarge

        let live = appState.labeled.filter { $0.label == "live" }.count
        let dead = appState.labeled.filter { $0.label == "dead" }.count
        let counts = selectedLarge.compactMap { tally[$0] }
        let average = counts.isEmpty
            ? 0
            : CountingService.meanCountPerLargeSquare(countsByIndex: tally, selectedLargeIndices: selectedLarge, outlierThreshold: 2.5)
        let values = counts.map(Double.init)
        let mask = CountingService.robustInliers(values, threshold: 2.5)
        let outliers = zip(values, mask).filter { !$0.1 }.count

        stats = ReviewStats(
            liveCount: live,
            deadCount: dead,
            averagePerSquare: average,
            selectedSquareCount: counts.count,
            outlierCount: outliers
        )
    }

    private static func makeSegmentationPreview(_ seg: SegmentationResult) -> UIImage? {
        guard seg.width > 0, seg.height > 0 else { return nil }
        let size = CGSize(width: seg.width, height: seg.height)
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { ctx in
            UIColor.clear.setFill()
            ctx.fill(CGRect(origin: .zero, size: size))
            ctx.cgContext.setFillColor(UIColor.systemPink.withAlphaComponent(0.45).cgColor)
            for idx in 0 ..< seg.mask.count where seg.mask[idx] {
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
    @State private var filter: ReviewFilter = .all
    var body: some View {
        VStack(spacing: 14) {
            reviewImageSection
                .frame(maxHeight: .infinity)

            ReviewStatsView(stats: viewModel.stats)
                .padding(.horizontal)

            if let segmentation = appState.segmentation {
                SegmentationMetadataView(segmentation: segmentation)
                    .padding(.horizontal)
            }

            ReviewOverlayToggleBar(
                options: ReviewViewModel.OverlayOption.allCases,
                states: viewModel.overlayStates,
                availability: { isOverlayAvailable($0) },
                toggle: { option in
                    viewModel.toggleOverlay(option)
                },
                undoAvailable: viewModel.undoAvailable,
                undoAction: { viewModel.undoLastRemoval(in: appState) }
            )
            .padding(.horizontal)

            if viewModel.showTallies, !viewModel.perSquare.isEmpty {
                PerSquareTable(
                    tally: viewModel.perSquare,
                    selected: Set(viewModel.selectedLarge),
                    onToggle: { index in viewModel.toggleSquare(index, appState: appState) }
                )
                .frame(maxHeight: 160)
                .cardStyle()
                .padding(.horizontal)
            }

            actionBar
                .padding(.horizontal)

            Picker(L10n.Review.filterLabel, selection: $filter) {
                ForEach(ReviewFilter.allCases) { option in
                    Text(option.title)
                        .tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
            .padding(.horizontal)
        }
        .navigationTitle(L10n.Review.navigationTitle)
        .onAppear {
            if appState.labeled.isEmpty,
               let img = appState.correctedImage ?? appState.capturedImage {
                viewModel.recompute(on: img, appState: appState)
            } else {
                viewModel.refreshStats(appState: appState)
            }
        }
        .modifier(ReviewNavigation(goToResults: $goToResults))
        .appBackground()
    }

    private var reviewImageSection: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let img = appState.correctedImage ?? appState.capturedImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .accessibilityLabel(L10n.Review.imageAccessibility)
                        .flipsForRightToLeftLayoutDirection(false)
                        .overlay {
                            if viewModel.isOverlayEnabled(.detections) {
                                DetectionOverlay(labeled: filteredLabeled()) { id in
                                    viewModel.toggleLabel(for: id, in: appState)
                                    Haptics.impact(.light)
                                }
                            }
                        }
                        .overlay {
                            overlayImages()
                        }
                        .gesture(lassoGesture(in: geo.size))

                    if viewModel.isComputing {
                        ProgressView(L10n.Review.computing)
                            .padding(8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding()
                    }

                    if viewModel.showLassoConfirmation {
                        LassoConfirmationBanner(
                            count: viewModel.pendingRemovalIDs.count,
                            confirm: { viewModel.confirmLassoRemoval(in: appState) },
                            cancel: { viewModel.cancelLassoSelection() }
                        )
                        .padding()
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                } else {
                    Text(L10n.Review.emptyState)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }
            }
        }
    }

    private var actionBar: some View {
        HStack {
            Button(L10n.Review.recompute) {
                if let img = appState.correctedImage ?? appState.capturedImage {
                    viewModel.recompute(on: img, appState: appState)
                }
            }
            .accessibilityHint(L10n.Review.recomputeHint)
            Spacer()
            Button(L10n.Common.next) { goToResults = true }
                .buttonStyle(.borderedProminent)
                .accessibilityHint(L10n.Review.nextHint)
        }
    }

    private func overlayImages() -> some View {
        ZStack {
            if viewModel.isOverlayEnabled(.segmentationMask),
               let mask = appState.debugImages["00_segmentation_mask"] {
                Image(uiImage: mask)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.55)
                    .accessibilityHidden(true)
            }
            if viewModel.isOverlayEnabled(.blueMask),
               let blue = appState.debugImages["08_blue_mask"] {
                Image(uiImage: blue)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.45)
                    .accessibilityHidden(true)
            }
            if viewModel.isOverlayEnabled(.gridMask),
               let grid = appState.debugImages["05_grid_mask"] {
                Image(uiImage: grid)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.45)
                    .accessibilityHidden(true)
            }
            if viewModel.isOverlayEnabled(.candidates),
               let candidates = appState.debugImages["07_candidates"] {
                Image(uiImage: candidates)
                    .resizable()
                    .scaledToFit()
                    .opacity(0.55)
                    .accessibilityHidden(true)
            }
        }
    }

    private func lassoGesture(in _: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if viewModel.lassoPath.isEmpty {
                    viewModel.lassoPath.move(to: value.location)
                }
                viewModel.lassoPath.addLine(to: value.location)
            }
            .onEnded { _ in
                viewModel.prepareLassoConfirmation(in: appState)
            }
    }

    private func filteredLabeled() -> [CellObjectLabeled] {
        switch filter {
        case .all: appState.labeled
        case .live: appState.labeled.filter { $0.label == "live" }
        case .dead: appState.labeled.filter { $0.label == "dead" }
        }
    }

    private func isOverlayAvailable(_ option: ReviewViewModel.OverlayOption) -> Bool {
        switch option {
        case .detections:
            !appState.labeled.isEmpty
        case .segmentationMask:
            appState.debugImages["00_segmentation_mask"] != nil
        case .blueMask:
            appState.debugImages["08_blue_mask"] != nil
        case .gridMask:
            appState.debugImages["05_grid_mask"] != nil
        case .candidates:
            appState.debugImages["07_candidates"] != nil
        case .tallies:
            !viewModel.perSquare.isEmpty
        }
    }
}

private enum ReviewFilter: String, CaseIterable, Identifiable {
    case all
    case live
    case dead

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: L10n.Review.Filter.all
        case .live: L10n.Review.Filter.live
        case .dead: L10n.Review.Filter.dead
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
        Canvas { ctx, _ in
            for item in labeled {
                let c = item.base.centroid
                let r: CGFloat = 6
                let rect = CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)
                let color: Color = item.label == "dead" ? .red : .green
                ctx.stroke(Path(ellipseIn: rect), with: .color(color), lineWidth: 2)
            }
        }
        .contentShape(Rectangle())
        .accessibilityHidden(true)
        .flipsForRightToLeftLayoutDirection(false)
        .overlay(
            ZStack {
                ForEach(labeled, id: \.id) { item in
                    Button(action: { onTap(item.id) }) { Color.clear }
                        .frame(width: 30, height: 30)
                        .position(item.base.centroid)
                        .accessibilityLabel(L10n.Review.detectionAccessibility(label: item.label))
                        .accessibilityHint(L10n.Review.detectionToggleHint)
                }
            }
        )
    }
}

private struct ReviewStatsView: View {
    let stats: ReviewViewModel.ReviewStats

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Review.statsTitle)
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            HStack(spacing: 12) {
                ReviewStatChip(
                    title: L10n.Review.liveTitle,
                    value: "\(stats.liveCount)",
                    systemImage: "heart.fill",
                    tint: Theme.success
                )
                ReviewStatChip(
                    title: L10n.Review.deadTitle,
                    value: "\(stats.deadCount)",
                    systemImage: "bandage.fill",
                    tint: Theme.danger
                )
                ReviewStatChip(
                    title: L10n.Review.averageTitle,
                    value: stats.formattedAverage,
                    systemImage: "function",
                    tint: Theme.accent
                )
                ReviewStatChip(
                    title: L10n.Review.outliersTitle,
                    value: "\(stats.outlierCount)",
                    systemImage: "exclamationmark.triangle",
                    tint: Theme.warning
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(L10n.Review.selectedSquares(stats.selectedSquareCount))
                .font(.footnote)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

private struct ReviewStatChip: View {
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label {
                Text(title)
                    .font(.caption)
            } icon: {
                Image(systemName: systemImage)
            }
            .foregroundColor(tint)
            Text(value)
                .font(.system(.title3, design: .rounded).weight(.semibold))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.Review.statAccessibility(title: title, value: value))
    }
}

private struct ReviewOverlayToggleBar: View {
    let options: [ReviewViewModel.OverlayOption]
    let states: [ReviewViewModel.OverlayOption: Bool]
    let availability: (ReviewViewModel.OverlayOption) -> Bool
    let toggle: (ReviewViewModel.OverlayOption) -> Void
    let undoAvailable: Bool
    let undoAction: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(options, id: \.self) { option in
                    let isEnabled = states[option, default: false]
                    let isAvailable = availability(option)
                    Button {
                        if isAvailable { toggle(option) }
                    } label: {
                        Label {
                            Text(option.title)
                        } icon: {
                            Image(systemName: option.iconName)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(isEnabled ? option.tint.opacity(0.25) : Theme.surface.opacity(0.4))
                        )
                        .foregroundColor(isAvailable ? (isEnabled ? option.tint : Theme.textPrimary) : Theme.textSecondary.opacity(0.6))
                    }
                    .buttonStyle(.plain)
                    .disabled(!isAvailable)
                    .accessibilityHint(L10n.Review.overlayToggleHint)
                    .accessibilityValue(L10n.Review.overlayValue(isEnabled: isEnabled))
                }

                if undoAvailable {
                    Button(action: undoAction) {
                        Label(L10n.Common.undo, systemImage: "arrow.uturn.backward.circle")
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface.opacity(0.5)))
                            .foregroundColor(Theme.accent)
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint(L10n.Review.undoHint)
                }
            }
        }
    }
}

private struct PerSquareTable: View {
    let tally: [Int: Int]
    let selected: Set<Int>
    var onToggle: (Int) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.Review.perSquareTitle)
                .font(.headline)
                .foregroundColor(Theme.textPrimary)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(0 ..< 9) { index in
                    let count = tally[index] ?? 0
                    let isSelected = selected.contains(index)
                    Button {
                        onToggle(index)
                    } label: {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(isSelected ? Theme.accent.opacity(0.25) : Theme.surface.opacity(0.8))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(isSelected ? Theme.accent : Theme.border.opacity(0.6), lineWidth: isSelected ? 2 : 1)
                                )
                            Text("\(count)")
                                .foregroundColor(Theme.textPrimary)
                        }
                        .frame(height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(L10n.Review.perSquareAccessibility(index: index, count: count, isSelected: isSelected))
                }
            }
        }
    }
}

private struct LassoConfirmationBanner: View {
    let count: Int
    let confirm: () -> Void
    let cancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(L10n.Review.lassoConfirmation(count))
                    .font(.subheadline)
            } icon: {
                Image(systemName: "scissors")
            }
            .foregroundColor(Theme.textPrimary)

            Spacer()

            Button(L10n.Common.cancel, action: cancel)
                .buttonStyle(.bordered)

            Button(L10n.Common.remove, action: confirm)
                .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L10n.Review.lassoConfirmation(count))
    }
}

private struct SegmentationMetadataView: View {
    let segmentation: SegmentationResult

    var body: some View {
        HStack(spacing: 12) {
            Label {
                Text(strategyText)
            } icon: {
                Image(systemName: "sparkles")
            }
            .font(.footnote)
            .foregroundColor(Theme.textSecondary)

            Label {
                Text(L10n.Detection.Segmentation.downscale(segmentation.downscaleFactor))
            } icon: {
                Image(systemName: "arrow.down.forward.and.arrow.up.backward")
            }
            .font(.footnote)
            .foregroundColor(Theme.textSecondary)

            Label {
                Text(polarityText)
            } icon: {
                Image(systemName: "circle.lefthalf.filled")
            }
            .font(.footnote)
            .foregroundColor(Theme.textSecondary)
        }
    }

    private var strategyText: String {
        switch segmentation.usedStrategy {
        case .automatic: L10n.Review.Segmentation.strategyAutomatic
        case .classical: L10n.Review.Segmentation.strategyClassical
        case .coreML: L10n.Review.Segmentation.strategyCoreML
        }
    }

    private var polarityText: String {
        segmentation.polarityInverted
            ? L10n.Review.Segmentation.polarityInverted
            : L10n.Review.Segmentation.polarityNormal
    }
}
