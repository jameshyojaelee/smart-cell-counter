import SwiftUI

struct CaptureHUDView: View {
    let statusText: String
    let isReady: Bool
    let focusScore: Double
    let glareRatio: Double
    @Binding var torchOn: Bool
    let permissionDenied: Bool
    let onSettingsTap: () -> Void

    private var statusColor: Color {
        if permissionDenied { return Theme.danger }
        return isReady ? Theme.success : Theme.warning
    }

    private var statusIcon: String {
        if permissionDenied { return "exclamationmark.triangle.fill" }
        return isReady ? "checkmark.circle.fill" : "hourglass"
    }

    private var formattedFocus: String {
        String(format: "%.2f", focusScore)
    }

    private var formattedGlare: String {
        String(format: "%.2f", glareRatio)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits {
                HStack(alignment: .center, spacing: 12) {
                    statusView
                    Spacer(minLength: 8)
                    torchToggle
                }
                VStack(alignment: .leading, spacing: 8) {
                    statusView
                    torchToggle
                }
            }

            ViewThatFits {
                HStack(spacing: 8) {
                    metricChip(
                        title: L10n.Capture.focusMetricTitle,
                        value: formattedFocus,
                        icon: "viewfinder",
                        accessibilityLabel: L10n.Capture.focusMetricAccessibility(formattedFocus)
                    )
                    metricChip(
                        title: L10n.Capture.glareMetricTitle,
                        value: formattedGlare,
                        icon: "sun.max",
                        accessibilityLabel: L10n.Capture.glareMetricAccessibility(formattedGlare)
                    )
                }
                VStack(alignment: .leading, spacing: 6) {
                    metricChip(
                        title: L10n.Capture.focusMetricTitle,
                        value: formattedFocus,
                        icon: "viewfinder",
                        accessibilityLabel: L10n.Capture.focusMetricAccessibility(formattedFocus)
                    )
                    metricChip(
                        title: L10n.Capture.glareMetricTitle,
                        value: formattedGlare,
                        icon: "sun.max",
                        accessibilityLabel: L10n.Capture.glareMetricAccessibility(formattedGlare)
                    )
                }
            }

            if permissionDenied {
                VStack(alignment: .leading, spacing: 6) {
                    Text(L10n.Capture.permissionExplanation)
                        .font(.footnote)
                        .foregroundColor(Theme.textSecondary)
                    Button(action: onSettingsTap) {
                        Label(L10n.Capture.openSettings, systemImage: "arrow.up.right.square")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .accessibilityHint(L10n.Capture.openSettingsHint)
                }
                .padding(10)
                .background(Theme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(14)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 18))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Theme.border.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 3)
    }

    private var statusView: some View {
        HStack(spacing: 8) {
            Image(systemName: statusIcon)
                .foregroundColor(statusColor)
            Text(statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(statusText)
    }

    private var torchToggle: some View {
        Toggle(isOn: $torchOn) {
            Label(L10n.Capture.torchTitle, systemImage: torchOn ? "flashlight.on.fill" : "flashlight.off.fill")
                .font(.footnote.weight(.semibold))
        }
        .toggleStyle(SwitchToggleStyle(tint: Theme.accent))
        .accessibilityLabel(L10n.Capture.torchToggleLabel(isOn: torchOn))
        .accessibilityHint(L10n.Capture.torchHint)
    }

    private func metricChip(title: String, value: String, icon: String, accessibilityLabel: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                Text(title)
                    .textCase(.uppercase)
                    .font(.caption2.weight(.medium))
            }
            .foregroundColor(Theme.textSecondary)
            Text(value)
                .font(.system(.body, design: .monospaced).weight(.semibold))
                .foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Theme.surface.opacity(0.7), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }
}
