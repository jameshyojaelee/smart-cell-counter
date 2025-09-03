import SwiftUI

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published var query: String = ""
}

struct HistoryView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel = HistoryViewModel()

    var filtered: [Sample] {
        if viewModel.query.isEmpty { return appState.samples }
        let q = viewModel.query.lowercased()
        return appState.samples.filter { $0.project.lowercased().contains(q) || $0.operatorName.lowercased().contains(q) }
    }

    var body: some View {
        VStack(spacing: 8) {
            #if ADS
            if !PurchaseManager.shared.isPro { BannerAdView().frame(height: 50) }
            #endif
            List(filtered) { s in
                HStack(spacing: 12) {
                    if let img = s.thumbnail {
                        Image(uiImage: img).resizable().scaledToFill().frame(width: 56, height: 56).clipped().cornerRadius(8)
                    } else {
                        ZStack { RoundedRectangle(cornerRadius: 8).fill(Theme.card); Image(systemName: "photo").foregroundColor(Theme.textSecondary) }.frame(width: 56, height: 56)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(s.date.formatted(.dateTime)).font(.subheadline).foregroundColor(Theme.textPrimary)
                        Text("Live: \(s.liveCount)  Dead: \(s.deadCount)").font(.caption).foregroundColor(Theme.textSecondary)
                    }
                    Spacer()
                    Text(String(format: "%.2e", s.concentrationPerML)).font(.caption2).foregroundColor(Theme.textSecondary)
                }
                .listRowBackground(Theme.surface)
            }
            .searchable(text: $viewModel.query, prompt: "Search project/operator")
            .navigationTitle("History")
        }
        .onAppear { loadFromDatabase() }
        .onChange(of: viewModel.query) { _ in loadFromDatabase() }
    }

    private func loadFromDatabase() {
        let rows = (try? AppDatabase.shared.fetchSamples(matching: viewModel.query.isEmpty ? nil : viewModel.query)) ?? []
        var samples: [Sample] = []
        for r in rows {
            var thumb: UIImage? = nil
            if let path = r.imagePath { thumb = UIImage(contentsOfFile: path) }
            let s = Sample(thumbnail: thumb,
                           project: r.project,
                           operatorName: r.operatorName,
                           liveCount: r.liveTotal,
                           deadCount: r.deadTotal,
                           squaresUsed: r.squaresUsed,
                           dilutionFactor: r.dilutionFactor,
                           concentrationPerML: r.concentrationPerMl)
            samples.append(s)
        }
        appState.samples = samples
    }
}
