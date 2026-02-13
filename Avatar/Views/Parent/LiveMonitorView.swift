import SwiftUI

struct LiveMonitorView: View {
    let conversation: Conversation
    @State private var viewModel: LiveMonitorViewModel

    init(conversation: Conversation) {
        self.conversation = conversation
        self._viewModel = State(initialValue: LiveMonitorViewModel(conversation: conversation))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Live transcript
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                        ForEach(viewModel.messages) { message in
                            LiveTranscriptBubble(message: message)
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
                TextField("Send guidance to avatar...", text: $viewModel.interventionText)
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
        .navigationTitle("Live Monitor")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .status) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(.red)
                        .frame(width: 8, height: 8)
                    Text("LIVE")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        }
        .onAppear { viewModel.startWatching() }
        .onDisappear { viewModel.stopWatching() }
    }
}

struct LiveTranscriptBubble: View {
    let message: Message

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
        case .child: "Child"
        case .avatar: "Avatar"
        case .parentIntervention: "You (intervention)"
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
