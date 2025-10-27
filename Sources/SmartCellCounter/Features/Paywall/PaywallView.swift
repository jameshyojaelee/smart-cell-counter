import Combine
import SwiftUI

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var price: String = ""
    @Published var isProcessing = false

    let purchases = PurchaseManager.shared
    private var cancellables: Set<AnyCancellable> = []

    init() {
        purchases.$price
            .receive(on: RunLoop.main)
            .sink { [weak self] value in
                self?.price = value ?? ""
            }
            .store(in: &cancellables)
        price = purchases.price ?? ""
    }

    func buy() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await purchases.purchase()
        } catch {
            Logger.log("Purchase failed: \(error)")
        }
    }

    func restore() async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }
        do {
            try await purchases.restore()
        } catch {
            Logger.log("Restore failed: \(error)")
        }
    }

    func refreshPrice() {
        price = purchases.price ?? ""
    }

    #if DEBUG
        func simulatePurchase() {
            purchases.debugOverrideEntitlement(true)
        }

        func revokeEntitlement() {
            purchases.debugOverrideEntitlement(false)
        }
    #endif
}

struct PaywallView: View {
    @StateObject private var viewModel = PaywallViewModel()
    @ObservedObject private var purchases = PurchaseManager.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                PaywallHeader(price: viewModel.price, isProcessing: viewModel.isProcessing)

                BenefitHighlights()
                ComparisonTable()
                FAQSection()

                PaywallActions(price: viewModel.price,
                               isProcessing: viewModel.isProcessing,
                               onBuy: { Task { await viewModel.buy() } },
                               onRestore: { Task { await viewModel.restore() } },
                               onContinue: { dismiss() })

                #if DEBUG
                    DebugPurchaseControls(onSimulate: viewModel.simulatePurchase,
                                          onRevoke: viewModel.revokeEntitlement)
                #endif
            }
            .padding()
        }
        .background(Theme.background.ignoresSafeArea())
        .navigationTitle(L10n.Paywall.navigationTitle)
        .onAppear { viewModel.refreshPrice() }
        .onReceive(purchases.$isPro) { isPro in
            if isPro { dismiss() }
        }
    }
}

private struct PaywallHeader: View {
    let price: String
    let isProcessing: Bool

    var body: some View {
        VStack(spacing: 12) {
            Text(L10n.Paywall.title)
                .font(.largeTitle)
                .bold()
                .multilineTextAlignment(.center)
            Text(L10n.Paywall.subtitle)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            if price.isEmpty || isProcessing {
                ProgressView()
                    .accessibilityLabel(Text("Loading price"))
            } else {
                Text(L10n.Paywall.buyTitle(price))
                    .font(.headline)
                    .foregroundColor(.primary)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .cardBackground()
    }
}

private struct BenefitHighlights: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Paywall.benefitsTitle)
                .font(.headline)
            VStack(alignment: .leading, spacing: 8) {
                BenefitRow(icon: "sparkles", text: L10n.Paywall.Benefit.exports)
                BenefitRow(icon: "arrow.triangle.2.circlepath", text: L10n.Paywall.Benefit.recovery)
                BenefitRow(icon: "person.2.crop.square.stack", text: L10n.Paywall.Benefit.support)
            }
        }
        .cardBackground()
    }
}

private struct BenefitRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Theme.accent)
            Text(text)
                .font(.subheadline)
        }
    }
}

