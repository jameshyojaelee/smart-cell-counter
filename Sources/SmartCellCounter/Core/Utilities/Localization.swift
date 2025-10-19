import Foundation
import CoreGraphics

enum L10n {
    /// Centralized translation helper modeled after SwiftGen output.
    /// - Parameters:
    ///   - table: The .strings filename (without extension).
    ///   - key: The localization key.
    ///   - args: Arguments applied to the localized format string.
    /// - Returns: The localized string for the current bundle and locale.
    static func tr(_ table: String, _ key: String, _ args: CVarArg...) -> String {
        let format = NSLocalizedString(key, tableName: table, bundle: .main, comment: "")
        guard args.isEmpty else {
            return String(format: format, locale: Locale.current, arguments: args)
        }
        return format
    }

    enum App {
        static let captureTab = tr("App", "tab.capture.title")
        static let historyTab = tr("App", "tab.history.title")
        static let resultsTab = tr("App", "tab.results.title")
        static let settingsTab = tr("App", "tab.settings.title")
    }

    enum Capture {
        static let navigationTitle = tr("Capture", "capture.navigation.title")
        static let gridShow = tr("Capture", "capture.grid.toggle.show")
        static let gridHide = tr("Capture", "capture.grid.toggle.hide")
        static let gridToggleHint = tr("Capture", "capture.grid.toggle.hint")
        static let gridVisibleValue = tr("Capture", "capture.grid.toggle.visible")
        static let gridHiddenValue = tr("Capture", "capture.grid.toggle.hidden")
        static let cameraPreviewLabel = tr("Capture", "capture.preview.label")
        static let cameraPreviewHint = tr("Capture", "capture.preview.hint")
        static let permissionDisabledTitle = tr("Capture", "capture.permission.disabled.title")
        static let importLabel = tr("Capture", "capture.import.label")
        static let importHint = tr("Capture", "capture.import.hint")
        static let shutterLabel = tr("Capture", "capture.shutter.label")
        static let shutterHintReady = tr("Capture", "capture.shutter.hint.ready")
        static let shutterHintNotReady = tr("Capture", "capture.shutter.hint.not_ready")
        static let shutterValueReady = tr("Capture", "capture.shutter.value.ready")
        static let shutterValueNotReady = tr("Capture", "capture.shutter.value.not_ready")
        static let settingsLabel = tr("Capture", "capture.settings.label")
        static let settingsHint = tr("Capture", "capture.settings.hint")
        static let torchTitle = tr("Capture", "capture.torch.title")
        static let torchHint = tr("Capture", "capture.torch.hint")
        static let torchTurnOn = tr("Capture", "capture.torch.toggle.on")
        static let torchTurnOff = tr("Capture", "capture.torch.toggle.off")
        static let focusMetricTitle = tr("Capture", "capture.metric.focus.title")
        static let glareMetricTitle = tr("Capture", "capture.metric.glare.title")
        static let permissionExplanation = tr("Capture", "capture.permission.explanation")
        static let openSettings = tr("Capture", "capture.permission.open_settings")
        static let openSettingsHint = tr("Capture", "capture.permission.open_settings.hint")

        enum Status {
            static let preparing = tr("Capture", "capture.status.preparing")
            static let requesting = tr("Capture", "capture.status.requesting")
            static let denied = tr("Capture", "capture.status.denied")
            static let unavailable = tr("Capture", "capture.status.unavailable")
            static let ready = tr("Capture", "capture.status.ready")
            static let saving = tr("Capture", "capture.status.saving")
            static let focusing = tr("Capture", "capture.status.focusing")
            static let idle = tr("Capture", "capture.status.idle")
            static let capturing = tr("Capture", "capture.status.capturing")
            static let genericError = tr("Capture", "capture.status.error")
        }

        static func gridToggleLabel(isVisible: Bool) -> String {
            isVisible ? gridHide : gridShow
        }

        static func gridToggleValue(isVisible: Bool) -> String {
            isVisible ? gridVisibleValue : gridHiddenValue
        }

