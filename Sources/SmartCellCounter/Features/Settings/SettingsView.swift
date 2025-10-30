import SwiftUI

struct SettingsView: View {
    @StateObject private var store = SettingsStore.shared
    @State private var validationMessage: String = ""
    @AppStorage("onboarding.completed") private var onboardingCompleted: Bool = false

    var body: some View {
        List {
            Section(header: Text(L10n.Settings.Section.general)) {
                NumericField(L10n.Settings.Field.dilution, value: $store.dilutionFactor, range: 0.1 ... 100, step: 0.1) { msg in validationMessage = msg }
                if !validationMessage.isEmpty {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundColor(.orange)
                        .accessibilityLabel(validationMessage)
                }
            }

            Section(header: Text(L10n.Settings.Section.detectionRanges)) {
                NumericField(L10n.Settings.Field.areaMin, value: $store.areaMinUm2, range: 1 ... 1_000_000, step: 10) { msg in validationMessage = msg }
                NumericField(L10n.Settings.Field.areaMax, value: $store.areaMaxUm2, range: 1 ... 1_000_000, step: 50) { msg in validationMessage = msg }
            }

            Section(header: Text(L10n.Settings.Section.cellSize)) {
                NumericField(L10n.Settings.Field.minDiameter, value: $store.minCellDiameterUm, range: 1 ... 200, step: 0.5) { msg in validationMessage = msg }
                NumericField(L10n.Settings.Field.maxDiameter, value: $store.maxCellDiameterUm, range: 1 ... 200, step: 0.5) { msg in validationMessage = msg }
            }

            Section(header: Text(L10n.Settings.Section.segmentation)) {
                Picker(L10n.Settings.Picker.strategy, selection: $store.segmentationStrategy) {
                    Text(L10n.Settings.SegmentationStrategy.automatic).tag(SegmentationStrategy.automatic)
                    Text(L10n.Settings.SegmentationStrategy.classical).tag(SegmentationStrategy.classical)
                    Text(L10n.Settings.SegmentationStrategy.coreML).tag(SegmentationStrategy.coreML)
                }
                .pickerStyle(.segmented)
                .accessibilityLabel(L10n.Settings.Picker.strategy)
                if store.segmentationStrategy == .coreML && !ImagingPipeline.isCoreMLSegmentationAvailable {
                    Text(L10n.Settings.Segmentation.coreMLFallback)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                Picker(L10n.Settings.Picker.threshold, selection: $store.thresholdMethod) {
                    Text(L10n.Settings.ThresholdMethod.adaptive).tag(ThresholdMethod.adaptive)
                    Text(L10n.Settings.ThresholdMethod.otsu).tag(ThresholdMethod.otsu)
                }
                Stepper(L10n.Settings.Segmentation.blockSize(store.blockSize), value: $store.blockSize, in: 31 ... 101, step: 2)
                Stepper(L10n.Settings.Segmentation.thresholdC(store.thresholdC), value: $store.thresholdC, in: -10 ... 10, step: 1)
            }

            Section(header: Text(L10n.Settings.Section.blueClassification)) {
                NumericField(L10n.Settings.Field.hueMin, value: $store.blueHueMin, range: 0 ... 360, step: 1) { msg in validationMessage = msg }
                NumericField(L10n.Settings.Field.hueMax, value: $store.blueHueMax, range: 0 ... 360, step: 1) { msg in validationMessage = msg }
                NumericField(L10n.Settings.Field.minSaturation, value: $store.minBlueSaturation, range: 0 ... 1, step: 0.05) { msg in validationMessage = msg }
            }

            Section(header: Text(L10n.Settings.Section.detectionThresholds)) {
                NumericField(L10n.Settings.Field.blobScoreThreshold, value: $store.blobScoreThreshold, range: 0 ... 1, step: 0.05) { msg in validationMessage = msg }
                NumericField(L10n.Settings.Field.nmsIoU, value: $store.nmsIoU, range: 0 ... 1, step: 0.05) { msg in validationMessage = msg }
                NumericField(L10n.Settings.Field.minFocus, value: $store.focusMinLaplacian, range: 0 ... 10000, step: 10) { msg in validationMessage = msg }
                Toggle(L10n.Settings.Toggle.gridSuppression, isOn: $store.enableGridSuppression)
            }

            Section {
                Button(L10n.Settings.Button.resetDefaults) { store.reset(); validationMessage = "" }
                    .foregroundColor(.red)
            }

            Section(header: Text(L10n.Settings.Section.more)) {
                NavigationLink(L10n.Settings.Button.help, destination: HelpView())
                NavigationLink(L10n.Settings.Button.debug, destination: DebugView())
                NavigationLink(L10n.Settings.Button.about, destination: AboutView())
                Button(L10n.Settings.Button.resetOnboarding) {
                    onboardingCompleted = false
                }
                .foregroundColor(.orange)
            }
        }
        .navigationTitle(L10n.Settings.navigationTitle)
        .appBackground()
    }
}
