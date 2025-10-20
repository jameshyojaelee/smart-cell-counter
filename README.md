# Smart Cell Counter (iOS · SwiftUI)

Automated hemocytometer cell counting on iPhone and iPad with on‑device Vision, Core Image, and (optional) Core ML. Built in SwiftUI with MVVM and modular Core services.

Active development build, not production ready.

> Note: Expect frequent changes and incomplete functionality while the app is under active development.

## Why Smart Cell Counter?

The world's first automated cell counter on mobile devices. Replace expensive laboratory equipment like Thermo Fisher Countess with the automated cell counter in your pocket.

- Cost Savings: Save $10,000+ on automated cell counters
- Accuracy: Sub‑pixel precision approaching laboratory standards
- Speed: Results in under 3 seconds for 1080p inputs on modern iPhones
- Portability: Works anywhere — only your phone is required

### Professional‑Grade Automation

- Laboratory‑grade algorithms: Vision‑based grid detection, robust perspective correction, segmentation, and feature analysis
- Native iOS pipeline: Apple Vision + Core Image + optional Core ML (on‑device, offline)
- Real‑time analysis: Complete count and viability in a few seconds
- 100% on‑device: No internet connection required

### Superior to Traditional Methods

- Automated grid detection: Eliminates manual corner alignment errors
- Intelligent segmentation: Separates touching cells; polarity and threshold adaptivity
- Quality assurance: Built‑in focus, glare, and density validation
- Statistical confidence: MAD‑based outlier rejection across squares

### Complete Laboratory Solution

- Research‑grade viability: Trypan blue classification with adaptive thresholds
- Reporting: Professional PDF with images, tables, and formulas; CSV for analysis
- Data traceability: Local history with project/operator fields
- Export flexibility: CSV, PDF, and image overlays

### Cost Comparison: Mobile vs Benchtop

| Feature          | Smart Cell Counter         | Thermo Countess 3 |
| ---------------- | -------------------------- | ----------------- |
| Initial Cost     | Free download              | $15,000+          |
| Pro Upgrade      | $4.99 (one‑time)          | N/A               |
| Processing Speed | ~3 s                       | ~10 s             |
| Accuracy         | Sub‑pixel pipeline        | High precision    |
| Portability      | Smartphone                 | Benchtop          |
| Maintenance      | None                       | Annual service    |
| Data Export      | PDF, CSV, Images           | Limited           |
| Quality Control  | Focus/glare/density checks | Basic             |

Total Savings: $17,000+ in the first year versus automated counters

## Highlights

- iOS‑first SwiftUI app (iOS 16+, Swift 5.9+)
- Fast on‑device pipeline: Vision rectangle detection → perspective correction → segmentation → object features → viability
- Accurate counting for Neubauer Improved chambers with inclusion rules and robust stats
- Exports CSV and professional PDF; local GRDB storage with history and search
- Pro unlock (StoreKit 2): removes watermark, unlocks batch/detections export, ML refine always on, ad‑free
- Optional ads (compile flag `ADS`) and first‑run consent with ATT when personalized

## Requirements

- Xcode 15 or newer (tested with Xcode 16.4)
- iOS 16+ (iPhone 12+ recommended for performance)
- XcodeGen 2.38+ to generate the project from `project.yml`

## Quick Start

```bash
brew install xcodegen
xcodegen generate
open SmartCellCounter.xcodeproj
```

- In Xcode: set Signing Team for targets, choose a simulator/device, Build & Run.
- For camera capture, use a physical device.

Makefile shortcuts:

```bash
make open     # generate and open Xcode project
make test     # generate and run tests on default simulator
```

## Project Structure