        static func shutterHint(isReady: Bool) -> String {
            isReady ? shutterHintReady : shutterHintNotReady
        }

        static func shutterValue(isReady: Bool) -> String {
            isReady ? shutterValueReady : shutterValueNotReady
        }

        static func torchToggleLabel(isOn: Bool) -> String {
            isOn ? torchTurnOff : torchTurnOn
        }

        static func focusMetricAccessibility(_ value: String) -> String {
            tr("Capture", "capture.metric.focus.value", value)
        }

        static func glareMetricAccessibility(_ value: String) -> String {
            tr("Capture", "capture.metric.glare.value", value)
        }

        static let framingHint = tr("Capture", "capture.framing.hint")
    }

    enum History {
        static let navigationTitle = tr("History", "history.navigation.title")
        static let searchPrompt = tr("History", "history.search.prompt")
        static let emptyState = tr("History", "history.empty_state")
        static func summary(live: Int, dead: Int) -> String {
            tr("History", "history.summary", "\(live)", "\(dead)")
        }

        static func accessibilitySummary(date: String, live: Int, dead: Int, concentration: String) -> String {
            tr("History", "history.accessibility.summary", date, "\(live)", "\(dead)", concentration)
        }
    }

    enum Selection {
        static let instructions = tr("Selection", "selection.instructions")
        static let widthLabel = tr("Selection", "selection.width.label")
        static let heightLabel = tr("Selection", "selection.height.label")
        static let areaLabel = tr("Selection", "selection.area.label")
        static let confirmButton = tr("Selection", "selection.confirm.button")
        static let overlayLabel = tr("Selection", "selection.overlay.label")
        static let overlayHint = tr("Selection", "selection.overlay.hint")
        static let handleLabel = tr("Selection", "selection.handle.label")
        static let undoLabel = tr("Selection", "selection.undo.label")
        static let undoHint = tr("Selection", "selection.undo.hint")
        static func sizeValue(_ value: CGFloat) -> String {
            let number = formatter.string(from: NSNumber(value: Double(value))) ?? String(format: "%.0f", value)
            return tr("Selection", "selection.value.format", number)
        }
        static func areaValue(width: CGFloat, height: CGFloat) -> String {
            let area = formatter.string(from: NSNumber(value: Double(width * height))) ?? String(format: "%.0f", width * height)
            return tr("Selection", "selection.area.value", area)
        }

        private static let formatter: NumberFormatter = {
            let nf = NumberFormatter()
            nf.numberStyle = .decimal
            nf.maximumFractionDigits = 0
            return nf
        }()
    }

    enum Crop {
        static let navigationTitle = tr("Crop", "crop.navigation.title")
        static let noImage = tr("Crop", "crop.no_image")
    }

    enum Detection {
        static let navigationTitle = tr("Detection", "detection.navigation.title")
        static let toggleLabel = tr("Detection", "detection.toggle.label")
        static let toggleHint = tr("Detection", "detection.toggle.hint")
        static let toggleValueVisible = tr("Detection", "detection.toggle.value.visible")
        static let toggleValueHidden = tr("Detection", "detection.toggle.value.hidden")
        static let pickerLabel = tr("Detection", "detection.picker.label")
        static let emptyState = tr("Detection", "detection.empty_state")

        static func toggleValue(isVisible: Bool) -> String {
            isVisible ? toggleValueVisible : toggleValueHidden
        }

        enum Overlay {
            static let candidates = tr("Detection", "detection.overlay.candidates")
            static let blueMask = tr("Detection", "detection.overlay.blue_mask")
            static let gridMask = tr("Detection", "detection.overlay.grid_mask")
            static let illumination = tr("Detection", "detection.overlay.illumination")
            static let segmentationMask = tr("Detection", "detection.overlay.segmentation_mask")
            static let segmentationInfo = tr("Detection", "detection.overlay.segmentation_info")
        }

