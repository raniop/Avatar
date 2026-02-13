import SwiftUI

struct ParentDashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @State private var viewModel = ParentDashboardViewModel()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppTheme.Spacing.lg) {
                    // Header
                    if let user = authManager.currentUser {
                        Text("Welcome, \(user.displayName)")
                            .font(AppTheme.Fonts.heading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    // Children list
                    if viewModel.children.isEmpty {
                        AddChildPromptView {
                            viewModel.showAddChild = true
                        }
                    } else {
                        ForEach(viewModel.children) { child in
                            ChildDashboardCard(child: child, viewModel: viewModel)
                        }
                    }

                    // Recent conversations
                    if !viewModel.recentConversations.isEmpty {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text("Recent Conversations")
                                .font(AppTheme.Fonts.bodyBold)

                            ForEach(viewModel.recentConversations) { conversation in
                                ConversationRow(conversation: conversation)
                            }
                        }
                    }
                }
                .padding(AppTheme.Spacing.lg)
            }
            .background(AppTheme.Colors.backgroundLight)
            .navigationTitle("Dashboard")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showAddChild = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddChild) {
                ChildProfileSetupView()
            }
            .task {
                await viewModel.loadData()
            }
        }
    }
}

struct AddChildPromptView: View {
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.primary)

            Text("Add your child's profile")
                .font(AppTheme.Fonts.bodyBold)

            Text("Set up your child's profile to get started with their AI avatar friend")
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button("Add Child", action: onTap)
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.Colors.primary)
        }
        .padding(AppTheme.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
    }
}

struct ChildDashboardCard: View {
    let child: Child
    let viewModel: ParentDashboardViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
            HStack {
                VStack(alignment: .leading) {
                    Text(child.name)
                        .font(AppTheme.Fonts.bodyBold)
                    Text("Age \(child.age)")
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }

                Spacer()

                if child.avatarConfig != nil {
                    Image(systemName: "face.smiling")
                        .font(.title2)
                        .foregroundStyle(AppTheme.Colors.secondary)
                }
            }

            Divider()

            HStack(spacing: AppTheme.Spacing.md) {
                DashboardActionButton(
                    icon: "questionmark.bubble",
                    label: "Questions",
                    action: { viewModel.navigateToQuestions(for: child) }
                )

                DashboardActionButton(
                    icon: "text.bubble",
                    label: "History",
                    action: { viewModel.navigateToHistory(for: child) }
                )

                DashboardActionButton(
                    icon: "chart.line.uptrend.xyaxis",
                    label: "Insights",
                    action: { viewModel.navigateToInsights(for: child) }
                )
            }
        }
        .padding(AppTheme.Spacing.md)
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
    }
}

struct DashboardActionButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title3)
                Text(label)
                    .font(AppTheme.Fonts.caption)
            }
            .frame(maxWidth: .infinity)
        }
        .tint(AppTheme.Colors.primary)
    }
}

struct ConversationRow: View {
    let conversation: Conversation

    var body: some View {
        HStack {
            Circle()
                .fill(conversation.status == .completed ? AppTheme.Colors.secondary : AppTheme.Colors.accent)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading) {
                Text("Conversation")
                    .font(AppTheme.Fonts.body)
                Text(conversation.startedAt, style: .relative)
                    .font(AppTheme.Fonts.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Spacing.sm)
    }
}
