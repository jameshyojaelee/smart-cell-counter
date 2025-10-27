import SwiftUI

struct OnboardingStep: Identifiable, Equatable {
    let id: Int
    let symbolName: String

    var title: String { L10n.Onboarding.stepTitle(id) }
    var message: String { L10n.Onboarding.stepMessage(id) }
    var symbolAccessibility: String { L10n.Onboarding.symbolAccessibility(id) }
}

struct OnboardingView: View {
    @AppStorage("onboarding.completed") private var onboardingCompleted = false
    @State private var currentIndex: Int = 0

    private let steps: [OnboardingStep] = [
        OnboardingStep(id: 0, symbolName: "camera"),
        OnboardingStep(id: 1, symbolName: "lock.shield"),
        OnboardingStep(id: 2, symbolName: "externaldrive")
    ]

    let onFinish: () -> Void

    var body: some View {
        VStack {
            HStack {
                Spacer()
                Button(L10n.Onboarding.skip) {
                    completeOnboarding()
                }
                .foregroundColor(.secondary)
                .padding()
                .accessibilityLabel(L10n.Onboarding.skip)
                .accessibilityHint(L10n.Onboarding.finishHint)
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
                            .accessibilityLabel(step.symbolAccessibility)
                            .accessibilityAddTraits(.isImage)
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
                ForEach(0 ..< steps.count, id: \.self) { idx in
                    Circle()
                        .fill(idx == currentIndex ? Theme.accent : Theme.textSecondary.opacity(0.3))
                        .frame(width: 8, height: 8)
                }
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(L10n.Onboarding.pageIndicator(current: currentIndex + 1, total: steps.count))
            .padding(.bottom, 12)

            Button(action: nextStep) {
                Text(currentIndex == steps.count - 1 ? L10n.Onboarding.getStarted : L10n.Onboarding.continueButton)
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Theme.accent)
                    .foregroundColor(.white)
                    .cornerRadius(14)
                    .padding(.horizontal)
                    .padding(.bottom, 24)
            }
            .accessibilityHint(currentIndex == steps.count - 1 ? L10n.Onboarding.finishHint : L10n.Onboarding.continueHint)
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
