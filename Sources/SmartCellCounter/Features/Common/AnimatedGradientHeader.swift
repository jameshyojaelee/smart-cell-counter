import SwiftUI

struct AnimatedGradientHeader: View {
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey?
    @State private var animate = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            LinearGradient(colors: [Theme.accent, Theme.accent2.opacity(0.8)], startPoint: animate ? .topLeading : .bottomTrailing, endPoint: animate ? .bottomTrailing : .topLeading)
                .animation(.linear(duration: 6).repeatForever(autoreverses: true), value: animate)
                .overlay(Theme.accent.opacity(0.15))
            VStack(alignment: .leading, spacing: DS.Spacing.xs) {
                Text(title).font(DS.Typo.title).foregroundColor(.white)
                if let subtitle { Text(subtitle).font(DS.Typo.caption).foregroundColor(.white.opacity(0.9)) }
            }
            .padding(DS.Spacing.lg)
        }
        .frame(height: 120)
        .onAppear { animate = true }
        .cornerRadius(DS.Radius.lg)
        .shadow(color: Theme.accent.opacity(0.25), radius: 12, x: 0, y: 6)
    }
}
