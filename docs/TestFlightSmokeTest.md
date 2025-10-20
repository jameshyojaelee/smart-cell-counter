# TestFlight Smoke Test Plan

Run this lightweight checklist for every TestFlight build before promoting to App Store review.

## Environment
- Device: recent iPhone (iOS 16+)
- Build: Release `.ipa` installed from TestFlight
- Network: Wi-Fi enabled

## Scenarios

1. **First Launch & Permissions**
   - Accept onboarding and consent prompts.
   - Grant camera & photo permissions when prompted.
   - Confirm the camera preview loads and grid toggle responds.

2. **Capture Flow**
   - Capture a sample image (or import from Photos).
   - Adjust crop and confirm transition to Review.
   - Verify detections render, lasso removal works, and stats update.

3. **Results & Export**
   - Review calculated concentration/viability metrics.
   - Adjust dilution factor and confirm recalculation.
   - Export CSV/PDF (if Pro, ensure detections export also works). Share sheets should appear.

4. **History & Persistence**
   - Save the sample and verify it appears under History with thumbnail.
   - Re-open the entry to confirm metadata and stored exports.

5. **Settings & Debug**
   - Change a Settings parameter (e.g. threshold method) and ensure it persists after relaunch.
   - Visit Debug view and confirm performance dashboard updates as pipeline runs.

6. **Purchase / Entitlement**
   - Trigger the paywall. Ensure pricing loads and restore works (using sandbox account).
   - If Pro entitlement available, confirm ads disappear and gated exports unlock.

7. **Stability**
   - Background the app during capture; return and ensure session recovers.
   - Force-quit & relaunch: previously saved sample should remain available.

Record any issues, device details, and build number alongside this checklist.

