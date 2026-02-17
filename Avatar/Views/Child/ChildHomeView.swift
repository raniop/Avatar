import SwiftUI

struct ChildHomeView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var viewModel = ChildHomeViewModel()

    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        NavigationStack {
            ZStack {
                // Playful gradient background
                LinearGradient(
                    colors: [
                        Color(hex: "74B9FF"),
                        Color(hex: "A29BFE"),
                        Color(hex: "FD79A8")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: AppTheme.Spacing.xl) {
                        // Switch child button — only when more than one child
                        if let children = appRouter.cachedChildren, children.count > 1 {
                            HStack {
                                if L == .hebrew { Spacer() }
                                Button {
                                    appRouter.switchChild()
                                } label: {
                                    HStack(spacing: 4) {
                                        Image(systemName: L == .hebrew ? "chevron.right" : "chevron.left")
                                        Text(L.switchChild)
                                    }
                                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.85))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.2), in: Capsule())
                                }
                                if L != .hebrew { Spacer() }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        }

                        // Avatar greeting — child + friend side by side
                        VStack(spacing: AppTheme.Spacing.md) {
                            HStack(spacing: 16) {
                                // Friend's preset avatar (if chosen) — on the right in RTL
                                if let presetId = viewModel.friendPresetId,
                                   let friendImage = UIImage(named: "avatar_preset_\(presetId)") {
                                    VStack(spacing: -6) {
                                        AnimatedAvatarView(image: friendImage, size: 120)
                                        Text(viewModel.friendName ?? "")
                                            .font(.system(size: 16, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                }

                                // Child's own AI-generated avatar
                                VStack(spacing: -6) {
                                    if let image = viewModel.avatarImage {
                                        AnimatedAvatarView(image: image, size: 120)
                                    } else {
                                        Circle()
                                            .fill(.white.opacity(0.2))
                                            .frame(width: 120, height: 120)
                                            .overlay(
                                                Image(systemName: "face.smiling.inverse")
                                                    .font(.system(size: 50))
                                                    .foregroundStyle(.white.opacity(0.6))
                                            )
                                    }
                                    Text(viewModel.child?.name ?? "")
                                        .font(.system(size: 16, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }

                            Text(L.childGreeting(viewModel.child?.name ?? ""))
                                .font(AppTheme.Fonts.childLarge)
                                .foregroundStyle(.white)

                            Text(L.readyForAdventure(gender: viewModel.child?.gender))
                                .font(AppTheme.Fonts.childBody)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.top, AppTheme.Spacing.xxl)

                        // Star counter (adventure progress)
                        if viewModel.totalStars > 0 {
                            HStack(spacing: 6) {
                                Text("⭐")
                                    .font(.system(size: 20))
                                Text("\(viewModel.totalStars)")
                                    .font(.system(size: 18, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text(L.starsCollected)
                                    .font(.system(size: 14, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.8))
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(.white.opacity(0.2), in: Capsule())
                        }

                        // Mission selection — always shown
                        VStack(spacing: AppTheme.Spacing.md) {
                            Text(L.chooseYourMission(gender: viewModel.child?.gender))
                                .font(AppTheme.Fonts.childBody)
                                .foregroundStyle(.white)

                            if viewModel.isLoading && viewModel.availableMissions.isEmpty {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.2)
                                    .padding(.top, 20)
                            } else if viewModel.availableMissions.isEmpty {
                                Text(L.noMissions)
                                    .font(AppTheme.Fonts.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.top, 10)
                            } else {
                                MissionCarouselView(
                                    missions: viewModel.availableMissions,
                                    locale: L,
                                    onSelect: { mission in
                                        viewModel.startMission(mission)
                                    }
                                )
                            }
                        }

                        Spacer().frame(height: AppTheme.Spacing.xxl)
                    }
                }
            }
            .environment(\.layoutDirection, L.layoutDirection)
            .navigationBarHidden(true)
            .task(id: appRouter.currentLocale) {
                if let selectedChild = appRouter.selectedChild {
                    viewModel.configure(with: selectedChild)
                }
                await viewModel.loadData()
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
                // Reload friend data when app returns to foreground or after setup overlay dismisses
                viewModel.reloadFriendData()
            }
            .onReceive(NotificationCenter.default.publisher(for: .friendSetupCompleted)) { _ in
                viewModel.reloadFriendData()
            }
            .fullScreenCover(isPresented: $viewModel.showConversation) {
                if let child = viewModel.child,
                   let mission = viewModel.selectedMission {
                    AdventureView(
                        viewModel: AdventureViewModel(
                            child: child,
                            mission: mission
                        )
                    )
                }
            }
            .onChange(of: viewModel.showConversation) { _, isShowing in
                if !isShowing {
                    // Reload progress after returning from adventure
                    Task { await viewModel.refreshProgress() }
                }
            }
        }
    }
}
