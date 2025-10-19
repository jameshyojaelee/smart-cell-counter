# SmartCellCounter Accessibility Guide

## Objective

SmartCellCounter is designed to be operable with VoiceOver, Dynamic Type, and Right-to-Left layouts. This guide outlines expected behaviours, key affordances, and the manual test flows to validate accessibility.

## Global behaviours

- **Dynamic Type**: All SwiftUI text styles and custom components respond to the system content size category, including the largest accessibility sizes.
- **VoiceOver**: Every actionable control exposes an explicit label, hint, and (where applicable) value. Decorative imagery and overlays are hidden from accessibility.
- **Right-to-Left**: Canvas-based overlays (selection handles, detection markers, diagnostic imagery) opt-out of automatic mirroring to preserve coordinate space alignment.
- **Color/Contrast**: Primary interactions adopt the dark design system palette with WCAG-compliant contrast, while stateful feedback uses both colour and text.

## Feature checklists

### Capture
- Camera preview advertises touch-to-focus behaviour.
- Grid toggle, shutter, photo import, and settings buttons include hints and stateful values.
- HUD metrics expose descriptive labels (`Focus`, `Glare`) and values formatted for VoiceOver.

### Selection & Crop
- Selection overlay communicates current area/size through accessibility values.
- Resize handles and undo actions have explicit labels and hints.
- Geometry ignores layout mirroring so handles remain aligned.

### Detection & Review
- Overlay picker toggles announce current state (on/off) and provide hints.
- Individual detections render as labelled invisible buttons for VoiceOver; underlying canvas is hidden.
- Lasso confirmation banners, stats, and per-square tables deliver combined labels for quick scan.

### Results
- Metric cards merge title/value for VoiceOver and hide decorative gauges.
- Export actions provide purpose-specific hints; layout survives Accessibility XXL text sizes (see UITest `testDynamicTypeScalingOnResults`).

### Settings & Consent
- Toggles and numeric fields expose context-aware labels, validation messaging, and actionable hints.
- Numeric fields collapse into a combined accessibility element so VoiceOver reads label and current value together.

### Help & Debug
- Help topics, quick links, and videos are presented with localized labels and hints for launching URLs.
- Debug/QC tooling remains available but clearly labelled.

## Manual testing steps

1. **VoiceOver audit**
   - Enable VoiceOver (`Settings → Accessibility → VoiceOver`).
   - Launch SmartCellCounter and traverse: Capture → Crop → Detection → Review → Results → Settings.
   - Confirm rotor navigation announces controls in logical order; verify hints for shutter, overlays, export, and numeric inputs.

2. **Dynamic Type sweep**
   - Set `Settings → Accessibility → Display & Text Size → Larger Text` to the largest accessibility size.
   - Relaunch the app; visit each tab to ensure no clipped labels or overlapping content.
   - UITest `testDynamicTypeScalingOnResults` serves as an automated smoke check.

3. **Right-to-Left verification**
   - In the simulator, enable `Environment Overrides → Right-to-Left`.
   - Confirm capture overlays, selection handles, and detection markers remain aligned with the underlying imagery.

4. **Export workflows**
   - With VoiceOver enabled, activate `Export CSV`, `Export PDF`, and `Save Sample` from the Results tab; ensure share sheet items announce descriptive labels.

## Reporting issues

Log accessibility regressions or localization gaps in the issue tracker with reproduction steps, VoiceOver transcripts (if available), and screenshots highlighting the affected UI.
