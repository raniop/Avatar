import SwiftUI

struct ConversationDetailView: View {
    let conversation: Conversation
    @State private var summary: ConversationSummary?
    @State private var messages: [Message] = []
    @State private var isLoading = true
    @State private var selectedTab = 0

    private let apiClient = APIClient.shared

    var body: some View {
        VStack(spacing: 0) {
            // Tab picker
            Picker("View", selection: $selectedTab) {
                Text("Summary").tag(0)
                Text("Transcript").tag(1)
            }
            .pickerStyle(.segmented)
            .padding()

            if isLoading {
                Spacer()
                ProgressView()
                Spacer()
            } else {
                if selectedTab == 0 {
                    summaryView
                } else {
                    transcriptView
                }
            }
        }
        .navigationTitle("Conversation Details")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadData() }
    }

    private var summaryView: some View {
        ScrollView {
            if let summary {
                VStack(alignment: .leading, spacing: AppTheme.Spacing.lg) {
                    // Brief summary
                    SummaryCard(title: "Summary", content: summary.briefSummary)

                    // Mood
                    if let mood = summary.moodAssessment {
                        SummaryCard(title: "Mood", content: mood)
                    }

                    // Key topics
                    if !summary.keyTopics.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("Key Topics")
                                .font(AppTheme.Fonts.bodyBold)

                            FlowLayout(spacing: 6) {
                                ForEach(summary.keyTopics, id: \.self) { topic in
                                    Text(topic)
                                        .font(AppTheme.Fonts.caption)
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 4)
                                        .background(AppTheme.Colors.primary.opacity(0.1))
                                        .clipShape(Capsule())
                                }
                            }
                        }
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    }

                    // Question answers
                    if !summary.questionAnswers.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("Your Questions")
                                .font(AppTheme.Fonts.bodyBold)

                            ForEach(summary.questionAnswers, id: \.questionId) { answer in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(answer.childResponse)
                                        .font(AppTheme.Fonts.body)
                                    if let analysis = answer.analysis {
                                        Text(analysis)
                                            .font(AppTheme.Fonts.caption)
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }
                                }
                                .padding()
                                .background(Color.gray.opacity(0.05))
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.sm))
                            }
                        }
                        .padding()
                        .background(.white)
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    }

                    // Engagement
                    if let engagement = summary.engagementLevel {
                        SummaryCard(title: "Engagement", content: "Level: \(engagement)")
                    }

                    // Emotional flags
                    if let flags = summary.emotionalFlags, flags.hasFlags {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Label("Attention", systemImage: "exclamationmark.triangle")
                                .font(AppTheme.Fonts.bodyBold)
                                .foregroundStyle(AppTheme.Colors.danger)

                            ForEach(flags.flags, id: \.self) { flag in
                                Text(flag)
                                    .font(AppTheme.Fonts.body)
                            }

                            if let rec = flags.recommendation {
                                Text(rec)
                                    .font(AppTheme.Fonts.caption)
                                    .foregroundStyle(AppTheme.Colors.textSecondary)
                            }
                        }
                        .padding()
                        .background(AppTheme.Colors.danger.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                    }

                    // Detailed summary
                    SummaryCard(title: "Detailed Analysis", content: summary.detailedSummary)
                }
                .padding()
            } else {
                Text("No summary available yet.")
                    .foregroundStyle(AppTheme.Colors.textSecondary)
                    .padding()
            }
        }
        .background(AppTheme.Colors.backgroundLight)
    }

    private var transcriptView: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                ForEach(messages) { message in
                    LiveTranscriptBubble(message: message)
                }
            }
            .padding()
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            async let summaryTask = apiClient.getConversationSummary(conversationId: conversation.id)
            async let messagesTask = apiClient.getConversationTranscript(conversationId: conversation.id)
            summary = try await summaryTask
            messages = try await messagesTask
        } catch {
            // Partial load is ok
        }
        isLoading = false
    }
}

struct SummaryCard: View {
    let title: String
    let content: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            Text(title)
                .font(AppTheme.Fonts.bodyBold)
            Text(content)
                .font(AppTheme.Fonts.body)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }
}
