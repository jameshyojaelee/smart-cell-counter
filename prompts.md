```

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