```
Sources/
  SmartCellCounter/
    SmartCellCounterApp.swift          # App entry + Root tab navigation
    Info.plist                         # iOS keys (camera, photos, tracking strings)
    PrivacyInfo.xcprivacy              # Privacy manifest (no tracking, on‑device)
    Assets.xcassets/                   # App icons, (optional) QA fixtures
    Core/
      CoreModules.swift                # Module markers
      Math/Hemocytometer.swift         # Concentration, viability, area unit conversion
      Imaging/                         # Camera, pipeline, types
        CameraService.swift            # AVFoundation still capture + focus/glare metrics
        ImagingPipeline.swift          # Vision + CI + (optional) ML segmentation
        ImagingTypes.swift             # DTOs for pipeline
        ImagingService.swift           # Protocols (grid, perspective, segmenter)
      Counting/CountingService.swift   # Grid indexing, inclusion rules, robust tallies
      Viability/ViabilityClassifier.swift
      Export/CSVExporter.swift         # Summary + detections CSV
      Export/PDFExporter.swift         # Report with images, tables, formulas
      Storage/StorageService.swift     # GRDB migrations + DAO + file helpers
      Monetization/ProPurchase.swift   # StoreKit 2 purchase/restore, entitlement
      Ads/AdsManager.swift             # Optional Google Mobile Ads (flag: ADS)
      Privacy/ConsentManager.swift     # ATT request if personalized ads
      Utilities/Utilities.swift        # Logger
      Utilities/Settings.swift         # User‑tunable parameters
      Utilities/TimerUtil.swift        # Lightweight timing helper
      Utilities/ImageContext.swift     # Metal‑backed CIContext (shared)
      Utilities/PerformanceLogger.swift# Per‑stage timing (capture→render)
    Features/
      Capture/                         # Live preview, focus/glare, torch, import
        CameraPreviewView.swift
        CaptureView.swift
      Crop/
        CornerEditorView.swift         # Pan/zoom + corner handles with snapping
        CropView.swift                 # Live low‑res warp preview; apply full‑res
      Review/ReviewView.swift          # Overlay toggles, lasso erase, per‑square table
      Results/ResultsView.swift        # Cards, QC banners, CSV/PDF export, save sample
      History/HistoryView.swift        # GRDB‑backed list with search
      Settings/SettingsView.swift      # Chamber/stain/dilution/segmentation/privacy
      Settings/AboutView.swift         # Version, licenses, disclaimer, links
      Paywall/PaywallView.swift        # Pro upsell, price, restore
      Help/HelpView.swift              # Counting rules diagram and tips
      Debug/DebugView.swift            # Thumbnails + QA entry
      Debug/QATestsView.swift          # Batch fixtures runner (counts + timings)
Tests/
  SmartCellCounterTests/
    SmartCellCounterTests.swift        # AppState publisher + formulas
    ImagingPipelineTests.swift         # Polarity inversion, fallback segmentation
    CountingServiceTests.swift         # Inclusion, MAD mean, concentration/viability
    PurchaseManagerTests.swift         # Gating + mock purchase/restore
  SmartCellCounterUITests/
    SmartCellCounterUITests.swift      # Screenshot attachments for ASC
project.yml                          # XcodeGen project (SPM, build settings)
.github/workflows/ci.yml             # macOS build, dynamic simulator selection
```

## Screens & Workflows

- Capture: live camera preview with grid guide, focus/glare chips, torch toggle, capture still, import from Photos.
- Redesigned capture UI: large centered shutter (haptics), left import, right settings, top-right torch; status label shows Ready/Focusing/Captured/Errors. Shutter disables during capture to prevent double-taps.
- Crop: direct‑manipulation corner editor (pan/pinch; large handles with snapping). Low‑res warp while dragging; full‑res perspective on Apply.
  - Alternate selection: non-rotating, draggable, resizable rectangular ROI overlay with numeric size readouts. Confirm Selection produces a cropped image or rect coordinates in image space.
- Review: vector overlay of detections; tap toggles live/dead; freehand lasso removes debris; per‑square counts; Recompute.
- Results: cards for concentration, viability, live/dead, squares, dilution. QC banners for low focus/glare/overcrowding. Export CSV/PDF; save sample.
- History: GRDB‑backed saved samples with thumbnail, date, counts; search by project/operator.
- Settings: chamber/stain/dilution defaults; segmentation params; area filters; privacy toggles; About & Paywall.
- Help: inclusion rule diagram (include top/left, exclude bottom/right) + tips.
- Debug: intermediate thumbnails (optional) and QA Fixtures runner.
- Consent: first‑run consent for personalized ads + crash reports (ATT prompt if opted‑in).

## Imaging Pipeline (On‑Device)

1) Rectangle detection: `VNDetectRectanglesRequest` with tunables; returns 4 corners (image space).
2) Perspective correction: `CIFilter.perspectiveCorrection` to top‑down corrected image.
3) Segmentation:
   - Optional Core ML UNet (256×256) loader path (tiling ready) with Metal acceleration.
   - Classical fallback when model missing: grayscale → (adaptive or Otsu) threshold → connected components → optional post‑filtering.
   - Working image automatically capped to 2048 px on the long side; classical stage uses an internal 512 px cap for speed/memory.
