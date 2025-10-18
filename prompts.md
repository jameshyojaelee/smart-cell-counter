## Prompt 7 – Improve Onboarding, Consent, and Help

```
You are GPT-5 Codex. Objective: guide users through first-run setup and compliance requirements.

Tasks:
1. Create a multi-step onboarding carousel explaining capture best practices, privacy, and data storage. Display it on first launch before the consent sheet.
2. Expand `ConsentView` with explicit opt-in/opt-out toggles for crash reporting and analytics (wired into `Settings.shared.personalizedAds` / new settings as needed).
3. Refresh `HelpView` with searchable FAQs, quick links to troubleshooting topics, and inline tutorial videos (use placeholders if assets are not yet available).
4. Log completion events so future analytics can measure onboarding effectiveness.

Validation:
- Add snapshot tests or SwiftUI previews for the onboarding screens.
- Ensure onboarding state is persisted (e.g. via `@AppStorage`) and can be reset for QA.
```

## Prompt 8 – Accessibility and Localization Pass

```
You are GPT-5 Codex. Goal: ensure SmartCellCounter meets accessibility standards and is ready for localization.

Tasks:
1. Audit all SwiftUI views for accessibility labels, traits, Dynamic Type scaling, and VoiceOver order. Add explicit `accessibilityLabel`, `Hint`, and `Value` where appropriate.
2. Replace hard-coded strings with localized keys in `.strings` files (start with English). Group keys by feature module.
3. Add support for right-to-left layouts by verifying geometry calculations (e.g. in `SelectionOverlay`, `DetectionOverlay`) respect Mirroring.
4. Create an `AccessibilityGuide.md` summarizing key behaviors and testing steps.

Validation:
- Run the app with VoiceOver in the simulator and confirm critical workflows are navigable.
- Add an XCTest UI test that exercises a Dynamic Type change and verifies layout constraints hold.
```

## Prompt 9 – Performance Instrumentation and Diagnostics

```
You are GPT-5 Codex. Objective: provide deeper insight into performance and reliability.

Tasks:
1. Extend `PerformanceLogger` to aggregate rolling averages and expose data via a SwiftUI dashboard (e.g. in DebugView).
2. Instrument key pipeline stages (capture, correction, segmentation, counting) with unified timing identifiers and include device info.
3. Integrate MetricKit crash diagnostics into `CrashReporter` with persisted summaries in Application Support for later upload.
4. Add background upload stubs (disabled by default) that demonstrate how anonymized metrics would be sent.

Validation:
- Add unit tests ensuring `PerformanceLogger` aggregation works.
- Verify DebugView renders the new performance dashboard.
```

## Prompt 10 – Export and Sharing Enhancements

```
You are GPT-5 Codex. Goal: make exporting results more flexible and user-friendly.

Tasks:
1. Refactor `CSVExporter` and `PDFExporter` to accept custom metadata (lab name, stain, dilution) so exports reflect user settings.
2. Add background export support with progress indicators in `ResultsViewModel`, using `Task` or `Observation`.
3. Introduce an export history panel that tracks recent exports and provides quick share actions.
4. Guard exports behind file permission checks and handle errors with user-facing alerts.

Validation:
- Add unit tests covering new exporter inputs.
- Manually exercise CSV/PDF exports and verify metadata inclusion.
```

## Prompt 11 – Monetization and Paywall Improvements

```
You are GPT-5 Codex. Objective: polish the purchasing experience and ensure entitlements are robust.

Tasks:
1. Redesign `PaywallView` with benefit highlights, FAQs, and a clear comparison table (Pro vs Free).
2. Add receipt validation and entitlement refresh logic to `PurchaseManager` so the app recovers from interrupted purchases.
3. Provide a sandbox-friendly purchase simulator in Debug mode for QA.
4. Gate advanced exports/detections behind `isPro` with graceful fallbacks explaining why the feature is locked.

Validation:
- Add unit tests that simulate entitlement changes and verify UI updates.
- Test purchase, restore, and failure flows in the StoreKit sandbox.
```

## Prompt 12 – Continuous Integration and QA Automation

```
You are GPT-5 Codex. Goal: establish automated validation for SmartCellCounter.

Tasks:
1. Add a GitHub Actions (or preferred CI) workflow that runs `xcodebuild test` on PRs, including SwiftLint (if available) and swift-format checks.
2. Create at least one XCTUI test in `Tests/SmartCellCounterUITests` that walks through capture → crop → review with mocked data.
3. Generate code coverage reports and publish them as CI artifacts.
4. Document how to run CI locally via a `Makefile` target.

Validation:
- Ensure the workflow passes locally (using `act` or manual dry runs).
- Commit updated `README.md` instructions for contributors.
```

## Prompt 13 – iOS Distribution Readiness

```
You are GPT-5 Codex. Objective: prepare the project for seamless App Store delivery.

Tasks:
1. Configure app capabilities (camera, photo library, file sharing) in the Xcode project or `project.yml`, ensuring Info.plist includes human-readable usage descriptions for each permission.
2. Add a release configuration checklist (versioning, build numbers, signing) to the repository.
3. Verify the app builds and archives under Release configuration with bitcode disabled (modern requirement) and Swift concurrency flags set.
4. Create a lightweight smoke test plan for TestFlight that documents critical manual scenarios.

Validation:
- Produce an `.ipa` via `xcodebuild archive` and confirm it launches on a device/simulator.
- Update `README.md` with distribution steps.
```

## Prompt 14 – Developer Documentation and Architecture Guide

```
You are GPT-5 Codex. Goal: make onboarding new contributors easier.

Tasks:
1. Write `docs/ARCHITECTURE.md` explaining high-level modules (Capture, Imaging, Review, Storage, Monetization) and data flow between them.
2. Add `docs/CONTRIBUTING.md` outlining coding standards, testing expectations, and how to run the app without hardware (using mocks/fakes).
3. Generate a diagram (ASCII or Mermaid) depicting the imaging pipeline stages and where configuration settings feed in.
4. Update `README.md` to reference the new docs and include a quick-start checklist.

Validation:
- Ensure Markdown passes basic lint (if tooling exists) or is at least well-formatted.
- Link the new docs from appropriate locations in the repo.
```

---

Work through the prompts sequentially or prioritize based on product goals. Each prompt is intentionally self-contained so you can tackle them one at a time with GPT-5 Codex.
