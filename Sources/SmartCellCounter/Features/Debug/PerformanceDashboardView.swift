import SwiftUI

struct PerformanceDashboardView: View {
    @ObservedObject private var logger = PerformanceLogger.shared

    private let columns = [GridItem(.adaptive(minimum: 180), spacing: 12)]

    var body: some View {
        let dashboard = logger.dashboard
        let stageMetrics = dashboard.metrics.filter { PerformanceLogger.Stage(rawValue: $0.label) != nil }
        let otherMetrics = dashboard.metrics.filter { PerformanceLogger.Stage(rawValue: $0.label) == nil }

        return VStack(alignment: .leading, spacing: 12) {
            DeviceSummaryView(info: dashboard.deviceInfo)

            if stageMetrics.isEmpty {
                Text("No performance samples captured yet.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(stageMetrics) { metric in
                        let title = PerformanceLogger.Stage(rawValue: metric.label)?.displayName ?? metric.label
                        PerformanceMetricCard(metric: metric, title: title)
                    }
                }
            }

            if !otherMetrics.isEmpty {
                Divider()
                    .padding(.vertical, 4)
                Text("Additional Timings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(otherMetrics) { metric in
                        PerformanceMetricCard(metric: metric, title: metric.label)
                    }
                }
            }
        }
    }
}

private struct DeviceSummaryView: View {
    let info: PerformanceLogger.DeviceInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("\(info.deviceModel) • \(info.systemName) \(info.systemVersion)")
                .font(.caption)
                .foregroundColor(.secondary)
            Text("App \(info.appVersion) • Locale \(info.localeIdentifier)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

private struct PerformanceMetricCard: View {
    let metric: PerformanceLogger.PerformanceMetric
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.subheadline)
                    .bold()
                Spacer()
                Text(durationString(metric.last))
                    .font(.subheadline)
            }
            VStack(alignment: .leading, spacing: 4) {
                MetricRow(label: "Rolling", value: durationString(metric.rollingAverage))
                MetricRow(label: "All-time", value: durationString(metric.overallAverage))
                MetricRow(label: "Window", value: "\(metric.recentSampleCount) / \(metric.sampleCount)")
                MetricRow(label: "Min • Max", value: "\(durationString(metric.recentMin)) • \(durationString(metric.recentMax))")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

private struct MetricRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .foregroundColor(.primary)
        }
    }
}

private func durationString(_ ms: Double) -> String {
    guard ms.isFinite else { return "--" }
    if ms >= 1000 {
        return String(format: "%.2fs", ms / 1000)
    } else if ms >= 10 {
        return String(format: "%.0fms", ms)
    } else if ms >= 1 {
        return String(format: "%.1fms", ms)
    } else {
        return String(format: "%.2fms", ms)
    }
}