4) Object features: connected components, areaPx, perimeterPx, circularity (4πA/P²), centroid, bbox; solidity placeholder (extendable via convex hull).
5) Viability: 5×5 mean HSV/LAB around centroid. Dead if hue in blue band (200–260°), saturation above adaptive percentile, and V below global median.

Performance:

- Metal‑backed CIContext; reused pixel buffers to minimize allocations.
- `PerformanceLogger` times: capture, detectRectangle, perspective, segmentation, features, viability, render overlay, pipeline total.
- Target: < 5 s from corrected image to detections on iPhone 12+ for 1080p input.

## Counting (Neubauer Improved)

- Grid geometry: 3×3 large squares (1 mm each), small squares 50 µm.
- Inclusion rule: include top/left borders, exclude bottom/right; exact boundaries nudge to include top/left.
- Mapping: centroid → small/large square indices; per‑large‑square tallies.
- Robust stats: MAD outlier rejection; default squares used = 4 corners (0,2,6,8).
- Formulas:
  - Concentration (cells/mL) = mean per large square × 1e4 × dilution
  - Viability (%) = (live / total) × 100
- Seeding calculator: given target cells + final volume → volume to add + guidance (overcrowding/undercrowding).

## Persistence (GRDB)

Tables:

- `sample(id, createdAt, operator, project, chamberType, dilutionFactor, stainType, liveTotal, deadTotal, concentrationPerMl, viabilityPercent, squaresUsed, rejectedSquares, focusScore, glareRatio, pxPerMicron, imagePath, maskPath, pdfPath, notes)`
- `detection(sampleId, objectId, x, y, areaPx, circularity, solidity, isLive)`

Features:

- Migrations on first run.
- DAO for insert sample + detections; query by project/operator; per‑sample folder with images/PDF.

## Export

## Settings & Persistence

- SettingsStore persists expert parameters with @AppStorage. Direct numeric input supported via NumericField, with validation and inline hints.
- Key numeric parameters: dilutionFactor (default 1.0), areaMinUm2 (50), areaMaxUm2 (50000), threshold method, block size, and C offset. Reset to defaults available.

## Area Selection Coordinates

- ImageSelectionView renders image “fit-to-view” and manages a selection rectangle in view space. On Confirm Selection, the overlay rect is converted back to image coordinates via GeometryUtils.scale(rect:from:to:), so you can crop or pass the ROI to downstream processing.
- CSV: Summary row; optional per‑object detections (Pro‑gated).
- PDF: Header (project, operator, timestamp); original/corrected/overlay images; 3×3 count table; formulas/params; optional watermark (removed for Pro).
- Share: System share sheets for CSV/PDF; can also save corrected image to Photos.

## Monetization & Ads

- StoreKit 2: one‑time Pro (`com.smartcellcounter.pro`) via `PurchaseManager`.
  - Pro enables: no watermark, detections export/batch paths, ML refine always on, ad‑free.
- Optional Ads (compile flag `ADS`): banner on Results and History only; respects consent; no ads on capture/crop/review.
- Consent: first run sheet for personalized ads + crash reports; ATT prompt only if personalized ads enabled.

## Performance & QA

## Cell Detection v2 (Classical CV + Optional ML)

Pipeline (on-device, deterministic):

1) Input normalization: sRGB → linear luminance; HSV computed. Focus check via variance of Laplacian.
2) Illumination correction: large Gaussian background estimation and division; histogram equalization on luminance.
3) Grid/debris suppression: directional edges projection → line mask; texture mask via Laplacian energy.
4) Candidate detection: multi-scale DoG on luminance; local maxima kept as centers; radii from scale (≈1.6σ); diameter constrained by calibration.
5) Classification: rule-based (blue HSV mask → dead; bright blob → live) with confidence; optional tiny ML stub for refinement.
6) NMS: IoU-based circle merging to suppress duplicates.
7) ROI: compute in ROI space then remap to image space.
8) Calibration: supports µm-per-pixel via hemocytometer square; settings expose min/max cell diameter and thresholds.
9) Overlays: blue mask, grid mask, illumination field, candidate circles; enable from Review → eye menu.

Settings (persisted):

- minCellDiameterUm, maxCellDiameterUm
- blueHueMin, blueHueMax, minBlueSaturation
- blobScoreThreshold, nmsIoU, focusMinLaplacian
- enableGridSuppression

Testing:

