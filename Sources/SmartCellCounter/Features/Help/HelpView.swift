import SwiftUI
import UIKit

struct HelpTopic: Identifiable {
    let id = UUID()
    let category: String
    let question: String
    let answer: String
    let tags: [String]
}

struct HelpLink: Identifiable {
    let id = UUID()
    let title: String
    let symbol: String
    let url: URL?
}

struct HelpVideo: Identifiable {
    let id = UUID()
    let title: String
    let description: String
}

final class HelpViewModel: ObservableObject {
    @Published var query: String = ""

    let topics: [HelpTopic] = [
        HelpTopic(category: "Capture", question: "How do I avoid glare?", answer: "Tilt the plate slightly and ensure lights are not reflecting directly into the camera. Use the torch sparingly.", tags: ["capture","glare"]),
        HelpTopic(category: "Counting", question: "Which borders should I include?", answer: "Include cells touching the top and left borders; exclude cells touching the bottom and right borders.", tags: ["counting","rules"]),
        HelpTopic(category: "Results", question: "What does the viability percentage mean?", answer: "Viability is calculated as live cells divided by total cells, multiplied by 100.", tags: ["results","viability"]),
        HelpTopic(category: "Storage", question: "Where are my samples saved?", answer: "Samples are stored locally in the app's Documents folder. Export CSV or PDF from the Results screen for backup.", tags: ["storage","export"])
    ]

    let quickLinks: [HelpLink] = [
        HelpLink(title: "Troubleshooting Checklist", symbol: "wrench.and.screwdriver", url: URL(string: "https://www.smartcellcounter.com/support")),
        HelpLink(title: "Submit Feedback", symbol: "envelope", url: URL(string: "mailto:support@smartcellcounter.com")),
        HelpLink(title: "View Release Notes", symbol: "doc.text", url: URL(string: "https://www.smartcellcounter.com/releases"))
    ]

    let videos: [HelpVideo] = [
        HelpVideo(title: "Capturing the Grid", description: "Placeholder video showing best framing practices."),
        HelpVideo(title: "Reviewing Results", description: "Walkthrough of the Review screen and overlays.")
    ]

    var filteredTopics: [HelpTopic] {
        let normalized = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalized.isEmpty else { return topics }
        return topics.filter { topic in
            topic.question.localizedCaseInsensitiveContains(normalized) ||
            topic.answer.localizedCaseInsensitiveContains(normalized) ||
            topic.tags.contains { $0.localizedCaseInsensitiveContains(normalized) }
        }
    }
}

struct HelpView: View {
    @Environment(\.openURL) private var openURL
    @StateObject private var viewModel = HelpViewModel()

    var body: some View {
        List {
            if !viewModel.filteredTopics.isEmpty {
                Section(header: Text("FAQs")) {
                    ForEach(viewModel.filteredTopics) { topic in
                        VStack(alignment: .leading, spacing: 6) {
                            Text(topic.question)
                                .font(.headline)
                                .foregroundColor(Theme.textPrimary)
                            Text(topic.answer)
                                .font(.subheadline)
                                .foregroundColor(Theme.textSecondary)
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            Section(header: Text("Quick Links")) {
                ForEach(viewModel.quickLinks) { link in
                    Button {
                        if let url = link.url {
                            openURL(url)
                        }
                    } label: {
                        Label(link.title, systemImage: link.symbol)
                    }
                }
            }

            Section(header: Text("Tutorial Videos")) {
                ForEach(viewModel.videos) { video in
                    VStack(alignment: .leading, spacing: 8) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Theme.surface)
                                .frame(height: 160)
                            Image(systemName: "play.circle.fill")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 48, height: 48)
                                .foregroundColor(Theme.accent)
                        }
                        Text(video.title)
                            .font(.headline)
                            .foregroundColor(Theme.textPrimary)
                        Text(video.description)
                            .font(.footnote)
                            .foregroundColor(Theme.textSecondary)
                    }
                    .padding(.vertical, 6)
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $viewModel.query, prompt: "Search help topics")
        .navigationTitle("Help")
        .appBackground()
    }
}
