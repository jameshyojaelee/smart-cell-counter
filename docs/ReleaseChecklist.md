# Release Configuration Checklist

Use this checklist before cutting a new App Store build.

1. **Versioning**
   - Update `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` in `project.yml`.
   - Run `xcodegen generate` to refresh the project files.
   - Commit version bumps.

2. **Code & Assets**
   - Verify `make lint` and `make test` (or `make ci`) complete cleanly.
   - Review localized strings, Info.plist usage descriptions, and screenshots.
   - Regenerate QA fixtures if detection changes affected metrics.

3. **Signing & Certificates**
   - Confirm the correct `DEVELOPMENT_TEAM` and provisioning profiles in Xcode > Signing & Capabilities.
   - Ensure the release signing certificate is installed on the build machine.

4. **Build Settings**
   - Confirm `ENABLE_BITCODE = NO` and `SWIFT_STRICT_CONCURRENCY = complete` for Release.
   - Validate any feature flags (e.g. ADS, DEBUG) are set appropriately.

5. **Archive**
   - Build a clean Release archive:
     ```bash
     xcodebuild -scheme SmartCellCounter \
       -configuration Release \
       -archivePath build/SmartCellCounter.xcarchive \
       clean archive
     ```
   - Export an `.ipa` (see README for the export command) and install it on a physical device.

6. **Manual QA**
   - Follow the TestFlight smoke test plan (`docs/TestFlightSmokeTest.md`).
   - Capture fresh marketing screenshots if UI changes were made.

7. **Metadata & Submission**
   - Update App Store Connect release notes and What’s New.
   - Attach the latest privacy questionnaire results and review App Privacy responses.

8. **Tag & Release**
   - Tag the commit (`git tag vX.Y.Z && git push --tags`).
   - Create a GitHub release with change summary.

