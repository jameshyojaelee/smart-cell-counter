import SwiftUI

struct OnboardingStep: Identifiable, Equatable {
    let id = UUID()
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    let symbolName: String
}

struct OnboardingView: View {
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @State private var currentIndex: Int = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(title: "Capture Tips",
                       message: "Use even lighting, focus on the grid, and avoid glare for the most accurate counts.",
                       symbolName: "camera"),
        OnboardingStep(title: "Privacy First",
                       message: "All analysis happens on-device. You control if ads, analytics, or crash reports are shared.",
                       symbolName: "lock.shield"),
        OnboardingStep(title: "Data Storage",
                       message: "Samples are saved locally. Export CSV/PDF files to back them up or share with teammates.",
                       symbolName: "externaldrive")
    ]

    let onFinish: () -> Void

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button("Skip") {
                    completeOnboarding()
                }
                .foregroundColor(.secondary)
                .padding()
            }
            TabView(selection: $currentIndex) {
                ForEach(Array(steps.enumerated()), id: \.element.id) { index, step in
                    VStack(spacing: 24) {
                        Spacer()
                        Image(systemName: step.symbolName)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 120, height: 120)
                            .foregroundColor(Theme.accent)
                            .padding()
                        Text(step.title)
                            .font(.title2.weight(.semibold))
                            .foregroundColor(Theme.textPrimary)
                        Text(step.message)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundColor(Theme.textSecondary)
                            .padding(.horizontal)
                        Spacer()
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(PageTabViewStyle())

            HStack(spacing: 6) {
                ForEach(0..<steps.count, id: \.self) { idx in
                    Circle()
                        .fill(idx == currentIndex ? Theme.accent : Theme.textSecondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.bottom, 12)

            Button(action: nextStep) {
                Text(currentIndex == steps.count - 1 ? "Get Started" : "Continue")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
        }
        .background(Theme.background.ignoresSafeArea())
    }

    private func nextStep() {
        if currentIndex < steps.count - 1 {
            currentIndex += 1
        } else {
            completeOnboarding()
        }
    }

    private func completeOnboarding() {
        onboardingCompleted = true
        onFinish()
    }
}

#if DEBUG
struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView {
            // preview completion
        }
    }
}
#endif
