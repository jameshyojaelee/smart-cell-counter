import CoreGraphics
import Foundation

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

    enum Onboarding {
        static let skip = tr("Onboarding", "onboarding.skip")
        static let continueButton = tr("Onboarding", "onboarding.continue")
        static let getStarted = tr("Onboarding", "onboarding.get_started")
        static let continueHint = tr("Onboarding", "onboarding.continue.hint")
        static let finishHint = tr("Onboarding", "onboarding.finish.hint")

        static func stepTitle(_ index: Int) -> String {
            tr("Onboarding", "onboarding.step.title.\(index)")
        }

        static func stepMessage(_ index: Int) -> String {
            tr("Onboarding", "onboarding.step.message.\(index)")
        }

        static func pageIndicator(current: Int, total: Int) -> String {
            tr("Onboarding", "onboarding.page_indicator", "\(current)", "\(total)")
        }

        static func symbolAccessibility(_ index: Int) -> String {
            tr("Onboarding", "onboarding.symbol.accessibility.\(index)")
        }
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
        static let undo = tr("Common", "common.undo")
        static let cancel = tr("Common", "common.cancel")
        static let remove = tr("Common", "common.remove")
        static let next = tr("Common", "common.next")
    }

    enum Paywall {
        static let navigationTitle = tr("Paywall", "paywall.navigation.title")
        static let title = tr("Paywall", "paywall.title")
        static let subtitle = tr("Paywall", "paywall.subtitle")
        static let restore = tr("Paywall", "paywall.restore")
        static let continueFree = tr("Paywall", "paywall.continue_free")
        static let restoreHint = tr("Paywall", "paywall.restore.hint")
        static let continueHint = tr("Paywall", "paywall.continue.hint")
        static func buyTitle(_ price: String) -> String {
            tr("Paywall", "paywall.buy_price", price)
        }

        static let buyHint = tr("Paywall", "paywall.buy.hint")
        static let benefitsTitle = tr("Paywall", "paywall.section.benefits")
        static let comparisonTitle = tr("Paywall", "paywall.section.comparison")
        static let faqTitle = tr("Paywall", "paywall.faq.title")
        static let upgradeAction = tr("Paywall", "paywall.action.upgrade")

        enum Feature {
            static let noWatermark = tr("Paywall", "paywall.feature.no_watermark")
            static let advanced = tr("Paywall", "paywall.feature.advanced")
            static let mlRefine = tr("Paywall", "paywall.feature.ml_refine")
            static let adFree = tr("Paywall", "paywall.feature.ad_free")
        }

        enum Benefit {
            static let exports = tr("Paywall", "paywall.benefit.exports")
            static let recovery = tr("Paywall", "paywall.benefit.recovery")
            static let support = tr("Paywall", "paywall.benefit.support")
        }

        enum Comparison {
            static let free = tr("Paywall", "paywall.plan.free")
            static let pro = tr("Paywall", "paywall.plan.pro")
            static let advancedExports = tr("Paywall", "paywall.comparison.advanced_exports")
            static let detections = tr("Paywall", "paywall.comparison.detections")
            static let watermark = tr("Paywall", "paywall.comparison.watermark")
            static let ads = tr("Paywall", "paywall.comparison.ads")
            static let support = tr("Paywall", "paywall.comparison.support")
            static let valueIncluded = tr("Paywall", "paywall.comparison.value.included")
            static let valueLimited = tr("Paywall", "paywall.comparison.value.limited")
            static let valueNotAvailable = tr("Paywall", "paywall.comparison.value.not_available")
            static let valueRemoved = tr("Paywall", "paywall.comparison.value.removed")
        }

        enum FAQ {
            static let syncQuestion = tr("Paywall", "paywall.faq.sync.q")
            static let syncAnswer = tr("Paywall", "paywall.faq.sync.a")
            static let restoreQuestion = tr("Paywall", "paywall.faq.restore.q")
            static let restoreAnswer = tr("Paywall", "paywall.faq.restore.a")
            static let trialQuestion = tr("Paywall", "paywall.faq.trial.q")
            static let trialAnswer = tr("Paywall", "paywall.faq.trial.a")
        }

        #if DEBUG
            enum Debug {
                static let simulatePurchase = tr("Paywall", "paywall.debug.simulate_purchase")
                static let revokePurchase = tr("Paywall", "paywall.debug.revoke_purchase")
            }
        #endif
    }

    enum Consent {
        static let navigationTitle = tr("Consent", "consent.navigation.title")
        static let sectionTitle = tr("Consent", "consent.section.title")
        static let personalizedAds = tr("Consent", "consent.toggle.ads")
        static let crashReporting = tr("Consent", "consent.toggle.crash")
        static let analytics = tr("Consent", "consent.toggle.analytics")
        static let reminder = tr("Consent", "consent.reminder")
        static let continueButton = tr("Consent", "consent.continue")
        static let continueHint = tr("Consent", "consent.continue.hint")
    }

    enum Help {
        static let navigationTitle = tr("Help", "help.navigation.title")
        static let searchPrompt = tr("Help", "help.search.prompt")

        enum Section {
            static let faq = tr("Help", "help.section.faq")
            static let links = tr("Help", "help.section.links")
            static let videos = tr("Help", "help.section.videos")
        }

        enum Topic {
            static func category(_ id: Int) -> String { tr("Help", "help.topic.\(id).category") }
            static func question(_ id: Int) -> String { tr("Help", "help.topic.\(id).question") }
            static func answer(_ id: Int) -> String { tr("Help", "help.topic.\(id).answer") }
            static func tags(_ id: Int) -> [String] {
                let raw = tr("Help", "help.topic.\(id).tags")
                return raw.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            }
        }

        enum Link {
            static func title(_ id: Int) -> String { tr("Help", "help.link.\(id).title") }
            static func hint(_ id: Int) -> String { tr("Help", "help.link.\(id).hint") }
        }

        enum Video {
            static func title(_ id: Int) -> String { tr("Help", "help.video.\(id).title") }
            static func description(_ id: Int) -> String { tr("Help", "help.video.\(id).description") }
        }

        static let videoThumbnailAccessibility = tr("Help", "help.video.thumbnail.accessibility")
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

        enum About {
            static let screenTitle = tr("Settings", "settings.about.title")
            static let appName = tr("Settings", "settings.about.app_name")
            static func version(_ value: String) -> String {
                tr("Settings", "settings.about.version", value)
            }

            static let noticeTitle = tr("Settings", "settings.about.notice.title")
            static let noticeDevelopment = tr("Settings", "settings.about.notice.development")
            static let noticeResearch = tr("Settings", "settings.about.notice.research")
            static let privacyTitle = tr("Settings", "settings.about.privacy.title")
            static let privacyBody = tr("Settings", "settings.about.privacy.body")
            static let licensesTitle = tr("Settings", "settings.about.licenses.title")
            static let licenseGRDB = tr("Settings", "settings.about.licenses.grdb")
            static let licenseGMA = tr("Settings", "settings.about.licenses.gma")
            static let licenseApple = tr("Settings", "settings.about.licenses.apple")
            static let contactTitle = tr("Settings", "settings.about.contact.title")
            static let contactSupport = tr("Settings", "settings.about.contact.support")
            static let contactPrivacy = tr("Settings", "settings.about.contact.privacy")
            static let contactEmail = tr("Settings", "settings.about.contact.email")
        }
    }

    enum Results {
        static let navigationTitle = tr("Results", "results.navigation.title")
        static let headerTitle = tr("Results", "results.header.title")
        static let headerSubtitle = tr("Results", "results.header.subtitle")
        static let viabilityTitle = tr("Results", "results.stat.viability.title")
        static let concentrationTitle = tr("Results", "results.stat.concentration.title")
        static let liveDeadTitle = tr("Results", "results.stat.live_dead.title")
        static let squaresUsed = tr("Results", "results.squares_used")
        static let selectedSquares = tr("Results", "results.selected_squares")
        static let dilution = tr("Results", "results.dilution")
        static let concentrationFAQ = tr("Results", "results.faq.concentration.question")
        static let concentrationExplanation = tr("Results", "results.faq.concentration.answer")
        static let viabilityFAQ = tr("Results", "results.faq.viability.question")
        static let viabilityExplanation = tr("Results", "results.faq.viability.answer")
        static let qcLowFocus = tr("Results", "results.qc.low_focus")
        static let qcHighGlare = tr("Results", "results.qc.high_glare")
        static let qcOvercrowded = tr("Results", "results.qc.overcrowded")
        static let exportCSV = tr("Results", "results.action.export_csv")
        static let exportDetectionsCSV = tr("Results", "results.action.export_detections")
        static let share = tr("Results", "results.action.share")
        static let saveSample = tr("Results", "results.action.save_sample")
        static let exportPDF = tr("Results", "results.action.export_pdf")
        static let saveImage = tr("Results", "results.action.save_image")
        static let exportCSVHint = tr("Results", "results.action.export_csv.hint")
        static let exportDetectionsHint = tr("Results", "results.action.export_detections.hint")
        static let shareHint = tr("Results", "results.action.share.hint")
        static let saveSampleHint = tr("Results", "results.action.save_sample.hint")
        static let exportPDFHint = tr("Results", "results.action.export_pdf.hint")
        static let saveImageHint = tr("Results", "results.action.save_image.hint")

        static func viabilityValue(_ percent: Double) -> String {
            guard percent.isFinite else { return "--" }
            let value = NSNumber(value: percent / 100.0)
            return percentFormatter.string(from: value) ?? "--"
        }

        static func concentrationValue(_ value: Double) -> String {
            guard value.isFinite else { return "--" }
            let formatted = concentrationFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.3e", value)
            return tr("Results", "results.stat.concentration.value", formatted)
        }

        static func concentrationNumeric(_ value: Double) -> String {
            guard value.isFinite else { return "--" }
            return concentrationFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.3e", value)
        }

        static func liveDeadValue(live: Int, dead: Int) -> String {
            tr("Results", "results.stat.live_dead.value", countValue(live), countValue(dead))
        }

        static func countValue(_ count: Int) -> String {
            integerFormatter.string(from: NSNumber(value: count)) ?? "\(count)"
        }

        static func dilutionValue(_ value: Double) -> String {
            let number = dilutionFormatter.string(from: NSNumber(value: value)) ?? String(format: "%.1f", value)
            return tr("Results", "results.dilution.value", number)
        }

        static func viabilityNumeric(_ percent: Double) -> String {
            guard percent.isFinite else { return "--" }
            return numericPercentFormatter.string(from: NSNumber(value: percent)) ?? String(format: "%.1f", percent)
        }

        static func selectedSquaresList(_ indices: [Int]) -> String {
            let formatted = indices.map { countValue($0) }
            return formatted.joined(separator: ", ")
        }

        enum CSV {
            static var summaryHeaders: [String] {
                [
                    tr("Results", "results.csv.header.sample_id"),
                    tr("Results", "results.csv.header.timestamp"),
                    tr("Results", "results.csv.header.concentration"),
                    tr("Results", "results.csv.header.viability"),
                    tr("Results", "results.csv.header.live"),
                    tr("Results", "results.csv.header.dead"),
                ]
            }

            static var detailedHeaders: [String] {
                [
                    tr("Results", "results.csv.header.sample_id"),
                    tr("Results", "results.csv.header.timestamp"),
                    tr("Results", "results.csv.detailed.operator"),
                    tr("Results", "results.csv.detailed.project"),
                    tr("Results", "results.csv.detailed.lab"),
                    tr("Results", "results.csv.detailed.stain"),
                    tr("Results", "results.csv.header.concentration"),
                    tr("Results", "results.csv.header.viability"),
                    tr("Results", "results.csv.header.live"),
                    tr("Results", "results.csv.header.dead"),
                    tr("Results", "results.csv.detailed.dilution"),
                ]
            }

            enum Metadata {
                static let lab = tr("Results", "results.csv.metadata.lab")
                static let stain = tr("Results", "results.csv.metadata.stain")
                static let dilution = tr("Results", "results.csv.metadata.dilution")
            }

            static var detectionsHeaders: [String] {
                [
                    tr("Results", "results.csv.detections.sample_id"),
                    tr("Results", "results.csv.detections.object_id"),
                    tr("Results", "results.csv.detections.x"),
                    tr("Results", "results.csv.detections.y"),
                    tr("Results", "results.csv.detections.area"),
                    tr("Results", "results.csv.detections.circularity"),
                    tr("Results", "results.csv.detections.solidity"),
                    tr("Results", "results.csv.detections.label"),
                    tr("Results", "results.csv.detections.confidence"),
                ]
            }

            static let filename = tr("Results", "results.csv.filename")
            static let summaryFilename = tr("Results", "results.csv.summary.filename")
            static let detectionsFilename = tr("Results", "results.csv.detections.filename")
        }

        enum Export {
            static let preparing = tr("Results", "results.export.progress.preparing")
            static let writing = tr("Results", "results.export.progress.writing")
            static let finishing = tr("Results", "results.export.progress.finishing")
            static let historyTitle = tr("Results", "results.export.history.title")
            static let historyEmpty = tr("Results", "results.export.history.empty")
            static let permissionDenied = tr("Results", "results.export.permissionDenied")
            static let errorTitle = tr("Results", "results.export.error.title")
            static let errorGeneric = tr("Results", "results.export.error.generic")
            static let dismiss = tr("Results", "results.export.dismiss")
            static let lockedTitle = tr("Results", "results.export.lockedTitle")
            static func proRequired(_ feature: String) -> String {
                tr("Results", "results.export.pro_required", feature)
            }

            static let upgrade = tr("Results", "results.export.upgrade")
        }

        private static let percentFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .percent
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            return formatter
        }()

        private static let concentrationFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .scientific
            formatter.maximumFractionDigits = 3
            formatter.exponentSymbol = "e"
            return formatter
        }()

        private static let integerFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            return formatter
        }()

        private static let dilutionFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 1
            return formatter
        }()

        private static let numericPercentFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 1
            formatter.minimumFractionDigits = 0
            return formatter
        }()
    }

    enum ReviewStrings {
        static let navigationTitle = tr("Review", "review.navigation.title")
        static let computing = tr("Review", "review.computing")
        static let emptyState = tr("Review", "review.empty_state")
        static let recompute = tr("Review", "review.recompute")
        static let recomputeHint = tr("Review", "review.recompute.hint")
        static let nextHint = tr("Review", "review.next.hint")
        static let perSquareTitle = tr("Review", "review.per_square.title")
        static let statsTitle = tr("Review", "review.stats.title")
        static let liveTitle = tr("Review", "review.stats.live")
        static let deadTitle = tr("Review", "review.stats.dead")
        static let averageTitle = tr("Review", "review.stats.average")
        static let outliersTitle = tr("Review", "review.stats.outliers")
        static let filterLabel = tr("Review", "review.filter.label")

        static func selectedSquares(_ count: Int) -> String {
            tr("Review", "review.stats.selected_squares", "\(count)")
        }

        static func lassoConfirmation(_ count: Int) -> String {
            tr("Review", "review.lasso.confirmation", "\(count)")
        }

        static func perSquareAccessibility(index: Int, count: Int, isSelected: Bool) -> String {
            tr(
                "Review",
                "review.per_square.accessibility",
                "\(index + 1)",
                "\(count)",
                isSelected ? tr("Review", "review.per_square.selected") : tr("Review", "review.per_square.not_selected")
            )
        }

        static func statAccessibility(title: String, value: String) -> String {
            tr("Review", "review.stats.accessibility", title, value)
        }

        static let overlayToggleHint = tr("Review", "review.overlay.toggle_hint")
        static func overlayValue(isEnabled: Bool) -> String {
            isEnabled ? tr("Review", "review.overlay.on") : tr("Review", "review.overlay.off")
        }

        static let undoHint = tr("Review", "review.undo.hint")
        static let detectionToggleHint = tr("Review", "review.detection.toggle_hint")

        static func cellLabel(for label: String) -> String {
            label == "dead" ? tr("Review", "review.cell.dead") : tr("Review", "review.cell.live")
        }

        static func detectionAccessibility(label: String) -> String {
            tr("Review", "review.detection.accessibility", cellLabel(for: label))
        }

        static let imageAccessibility = tr("Review", "review.image.accessibility")

        enum Overlay {
            static let detections = tr("Review", "review.overlay.detections")
            static let segmentationMask = tr("Review", "review.overlay.segmentation_mask")
            static let blueMask = tr("Review", "review.overlay.blue_mask")
            static let gridMask = tr("Review", "review.overlay.grid_mask")
            static let candidates = tr("Review", "review.overlay.candidates")
            static let tallies = tr("Review", "review.overlay.tallies")
        }

        enum Filter {
            static let all = tr("Review", "review.filter.all")
            static let live = tr("Review", "review.filter.live")
            static let dead = tr("Review", "review.filter.dead")
            static let label = tr("Review", "review.filter.label")
        }

        enum Segmentation {
            static let strategyAutomatic = tr("Review", "review.segmentation.strategy.automatic")
            static let strategyClassical = tr("Review", "review.segmentation.strategy.classical")
            static let strategyCoreML = tr("Review", "review.segmentation.strategy.coreml")
            static let polarityInverted = tr("Review", "review.segmentation.polarity.inverted")
            static let polarityNormal = tr("Review", "review.segmentation.polarity.normal")
        }
    }

    enum Debug {
        static let navigationTitle = tr("Debug", "debug.navigation.title")
        static let performanceTitle = tr("Debug", "debug.performance.title")
        static let timingsDescription = tr("Debug", "debug.timings.description")
        static let qaFixtures = tr("Debug", "debug.qa_fixtures")
        static let qaTitle = tr("Debug", "debug.qa.title")
        static let runAll = tr("Debug", "debug.qa.run_all")
        static let running = tr("Debug", "debug.qa.running")
        static let missing = tr("Debug", "debug.qa.missing")
        static let countMissing = tr("Debug", "debug.qa.count_missing")

        static func count(_ value: Int) -> String {
            tr("Debug", "debug.qa.count", L10n.Results.countValue(value))
        }

        static func elapsed(_ ms: Double) -> String {
            let formatted = Debug.timeFormatter.string(from: NSNumber(value: ms)) ?? String(format: "%.0f", ms)
            return tr("Debug", "debug.qa.elapsed", formatted)
        }

        private static let timeFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            formatter.minimumFractionDigits = 0
            return formatter
        }()
    }

    typealias Review = ReviewStrings
}
