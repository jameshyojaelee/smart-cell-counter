import SwiftUI

struct RingGauge: View {
    let progress: Double // 0...1
    let lineWidth: CGFloat
    let gradient: LinearGradient
    @State private var anim: Double = 0

    var body: some View {
        ZStack {
            Circle().stroke(Color.white.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: anim)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.8), value: anim)
        }
        .onAppear { anim = progress }
    }
}