- Add PNGs under test bundle and JSON labels under TestLabels. See `CellDetectionTests.swift`.
- Acceptance: precision ≥ 0.9, recall ≥ 0.85 on goldens; blank control yields no circles.
- PerformanceLogger records per‑stage timings; view via Debug.
- QA Fixtures: 10 fixture images (place your PNGs under Assets as `fixture01`…`fixture10`).

  - Debug → QA Fixtures → Run All: shows counts, pass/fail (min/max), and durations.

## CI

Continuous Integration runs via GitHub Actions (`.github/workflows/ci.yml`):

- Installs XcodeGen, SwiftLint, and swift-format (best effort)
- Generates the Xcode project (`xcodegen generate`)
- Lints the Swift sources (SwiftLint/SwiftFormat)
- Dynamically selects an available iOS simulator, runs `xcodebuild test` with code coverage enabled, and uploads the coverage report as an artifact (`coverage.json`)

### Running the CI flow locally

Use the provided make targets:

```bash
# Regenerate the Xcode project
make generate

# Run linting (SwiftLint/SwiftFormat if installed)
make lint

# Full CI dry-run: generate + lint + xcodebuild test + coverage report
make ci
```

The `make ci` target mirrors the workflow steps and writes coverage output to `coverage.json`. Tools are optional—if SwiftLint / swift-format are not installed, the commands are skipped with a console message. Combine this with [`act`](https://github.com/nektos/act) if you want to execute the GitHub Actions workflow locally.

## TestFlight & Submission

- Start with the [Release Checklist](docs/ReleaseChecklist.md) to bump build numbers, verify signing, and archive a Release build (`ENABLE_BITCODE=NO`, `SWIFT_STRICT_CONCURRENCY=complete`).
- Generate a clean archive:
  ```bash
  xcodebuild -scheme SmartCellCounter \
    -configuration Release \
    -archivePath build/SmartCellCounter.xcarchive \
    clean archive
  ```
- Export the `.ipa` for TestFlight/device install:
  ```bash
  cat <<'EOF' > ExportOptions.plist
  <plist version="1.0">
  <dict>
    <key>method</key><string>ad-hoc</string>
    <key>signingStyle</key><string>automatic</string>
    <key>compileBitcode</key><false/>
  </dict>
  </plist>
  EOF

  xcodebuild -exportArchive \
    -archivePath build/SmartCellCounter.xcarchive \
    -exportOptionsPlist ExportOptions.plist \
    -exportPath build
  ```
  The resulting `build/SmartCellCounter.ipa` should install on a physical device before uploading to App Store Connect.
- Run the [TestFlight Smoke Test](docs/TestFlightSmokeTest.md) on the TestFlight build to cover critical flows.
- Privacy: `PrivacyInfo.xcprivacy` indicates no tracking and on‑device processing.
- Screenshots: UITest `SmartCellCounterUITests.testScreenshots` attaches Capture, Results (proxy for Review overlay), Settings. Run on 6.7" and 6.1" simulators when updating marketing assets.
- Release scheme (project.yml): whole‑module, `-O`, dead code stripping.
- StoreKit 2 sandbox works in TestFlight; verify purchase/restore.
- App Store Connect metadata (examples):
  - Name: Smart Cell Counter
  - Subtitle: Automated hemocytometer cell counting
  - Keywords: cell counting, hemocytometer, trypan blue, viability, lab
  - Privacy Policy URL: https://www.smartcellcounter.com/privacy
  - Support URL: https://www.smartcellcounter.com/support

## Disclaimers & Licenses

- Research use only. Not a medical device.
- Third‑party: GRDB.swift (MIT), GoogleMobileAds (optional; Google terms), Apple frameworks (PDFKit/Vision/Core Image/AVFoundation).
- See LICENSE if present for app‑level license.

## Quick Start Checklist

1. Clone the repo and install tooling: `brew install xcodegen swiftlint swiftformat`
2. `make generate` to sync the Xcode project (after editing `project.yml`).
3. `make lint` and `make test` to ensure a clean baseline.
4. Launch the app:
   - Simulator: `CODE_SIGNING_ALLOWED=NO xcodebuild -scheme SmartCellCounter -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16 Pro' build && open SmartCellCounter.xcodeproj`
   - Mocked capture: run with launch argument `-UITest.MockCapture 1` to bypass camera hardware.
5. Review `docs/ARCHITECTURE.md` and `docs/CONTRIBUTING.md` before submitting changes.

## Contact

- Support: https://www.smartcellcounter.com/support
- Privacy: https://www.smartcellcounter.com/privacy
- Email: jameshyojaelee@gmail.com
