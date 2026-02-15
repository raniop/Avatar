import SwiftUI

struct LiveMonitorView: View {
    let conversation: Conversation
    @Environment(AuthManager.self) private var authManager
    @Environment(AppRouter.self) private var appRouter
    @State private var viewModel: LiveMonitorViewModel?

    private var L: AppLocale { appRouter.currentLocale }

    init(conversation: Conversation) {
        self.conversation = conversation
    }

    var body: some View {
        Group {
            if let viewModel {
                VStack(spacing: 0) {
                    // Live transcript
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                                ForEach(viewModel.messages) { message in
                                    LiveTranscriptBubble(message: message, locale: L)
                                        .id(message.id)
                                }
                            }
                            .padding()
                        }
                        .onChange(of: viewModel.messages.count) { _, _ in
                            if let lastId = viewModel.messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(lastId, anchor: .bottom)
                                }
                            }
                        }
                    }

                    Divider()

                    // Intervention input
                    HStack(spacing: AppTheme.Spacing.sm) {
                        TextField(L.sendGuidance, text: Binding(
                            get: { viewModel.interventionText },
                            set: { viewModel.interventionText = $0 }
                        ))
                            .textFieldStyle(.roundedBorder)

                        Button {
                            viewModel.sendIntervention()
                        } label: {
                            Image(systemName: "paperplane.fill")
                                .foregroundStyle(AppTheme.Colors.primary)
                        }
                        .disabled(viewModel.interventionText.isEmpty)
                    }
                    .padding()
                }
            } else {
                ProgressView(L.connecting)
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .navigationTitle(L.liveMonitor)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .status) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text(L.live)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear {
            if viewModel == nil {
                let parentId = authManager.currentUser?.id ?? ""
                viewModel = LiveMonitorViewModel(conversation: conversation, parentUserId: parentId)
            }
            viewModel?.startWatching()
        }
        .onDisappear { viewModel?.stopWatching() }
    }
}

struct LiveTranscriptBubble: View {
    let message: Message
    let locale: AppLocale

    var body: some View {
        HStack {
            if message.role == .child { Spacer() }

            VStack(alignment: message.role == .child ? .trailing : .leading, spacing: 2) {
                Text(roleName)
                    .font(.caption2)
                    .foregroundStyle(AppTheme.Colors.textSecondary)

                Text(message.textContent)
                    .font(AppTheme.Fonts.body)
                    .foregroundStyle(message.role == .child ? .white : AppTheme.Colors.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(bubbleColor)
                    .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
            }

            if message.role != .child { Spacer() }
        }
    }

    private var roleName: String {
        switch message.role {
        case .child: locale.childRole
        case .avatar: locale.avatarRole
        case .parentIntervention: locale.youIntervention
        default: ""
        }
    }

    private var bubbleColor: Color {
        switch message.role {
        case .child: AppTheme.Colors.primary
        case .avatar: Color.gray.opacity(0.15)
        case .parentIntervention: AppTheme.Colors.accent.opacity(0.3)
        default: Color.clear
        }
    }
}
