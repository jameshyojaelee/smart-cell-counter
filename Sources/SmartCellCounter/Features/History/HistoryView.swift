import SwiftUI
import UIKit

@MainActor
final class HistoryViewModel: ObservableObject {
    @Published private(set) var rows: [Sample] = []
    @Published var query: String = ""
    @Published var isLoading = false

    private var searchTask: Task<Void, Never>?

    func loadInitial() {
        scheduleFetch(immediate: true)
    }

    func updateQuery(_ text: String) {
        query = text
        scheduleFetch(immediate: false)
    }

    private func scheduleFetch(immediate: Bool) {
        searchTask?.cancel()
        searchTask = Task { [weak self] in
            guard let self else { return }
            if !immediate {
                try? await Task.sleep(nanoseconds: 300_000_000)
                if Task.isCancelled { return }
            }
            await self.fetch()
        }
    }

    private func fetch() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let records = try await AppDatabase.shared.fetchSamples(matching: query.isEmpty ? nil : query, limit: 200)
            rows = records.map { $0.toSample() }
        } catch {
            Logger.log("History fetch error: \(error)")
            rows = []
        }
    }
}

struct HistoryView: View {
    @StateObject private var viewModel = HistoryViewModel()

    private var searchBinding: Binding<String> {
        Binding(
            get: { viewModel.query },
            set: { viewModel.updateQuery($0) }
        )
    }

    var body: some View {
        VStack(spacing: 8) {
            #if ADS
            if !PurchaseManager.shared.isPro { BannerAdView().frame(height: 50) }
            #endif
            List(viewModel.rows) { sample in
                HistoryRowView(sample: sample)
                    .listRowBackground(Theme.surface)
            }
            .overlay {
                if viewModel.isLoading {
                    ProgressView()
                } else if viewModel.rows.isEmpty {
                    Text("No samples yet.")
                        .foregroundColor(Theme.textSecondary)
                }
            }
            .searchable(text: searchBinding, prompt: "Search project/operator")
            .navigationTitle("History")
        }
        .task {
            viewModel.loadInitial()
        }
    }
}

private struct HistoryRowView: View {
    let sample: Sample

    var body: some View {
        HStack(spacing: 12) {
            HistoryThumbnailView(path: sample.thumbnailPath, size: sample.thumbnailSize)
            VStack(alignment: .leading, spacing: 4) {
                Text(sample.date.formatted(.dateTime))
                    .font(.subheadline)
                    .foregroundColor(Theme.textPrimary)
                Text("Live: \(sample.liveCount)  Dead: \(sample.deadCount)")
                    .font(.caption)
                    .foregroundColor(Theme.textSecondary)
            }
            Spacer()
            Text(String(format: "%.2e", sample.concentrationPerML))
                .font(.caption2)
                .foregroundColor(Theme.textSecondary)
        }
    }
}

private struct HistoryThumbnailView: View {
    let path: String?
    let size: CGSize?
    @State private var image: UIImage?
    @State private var loadTask: Task<Void, Never>?

    private var targetSize: CGSize {
        if let size, size.width > 0, size.height > 0 {
            return size
        }
        return CGSize(width: 56, height: 56)
    }

    var body: some View {
        ZStack {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: targetSize.width, height: targetSize.height)
                    .clipped()
                    .cornerRadius(8)
            } else {
                ZStack {
                    RoundedRectangle(cornerRadius: 8).fill(Theme.card)
                    Image(systemName: "photo").foregroundColor(Theme.textSecondary)
                }
                .frame(width: targetSize.width, height: targetSize.height)
            }
        }
        .task(id: path) { await loadImage() }
    }

    private func loadImage() async {
        loadTask?.cancel()
        guard let path else {
            image = nil
            return
        }
        loadTask = Task.detached(priority: .background) {
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
                  let img = UIImage(data: data) else { return }
            await MainActor.run {
                image = img
            }
        }
        _ = await loadTask?.value
    }
}

private extension SampleRecord {
    func toSample() -> Sample {
        let size = (thumbnailWidth > 0 && thumbnailHeight > 0) ? CGSize(width: thumbnailWidth, height: thumbnailHeight) : nil
        return Sample(
            id: id,
            date: createdAt,
            project: project,
            operatorName: operatorName,
            liveCount: liveTotal,
            deadCount: deadTotal,
            squaresUsed: squaresUsed,
            dilutionFactor: dilutionFactor,
            concentrationPerML: concentrationPerMl,
            thumbnailPath: thumbnailPath,
            thumbnailSize: size,
            pdfPath: pdfPath,
            csvPath: csvPath
        )
    }
}
