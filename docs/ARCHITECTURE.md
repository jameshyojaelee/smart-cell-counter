# SmartCellCounter Architecture Overview

This document introduces the major modules in the SmartCellCounter app and how data flows between components. The intent is to give new contributors situational awareness before diving into implementation details.

## Module Map

- **Capture** (`Features/Capture`, `Core/Imaging`)
  - Wraps camera session management, focus metrics, and mock capture paths used for testing.
  - Emits captured or imported images into the shared `AppState`.
- **Imaging** (`Core/Imaging`, `Core/Vision`, `Core/Math`)
  - Performs rectangle detection, perspective correction, segmentation (classical + optional Core ML), connected components, feature extraction, and per-square counting helpers.
  - Exposes pure functions (for tests) and progress metrics via `PerformanceLogger`.
- **Review** (`Features/Review`)
  - Presents segmented results, overlays, lasso editing, and stats summary.
  - Consumes objects/segmentation results produced by Imaging and updates `AppState` selections and tallies.
- **Storage** (`Core/Storage`, `Core/Models`, `Core/Utilities`)
  - Persists samples, CSV/PDF exports, thumbnails using GRDB and the filesystem.
  - Handles export metadata, crash/metric logging, and device info snapshots.
- **Monetization & Privacy** (`Core/Monetization`, `Features/Paywall`, `Core/Privacy`)
  - Manages StoreKit purchases, entitlement refresh, paywall UI, consent flows, ad gating.

## Data Flow Overview

```text
Camera (Capture) ──► Imaging Pipeline ──► Review overlays ──► Results / Storage
          ▲                 │                   │                    │
          │                 │                   │                    │
      Settings & Mock Data ─┴───────────────────┴────────────────────┘
```

### Detailed Flow

1. **Capture**
   - `CaptureViewModel` orchestrates the camera session (or mock preview when `-UITest.MockCapture` is passed).
   - Once a photo is captured/imported, the image is stored in `AppState.capturedImage` and navigation proceeds to `CropView`.

2. **Crop & Perspective**
   - `CropView` optionally adjusts the region of interest. The cropped image is written to `AppState.correctedImage`.
   - The imaging pipeline (`ImagingPipeline.perspectiveCorrect`) normalizes the image before segmentation.

3. **Imaging Pipeline**
   - Entry point: `ImagingPipeline.segmentCells` (decides between classical vs. Core ML).
   - Segmentation results feed into `CellDetector.detect` → `CountingService.tallyByLargeSquare`.
   - Results (segmentation mask, labeled objects, per-square tallies) are kept in `AppState.segmentation`, `AppState.labeled`, `AppState.objects`, etc.

4. **Review**
   - `ReviewViewModel` observes `AppState` and recomputes stats when recompute/filters change.
   - Overlays (detections, masks, grid) draw from segmentation results; editing actions update `AppState.labeled` and derived tallies.

5. **Results & Storage**
   - `ResultsViewModel` computes final concentration/viability metrics, exports CSV/PDF (with metadata), and persists via `AppDatabase`.
   - `PerformanceLogger` publishes stage timing + rolling averages for Debug dashboards.

6. **Monetization**
   - `PurchaseManager` refreshes entitlement state, toggles Pro-only features (advanced exports, ad removal).
   - `PaywallView` presents pricing, benefits, and a debug simulator for QA.

## Cross-Cutting Concerns

- **AppState**: central observable object shared across SwiftUI views. Holds current images, labeled objects, debug artifacts, focus/glare metrics.
- **SettingsStore & Settings**: capture user tunables (dilution factor, segmentation thresholds, lab metadata). Many pipeline decisions pull from these values.
- **PerformanceLogger**: asynchronous timing/rolling metrics surfaced in Debug view and available for export.
- **CrashReporter & AnalyticsLogger**: integrate MetricKit diagnostics and optional analytics.

Understanding these modules and flow should help you orient subsequent deep dives (see `docs/CONTRIBUTING.md` for coding standards and testing guidance).
