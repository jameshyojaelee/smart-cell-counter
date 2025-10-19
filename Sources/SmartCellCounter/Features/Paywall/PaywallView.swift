import SwiftUI

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var price: String = ""
    @Published var isPurchasing = false
    let purchases = PurchaseManager.shared
    func refreshPrice() { price = purchases.price ?? "" }
    func buy() async {
        isPurchasing = true
        defer { isPurchasing = false }
        try? await purchases.purchase()
    }
    func restore() async { try? await purchases.restore() }
}

struct PaywallView: View {
    @StateObject private var vm = PaywallViewModel()
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text(L10n.Paywall.title).font(.title).bold()
                Text(L10n.Paywall.subtitle).foregroundColor(.secondary)
                FeatureList()
                if !vm.price.isEmpty {
                    Button(L10n.Paywall.buyTitle(vm.price)) {
                        Task {
                            await vm.buy()
                            if vm.purchases.isPro { dismiss() }
                        }
                    }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.isPurchasing)
                        .accessibilityHint(L10n.Paywall.buyHint)
                } else {
                    ProgressView().onAppear { vm.refreshPrice() }
                }
                Button(L10n.Paywall.restore) {
                    Task {
                        await vm.restore()
                        if vm.purchases.isPro { dismiss() }
                    }
                }
                .accessibilityHint(L10n.Paywall.restoreHint)
                Button(L10n.Paywall.continueFree) { dismiss() }
                    .foregroundColor(.secondary)
                    .accessibilityHint(L10n.Paywall.continueHint)
            }
            .padding()
        }
        .navigationTitle(L10n.Paywall.navigationTitle)
        .onAppear { vm.refreshPrice() }
    }
}

private struct FeatureList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(L10n.Paywall.Feature.noWatermark, systemImage: "checkmark.seal")
            Label(L10n.Paywall.Feature.advanced, systemImage: "checkmark.seal")
            Label(L10n.Paywall.Feature.mlRefine, systemImage: "checkmark.seal")
            Label(L10n.Paywall.Feature.adFree, systemImage: "checkmark.seal")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .contain)
    }
}
