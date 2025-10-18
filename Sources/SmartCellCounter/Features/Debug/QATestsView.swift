import SwiftUI

struct QACase: Identifiable {
    let id = UUID()
    let assetName: String
    let expectedMin: Int
    let expectedMax: Int
}

@MainActor
final class QATestsViewModel: ObservableObject {
    @Published var results: [(name: String, count: Int, pass: Bool, ms: Double)] = []
    @Published var isRunning = false

    let cases: [QACase] = (1...10).map { i in QACase(assetName: String(format: "fixture%02d", i), expectedMin: 50, expectedMax: 500) }

    func runAll() {
        isRunning = true
        results.removeAll()
        Task.detached { [cases] in
            var out: [(String, Int, Bool, Double)] = []
            for c in cases {
                if let ui = UIImage(named: c.assetName) {
                    let start = Date()
                    let seg = ImagingPipeline.segmentCells(in: ui, params: ImagingParams())
                    let objs = ImagingPipeline.objectFeatures(from: seg, pxPerMicron: nil)
                    let elapsed = Date().timeIntervalSince(start) * 1000
                    let pass = objs.count >= c.expectedMin && objs.count <= c.expectedMax && elapsed < 5000
                    out.append((c.assetName, objs.count, pass, elapsed))
                } else {
                    out.append((c.assetName, -1, false, 0))
                }
            }
            await MainActor.run {
                self.results = out
                self.isRunning = false
            }
        }
    }
}

struct QATestsView: View {
    @StateObject private var vm = QATestsViewModel()
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("QA Fixtures").font(.title2).bold()
            Button(vm.isRunning ? "Running..." : "Run All") { vm.runAll() }
                .buttonStyle(.borderedProminent)
                .disabled(vm.isRunning)
            List(vm.results, id: \.0) { r in
                HStack {
                    Text(r.0).frame(width: 100, alignment: .leading)
                    Spacer()
                    Text("Count: \(r.1 >= 0 ? String(r.1) : "missing")")
                    Text(String(format: "%.0f ms", r.3)).foregroundColor(.secondary)
                    Image(systemName: r.2 ? "checkmark.seal.fill" : "xmark.seal.fill")
                        .foregroundColor(r.2 ? .green : .red)
                }
            }
        }
        .padding()
        .navigationTitle("QA")
    }
}

