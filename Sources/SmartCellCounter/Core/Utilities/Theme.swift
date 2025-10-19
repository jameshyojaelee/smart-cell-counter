import SwiftUI

public enum Theme {
    // Dark theme inspired by RN app
    public static let background = Color(hex: 0x0B0F14)
    public static let surface = Color(hex: 0x0F141A)
    public static let card = Color(hex: 0x121821)
    public static let textPrimary = Color(hex: 0xE6EDF3)
    public static let textSecondary = Color(hex: 0x9AA7B2)
    public static let border = Color(hex: 0x1E2A36)
    public static let accent = Color(hex: 0x3EA6FF)
    public static let accent2 = Color(hex: 0x7C4DFF)
    public static let success = Color(hex: 0x34C759)
    public static let warning = Color(hex: 0xFFB020)
    public static let danger = Color(hex: 0xFF4D4F)

    public static let gradient1 = LinearGradient(colors: [accent, accent.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
    public static let gradient2 = LinearGradient(colors: [accent2, accent2.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
    public static let gradientSuccess = LinearGradient(colors: [success, success.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
    public static let gradientDanger = LinearGradient(colors: [danger, danger.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
}

public extension View {
    func appBackground() -> some View {
        self.background(Theme.background.ignoresSafeArea())
    }

    func cardStyle(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(Theme.card)
            .cornerRadius(16)
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(Theme.border.opacity(0.5), lineWidth: 1))
            .shadow(color: .black.opacity(0.25), radius: 8, x: 0, y: 2)
    }
}

public struct Chip: View {
    let label: String
    let systemImage: String?
    let color: Color

    public init(_ label: String, systemImage: String? = nil, color: Color = Theme.surface.opacity(0.7)) {
        self.label = label
        self.systemImage = systemImage
        self.color = color
    }

    public var body: some View {
        HStack(spacing: 6) {
            if let systemImage { Image(systemName: systemImage).font(.caption2) }
            Text(label).font(.caption).foregroundColor(Theme.textPrimary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(.ultraThinMaterial)
        .background(color)
        .clipShape(Capsule())
    }
}

public struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String?
    let icon: String
    let gradient: LinearGradient

    public init(title: String, value: String, subtitle: String? = nil, icon: String = "chart.bar.fill", gradient: LinearGradient = Theme.gradient1) {
        self.title = title
        self.value = value
        self.subtitle = subtitle
        self.icon = icon
        self.gradient = gradient
    }

    public var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 16).fill(gradient)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Image(systemName: icon).foregroundColor(.white.opacity(0.95))
                    Text(title).font(.headline).foregroundColor(.white.opacity(0.9))
                }
                Text(value).font(.system(size: 28, weight: .bold, design: .rounded)).foregroundColor(.white)
                if let subtitle { Text(subtitle).font(.subheadline).foregroundColor(.white.opacity(0.85)) }
            }
            .padding(16)
        }
        .shadow(color: Theme.accent.opacity(0.2), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(value)")
        .accessibilityHint(subtitle ?? "")
    }
}

public extension Color {
    init(hex: UInt, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xff) / 255,
                  green: Double((hex >> 8) & 0xff) / 255,
                  blue: Double(hex & 0xff) / 255,
                  opacity: alpha)
    }
}
