import SwiftUI

struct PaywallView: View {
    @StateObject private var viewModel = PaywallViewModel()

    var body: some View {
        VStack(spacing: 12) {
            Text("Smart Cell Counter Pro").font(.title)
            Text("One-time purchase").foregroundColor(.secondary)
            Button("Buy for $4.99") {}
            Button("Restore Purchases") {}
        }
        .padding()
        .navigationTitle("Paywall")
    }
}

final class PaywallViewModel: ObservableObject {}