private struct ComparisonTable: View {
    private let rows: [(String, String, String)] = [
        (L10n.Paywall.Comparison.advancedExports,
         L10n.Paywall.Comparison.valueLimited,
         L10n.Paywall.Comparison.valueIncluded),
        (L10n.Paywall.Comparison.detections,
         L10n.Paywall.Comparison.valueNotAvailable,
         L10n.Paywall.Comparison.valueIncluded),
        (L10n.Paywall.Comparison.watermark,
         L10n.Paywall.Comparison.valueNotAvailable,
         L10n.Paywall.Comparison.valueIncluded),
        (L10n.Paywall.Comparison.ads,
         L10n.Paywall.Comparison.valueNotAvailable,
         L10n.Paywall.Comparison.valueRemoved),
        (L10n.Paywall.Comparison.support,
         L10n.Paywall.Comparison.valueNotAvailable,
         L10n.Paywall.Comparison.valueIncluded)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Paywall.comparisonTitle)
                .font(.headline)

            VStack(spacing: 0) {
                HStack {
                    Text("")
                    Spacer()
                    Text(L10n.Paywall.Comparison.free).font(.subheadline).foregroundColor(.secondary)
                    Text(L10n.Paywall.Comparison.pro).font(.subheadline).bold()
                }
                .padding(.horizontal, 4)

                Divider()

                ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.0)
                            .font(.subheadline)
                        Spacer()
                        Text(row.1)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 90, alignment: .leading)
                        Text(row.2)
                            .font(.caption)
                            .fontWeight(.semibold)
                            .frame(width: 90, alignment: .leading)
                    }
                    .padding(.vertical, 8)
                    if index < rows.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .cardBackground()
    }
}

private struct FAQSection: View {
    @State private var expanded = Set<Int>()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.Paywall.faqTitle)
                .font(.headline)
            FAQItem(index: 0,
                    question: L10n.Paywall.FAQ.syncQuestion,
                    answer: L10n.Paywall.FAQ.syncAnswer,
                    expanded: $expanded)
            FAQItem(index: 1,
                    question: L10n.Paywall.FAQ.restoreQuestion,
                    answer: L10n.Paywall.FAQ.restoreAnswer,
                    expanded: $expanded)
            FAQItem(index: 2,
                    question: L10n.Paywall.FAQ.trialQuestion,
                    answer: L10n.Paywall.FAQ.trialAnswer,
                    expanded: $expanded)
        }
        .cardBackground()
    }
}

private struct FAQItem: View {
    let index: Int
    let question: String
    let answer: String
    @Binding var expanded: Set<Int>

    var body: some View {
        DisclosureGroup(isExpanded: Binding(
            get: { expanded.contains(index) },
            set: { newValue in
                if newValue {
                    expanded.insert(index)
                } else {
                    expanded.remove(index)
                }
            }
        )) {
            Text(answer)
                .font(.footnote)
                .foregroundColor(.secondary)
                .padding(.top, 4)
        } label: {
            Text(question)
                .font(.subheadline)
                .bold()
        }
    }
}

private struct PaywallActions: View {
    let price: String
    let isProcessing: Bool
    let onBuy: () -> Void
    let onRestore: () -> Void
    let onContinue: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Button {
                onBuy()
            } label: {
                HStack {
                    Text(price.isEmpty ? L10n.Paywall.title : L10n.Paywall.buyTitle(price))
                    if isProcessing { ProgressView() }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isProcessing || price.isEmpty)
            .accessibilityHint(L10n.Paywall.buyHint)

            Button {
                onRestore()
            } label: {
                Text(L10n.Paywall.restore)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)
            .accessibilityHint(L10n.Paywall.restoreHint)

            Button {
                onContinue()
            } label: {
                Text(L10n.Paywall.continueFree)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .accessibilityHint(L10n.Paywall.continueHint)
        }
        .cardBackground()
    }
}

#if DEBUG
    private struct DebugPurchaseControls: View {
        let onSimulate: () -> Void
        let onRevoke: () -> Void

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                Text("Debug")
                    .font(.caption)
                    .foregroundColor(.secondary)
                HStack {
                    Button(L10n.Paywall.Debug.simulatePurchase, action: onSimulate)
                    Button(L10n.Paywall.Debug.revokePurchase, action: onRevoke)
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
#endif

private extension View {
    func cardBackground() -> some View {
        padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}
