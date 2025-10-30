import SwiftUI
import UIKit

struct HelpTopic: Identifiable {
    let id: Int
    var category: String { L10n.Help.Topic.category(id) }
    var question: String { L10n.Help.Topic.question(id) }
    var answer: String { L10n.Help.Topic.answer(id) }
    var tags: [String] { L10n.Help.Topic.tags(id) }
}

struct HelpLink: Identifiable {
    let id: Int
    let symbol: String
    let url: URL?
    var title: String { L10n.Help.Link.title(id) }
    var hint: String { L10n.Help.Link.hint(id) }
}

struct HelpVideo: Identifiable {
    let id: Int
    var title: String { L10n.Help.Video.title(id) }
    var description: String { L10n.Help.Video.description(id) }
}

final class HelpViewModel: ObservableObject {
    @Published var query: String = ""

    let topics: [HelpTopic] = [
        HelpTopic(id: 0),
        HelpTopic(id: 1),
        HelpTopic(id: 2),
        HelpTopic(id: 3),
    ]

    let quickLinks: [HelpLink] = [
        HelpLink(id: 0, symbol: "wrench.and.screwdriver", url: URL(string: "https://www.smartcellcounter.com/support")),
        HelpLink(id: 1, symbol: "envelope", url: URL(string: "mailto:support@smartcellcounter.com")),
        HelpLink(id: 2, symbol: "doc.text", url: URL(string: "https://www.smartcellcounter.com/releases")),
    ]

    let videos: [HelpVideo] = [
        HelpVideo(id: 0),
        HelpVideo(id: 1),
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
                Section(header: Text(L10n.Help.Section.faq)) {
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

            Section(header: Text(L10n.Help.Section.links)) {
                ForEach(viewModel.quickLinks) { link in
                    Button {
                        if let url = link.url {
                            openURL(url)
                        }
                    } label: {
                        Label(link.title, systemImage: link.symbol)
                    }
                    .accessibilityHint(link.hint)
                }
            }

            Section(header: Text(L10n.Help.Section.videos)) {
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
                                .accessibilityHidden(true)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(L10n.Help.videoThumbnailAccessibility)
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
        .searchable(text: $viewModel.query, prompt: Text(L10n.Help.searchPrompt))
        .navigationTitle(L10n.Help.navigationTitle)
        .appBackground()
    }
}