        enum Segmentation {
            static let heading = tr("Detection", "detection.segmentation.heading")
            static func strategy(_ value: String) -> String {
                tr("Detection", "detection.segmentation.strategy", value)
            }
            static func downscale(_ factor: Double) -> String {
                tr("Detection", "detection.segmentation.downscale", String(format: "%.2f", factor))
            }
            static func polarity(_ inverted: Bool) -> String {
                tr("Detection", "detection.segmentation.polarity", inverted ? Common.yes : Common.no)
            }
            static func resolution(width: Int, height: Int, originalWidth: Int, originalHeight: Int) -> String {
                tr("Detection", "detection.segmentation.resolution", "\(width)", "\(height)", "\(originalWidth)", "\(originalHeight)")
            }
        }
    }

    enum Common {
        static let yes = tr("Common", "common.yes")
        static let no = tr("Common", "common.no")
    }

    enum Settings {
        static let navigationTitle = tr("Settings", "settings.navigation.title")

        enum Section {
            static let general = tr("Settings", "settings.section.general")
            static let detectionRanges = tr("Settings", "settings.section.detection_ranges")
            static let cellSize = tr("Settings", "settings.section.cell_size")
            static let segmentation = tr("Settings", "settings.section.segmentation")
            static let blueClassification = tr("Settings", "settings.section.blue_classification")
            static let detectionThresholds = tr("Settings", "settings.section.detection_thresholds")
            static let more = tr("Settings", "settings.section.more")
        }

        enum Field {
            static let dilution = tr("Settings", "settings.field.dilution")
            static let areaMin = tr("Settings", "settings.field.area_min")
            static let areaMax = tr("Settings", "settings.field.area_max")
            static let minDiameter = tr("Settings", "settings.field.min_diameter")
            static let maxDiameter = tr("Settings", "settings.field.max_diameter")
            static let hueMin = tr("Settings", "settings.field.hue_min")
            static let hueMax = tr("Settings", "settings.field.hue_max")
            static let minSaturation = tr("Settings", "settings.field.min_saturation")
            static let blobScoreThreshold = tr("Settings", "settings.field.blob_score_threshold")
            static let nmsIoU = tr("Settings", "settings.field.nms_iou")
            static let minFocus = tr("Settings", "settings.field.min_focus")
        }

        enum Picker {
            static let strategy = tr("Settings", "settings.picker.strategy")
            static let threshold = tr("Settings", "settings.picker.threshold")
        }

        enum SegmentationStrategy {
            static let automatic = tr("Settings", "settings.segmentation.strategy.automatic")
            static let classical = tr("Settings", "settings.segmentation.strategy.classical")
            static let coreML = tr("Settings", "settings.segmentation.strategy.coreml")
        }

        enum ThresholdMethod {
            static let adaptive = tr("Settings", "settings.threshold.method.adaptive")
            static let otsu = tr("Settings", "settings.threshold.method.otsu")
        }

        enum Segmentation {
            static let coreMLFallback = tr("Settings", "settings.segmentation.coreml_fallback")
            static func blockSize(_ value: Int) -> String {
                tr("Settings", "settings.segmentation.block_size", "\(value)")
            }
            static func thresholdC(_ value: Int) -> String {
                tr("Settings", "settings.segmentation.threshold_c", "\(value)")
            }
        }

        enum Toggle {
            static let gridSuppression = tr("Settings", "settings.toggle.grid_suppression")
        }

        enum Button {
            static let resetDefaults = tr("Settings", "settings.button.reset_defaults")
            static let resetOnboarding = tr("Settings", "settings.button.reset_onboarding")
            static let help = tr("Settings", "settings.button.help")
            static let debug = tr("Settings", "settings.button.debug")
            static let about = tr("Settings", "settings.button.about")
        }

        enum Validation {
            static let invalidNumber = tr("Settings", "settings.validation.invalid_number")
            static func clamped(_ value: Double) -> String {
                let formatted = NumberFormatter.localizedString(from: NSNumber(value: value), number: .decimal)
                return tr("Settings", "settings.validation.clamped", formatted)
            }
        }
    }
}
