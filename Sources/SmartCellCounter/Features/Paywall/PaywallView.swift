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
                Text("Smart Cell Counter Pro").font(.title).bold()
                Text("One-time purchase").foregroundColor(.secondary)
                FeatureList()
                if !vm.price.isEmpty {
                    Button("Buy for \(vm.price)") { Task { await vm.buy(); if vm.purchases.isPro { dismiss() } } }
                        .buttonStyle(.borderedProminent)
                        .disabled(vm.isPurchasing)
                } else {
                    ProgressView().onAppear { vm.refreshPrice() }
                }
                Button("Restore Purchases") { Task { await vm.restore(); if vm.purchases.isPro { dismiss() } } }
                Button("Continue Free") { dismiss() }.foregroundColor(.secondary)
            }
            .padding()
        }
        .navigationTitle("Pro Upgrade")
        .onAppear { vm.refreshPrice() }
    }
}

private struct FeatureList: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("No watermark on PDFs", systemImage: "checkmark.seal")
            Label("Advanced options + batch export", systemImage: "checkmark.seal")
            Label("ML refine always on", systemImage: "checkmark.seal")
            Label("Ad-free experience", systemImage: "checkmark.seal")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
