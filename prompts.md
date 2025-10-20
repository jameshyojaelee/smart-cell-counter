```

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
