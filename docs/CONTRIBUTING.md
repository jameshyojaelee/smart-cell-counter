# Contributing to SmartCellCounter

Thanks for your interest in improving SmartCellCounter! This guide sets expectations for code quality, testing, and local setup.

## Development Environment

- Xcode 15 (or newer) on macOS with Swift 5.9+
- `xcodegen`, `swiftlint`, and `swiftformat` (the CI workflow installs these when available)
- Optional: [`act`](https://github.com/nektos/act) to simulate GitHub Actions

## Coding Standards

- Swift: follow [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Prefer small pure functions in the imaging/analysis layers. Keep SwiftUI views declarative and side-effect free.
- Use `MARK:` sections sparingly; rely on well named types/functions instead of excessive comments.
- Formatting: run `swiftformat` (or let CI do it). `swiftlint --strict` is the baseline linter configuration.

## Workflow

1. Fork + branch (`feature/your-topic`).
2. Run `make generate` (only necessary after editing `project.yml`).
3. Implement changes with tests.
4. Run `make lint` and `make test` locally (or `make ci` for the full check).
5. Submit a PR referencing related issues, including a summary of testing performed.

## Testing Expectations

- **Unit tests**: add coverage when touching logic-heavy code (`CountingService`, `ImagingPipeline`, `PerformanceLogger`, `PurchaseManager`, etc.). Use fixtures under `Tests/SmartCellCounterTests/Fixtures` when possible.
- **UI tests**: `SmartCellCounterUITests.testEndToEndMockedCaptureFlow` demonstrates the mocked capture path. Launch arguments `-UITest.MockCapture 1` mock the camera, auto-progress crop, and provide deterministic review data. Use this pattern for additional UI smoke tests.
- **Manual QA**: follow the [TestFlight Smoke Test](TestFlightSmokeTest.md) for release builds or if changes span multiple layers.

## Running Without Hardware

- Camera access can be simulated using the mock capture flag mentioned above.
- Results + Review can be driven entirely by fixtures (`AppState.debugImages`, sample segmentation results). See `MockCaptureData` in `CaptureView` for a fully mocked pipeline.
- When testing exports, use `CODE_SIGNING_ALLOWED=NO` to build/run on the simulator without provisioning.

## Pull Request Checklist

- [ ] `make lint`
- [ ] `make test`
- [ ] Updated docs/tests when applicable
- [ ] No debug print statements or commented-out code

CI will run the same lint + test steps and provide coverage as an artifact.

Happy hacking!
