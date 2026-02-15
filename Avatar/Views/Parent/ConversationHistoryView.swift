import SwiftUI

struct ConversationHistoryView: View {
    let child: Child
    @Environment(AppRouter.self) private var appRouter
    @State private var conversations: [ConversationListItem] = []
    @State private var isLoading = true

    private let apiClient = APIClient.shared
    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        Group {
            if isLoading {
                ProgressView(L.loadingConversations)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if conversations.isEmpty {
                VStack(spacing: AppTheme.Spacing.md) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 48))
                        .foregroundStyle(AppTheme.Colors.textSecondary.opacity(0.5))

                    Text(L.noConversationsYet)
                        .font(AppTheme.Fonts.bodyBold)
                        .foregroundStyle(AppTheme.Colors.textSecondary)

                    Text(L.noConversationsDesc(child.name))
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List(conversations) { item in
                    NavigationLink {
                        ConversationDetailView(conversation: Conversation(
                            id: item.id,
                            childId: child.id,
                            missionId: item.missionId,
                            status: ConversationStatus(rawValue: item.status) ?? .active,
                            locale: AppLocale(rawValue: item.locale) ?? .english,
                            startedAt: item.startedAt,
                            endedAt: item.endedAt
                        ))
                    } label: {
                        HStack {
                            Circle()
                                .fill(item.status == "COMPLETED" ? AppTheme.Colors.secondary : AppTheme.Colors.accent)
                                .frame(width: 10, height: 10)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.mission?.titleEn ?? L.conversation)
                                    .font(AppTheme.Fonts.body)

                                HStack {
                                    Text(item.startedAt, style: .date)
                                    Text(item.startedAt, style: .time)
                                }
                                .font(AppTheme.Fonts.caption)
                                .foregroundStyle(AppTheme.Colors.textSecondary)

                                if let duration = item.durationSeconds {
                                    Text("\(duration / 60) \(L.minuteSuffix)")
                                        .font(AppTheme.Fonts.caption)
                                        .foregroundStyle(AppTheme.Colors.textSecondary)
                                }
                            }

                            Spacer()

                            if let summary = item.summary {
                                Text(summary.moodAssessment ?? "")
                                    .font(AppTheme.Fonts.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(AppTheme.Colors.primary.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .navigationTitle(L.childHistory(child.name))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadConversations()
        }
    }

    private func loadConversations() async {
        isLoading = true
        do {
            let wrapper = try await apiClient.getConversations(childId: child.id)
            conversations = wrapper.conversations
        } catch {
            print("Failed to load conversations: \(error.localizedDescription)")
        }
        isLoading = false
    }
}
