import SwiftUI

struct InsightsView: View {
    let child: Child
    @Environment(AppRouter.self) private var appRouter
    @State private var conversations: [ConversationListItem] = []
    @State private var isLoading = true

    private let apiClient = APIClient.shared
    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(L.analyzing)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if conversations.isEmpty {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))

                    Text(L.noInsightsYet)
                        .font(AppTheme.Fonts.bodyBold)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    Text(L.insightsAppearAfter(child.name))
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Stats overview
                        HStack(spacing: AppTheme.Spacing.md) {
                            StatCard(
                                title: L.total,
                                value: "\(conversations.count)",
                                subtitle: L.conversationsPlural,
                                icon: "bubble.left.and.bubble.right"
                            )

                            StatCard(
                                title: L.completed,
                                value: "\(conversations.filter { $0.status == "COMPLETED" }.count)",
                                subtitle: L.finished,
                                icon: "checkmark.circle"
                            )
                        }

                        // Moods from summaries
                        let moods = conversations.compactMap { $0.summary?.moodAssessment }
                        if !moods.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                Text(L.moodOverview)
                                    .font(AppTheme.Fonts.bodyBold)

                                ForEach(Array(Set(moods)).sorted(), id: \.self) { mood in
                                    let count = moods.filter { $0 == mood }.count
                                    HStack {
                                        Text(mood)
                                            .font(AppTheme.Fonts.body)
                                        Spacer()
                                        Text("\(count)x")
                                            .font(AppTheme.Fonts.caption)
                                            .foregroundStyle(AppTheme.Colors.textSecondary)
                                    }
                                }
                            }
                            .padding()
                            .background(.white)
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                        }

                        // Recent topics
                        let topics = conversations.compactMap { $0.mission?.titleEn }
                        if !topics.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                Text(L.missionTopics)
                                    .font(AppTheme.Fonts.bodyBold)

                                FlowLayout(spacing: 6) {
                                    ForEach(Array(Set(topics)).sorted(), id: \.self) { topic in
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
                    }
                    .padding()
                }
                .background(AppTheme.Colors.backgroundLight)
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .navigationTitle(L.childInsights(child.name))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadData()
        }
    }

    private func loadData() async {
        isLoading = true
        do {
            let wrapper = try await apiClient.getConversations(childId: child.id)
            conversations = wrapper.conversations
        } catch {
            print("Failed to load insights: \(error.localizedDescription)")
        }
        isLoading = false
    }
}

private struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let icon: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(AppTheme.Colors.primary)

            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))

            Text(subtitle)
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
    }
}
