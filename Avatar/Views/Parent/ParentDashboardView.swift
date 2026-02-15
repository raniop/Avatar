import SwiftUI

struct ParentDashboardView: View {
    @Environment(AuthManager.self) private var authManager
    @Environment(AppRouter.self) private var appRouter
    @State private var viewModel = ParentDashboardViewModel()
    @State private var childToDelete: Child?

    private var L: AppLocale { appRouter.currentLocale }
    private var multipleChildren: Bool { viewModel.children.count > 1 }

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        // Header
                        if let user = authManager.currentUser {
                            Text(L.welcomeUser(user.displayName))
                                .font(AppTheme.Fonts.heading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        // Children list
                        if viewModel.isLoading && viewModel.children.isEmpty {
                            ProgressView(L.loading)
                                .frame(maxWidth: .infinity)
                                .padding(.top, 60)
                        } else if viewModel.children.isEmpty {
                            AddChildPromptView(locale: L) {
                                viewModel.showAddChild = true
                            }
                        } else {
                            ForEach(viewModel.children) { child in
                                ChildDashboardCard(child: child, locale: L) {
                                    childToDelete = child
                                }
                            }
                        }

                        // Recent conversations
                        if !viewModel.recentConversations.isEmpty {
                            VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                Text(L.recentConversations)
                                    .font(AppTheme.Fonts.bodyBold)

                                ForEach(viewModel.recentConversations) { item in
                                    ConversationListRow(
                                        item: item.conversation,
                                        childName: multipleChildren ? item.childName : nil,
                                        locale: L
                                    )
                                }
                            }
                        }
                    }
                    .padding(AppTheme.Spacing.lg)
                }
                .environment(\.layoutDirection, L.layoutDirection)
                .background(AppTheme.Colors.backgroundLight)

                // Deletion loading overlay
                if viewModel.isDeleting {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                    ProgressView()
                        .scaleEffect(1.5)
                        .tint(.white)
                }
            }
            .navigationTitle(L.dashboard)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        viewModel.showAddChild = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $viewModel.showAddChild, onDismiss: {
                Task { await viewModel.loadData() }
            }) {
                NewChildFlowView()
            }
            .task {
                await viewModel.loadData()
            }
            .alert(
                L.delete,
                isPresented: Binding(
                    get: { childToDelete != nil },
                    set: { if !$0 { childToDelete = nil } }
                )
            ) {
                Button(L.cancel, role: .cancel) {
                    childToDelete = nil
                }
                Button(L.delete, role: .destructive) {
                    if let child = childToDelete {
                        Task {
                            await viewModel.deleteChild(child)
                            childToDelete = nil
                            if viewModel.children.isEmpty {
                                appRouter.switchRole()
                            }
                        }
                    }
                }
            } message: {
                if let child = childToDelete {
                    Text(L.deleteChildConfirm(child.name))
                }
            }
        }
    }
}

