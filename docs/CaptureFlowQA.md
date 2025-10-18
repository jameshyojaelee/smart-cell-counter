# Capture Flow QA Notes

- **Focus & Glare HUD**: Verify the new banner at the top of Capture shows live focus (≈0.00 – 1.00) and glare readings that update while the preview is active. Torch toggle should flip between on/off instantly and persist when reopening the screen.
- **Permission Messaging**: Launch with camera permissions denied and confirm the HUD shows the warning callout plus the “Open Settings” action. After enabling permissions in Settings and returning to the app, the preview should start automatically without relaunching.
- **Tap to Focus**: Tap anywhere inside the preview and look for the circular focus indicator animating at the tap point while the status text briefly changes to “Focusing…”. Focus/exposure should adjust within ~1 second.
- **Scene Lifecycle**: Background the app (home button or multitask) while the camera is running. On return, the preview should resume without crashing and the HUD should come back to “Ready”.
- **Capture Flow**: With permissions granted, confirm snap-to-capture still works (shutter -> Crop screen) and the HUD status transitions through “Capturing…”/“Saving…” back to “Ready”.