struct AddChildPromptView: View {
    let locale: AppLocale
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: AppTheme.Spacing.md) {
            Image(systemName: "person.badge.plus")
                .font(.system(size: 48))
                .foregroundStyle(AppTheme.Colors.primary)

            Text(locale.addChildProfile)
                .font(AppTheme.Fonts.bodyBold)

            Text(locale.addChildDescription)
                .font(AppTheme.Fonts.caption)
                .foregroundStyle(AppTheme.Colors.textSecondary)
                .multilineTextAlignment(.center)

            Button(locale.addChild, action: onTap)
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
    let locale: AppLocale
    var onDelete: (() -> Void)?

    @State private var avatarImage: UIImage?

    var body: some View {
        VStack(spacing: 0) {
            // Avatar hero section
            ZStack(alignment: .topTrailing) {
                // Gradient background behind the avatar
                LinearGradient(
                    colors: [
                        AppTheme.Colors.primary.opacity(0.12),
                        AppTheme.Colors.primary.opacity(0.04)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 130)

                // Avatar + name centered
                VStack(spacing: AppTheme.Spacing.sm) {
                    if let image = avatarImage {
                        Circle()
                            .fill(.clear)
                            .frame(width: 80, height: 80)
                            .overlay {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                            }
                            .clipShape(Circle())
                            .overlay(
                                Circle()
                                    .stroke(
                                        LinearGradient(
                                            colors: [AppTheme.Colors.primary.opacity(0.5), AppTheme.Colors.primary.opacity(0.15)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        ),
                                        lineWidth: 3
                                    )
                            )
                            .shadow(color: AppTheme.Colors.primary.opacity(0.2), radius: 8, y: 4)
                    } else {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [AppTheme.Colors.primary.opacity(0.15), AppTheme.Colors.primary.opacity(0.08)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(child.name.prefix(1)).uppercased())
                                    .font(.system(size: 32, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.Colors.primary)
                            )
                            .overlay(
                                Circle()
                                    .stroke(AppTheme.Colors.primary.opacity(0.2), lineWidth: 2)
                            )
                    }

                    VStack(spacing: 2) {
                        Text(child.name)
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                        Text(locale.childAge(child.age))
                            .font(AppTheme.Fonts.caption)
                            .foregroundStyle(AppTheme.Colors.textSecondary)
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.top, AppTheme.Spacing.md)

                // Delete button
                if let onDelete {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 13))
                            .foregroundStyle(.red.opacity(0.4))
                            .padding(10)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, AppTheme.Spacing.sm)
                    .padding(.trailing, AppTheme.Spacing.sm)
                }
            }

            Divider()
                .padding(.horizontal, AppTheme.Spacing.md)

            // Action buttons
            HStack(spacing: 0) {
                NavigationLink {
                    QuestionsListView(child: child)
                } label: {
                    DashboardActionLabel(
                        icon: "questionmark.bubble",
                        label: locale.questions
                    )
                }

                NavigationLink {
                    ConversationHistoryView(child: child)
                } label: {
                    DashboardActionLabel(
                        icon: "text.bubble",
                        label: locale.history
                    )
                }

                NavigationLink {
                    InsightsView(child: child)
                } label: {
                    DashboardActionLabel(
                        icon: "chart.line.uptrend.xyaxis",
                        label: locale.insights
                    )
                }
            }
            .padding(.vertical, AppTheme.Spacing.sm)
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 10, y: 4)
        .task {
            if let saved = await AvatarStorage.shared.loadAvatar(childId: child.id) {
                avatarImage = saved.image
            }
        }
    }
}

struct DashboardActionLabel: View {
    let icon: String
    let label: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
            Text(label)
                .font(AppTheme.Fonts.caption)
        }
        .frame(maxWidth: .infinity)
        .foregroundStyle(AppTheme.Colors.primary)
    }
}

struct ConversationListRow: View {
    let item: ConversationListItem
    let childName: String?
    let locale: AppLocale

    var body: some View {
        HStack {
            Circle()
                .fill(item.status == "COMPLETED" ? AppTheme.Colors.secondary : AppTheme.Colors.accent)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                // Mission title
                Text(missionTitle)
                    .font(AppTheme.Fonts.body)

                HStack(spacing: 4) {
                    // Child name badge (when multiple children)
                    if let childName {
                        Text(childName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(AppTheme.Colors.primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.Colors.primary.opacity(0.1))
                            .clipShape(Capsule())
                    }

                    Text(item.startedAt, style: .relative)
                        .font(AppTheme.Fonts.caption)
                        .foregroundStyle(AppTheme.Colors.textSecondary)
                }
            }

            Spacer()

            if let summary = item.summary {
                Text(summary.moodAssessment ?? "")
                    .font(AppTheme.Fonts.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }

            Image(systemName: "chevron.right")
                .foregroundStyle(AppTheme.Colors.textSecondary)
        }
        .padding(AppTheme.Spacing.sm)
    }

    private var missionTitle: String {
        guard let mission = item.mission else { return locale.conversation }
        return locale == .hebrew ? mission.titleHe : mission.titleEn
    }
}
