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
                        // Avatar greeting — always shown
                        VStack(spacing: AppTheme.Spacing.md) {
                            if let image = viewModel.avatarImage {
                                // Show the AI-generated cartoon avatar
                                AnimatedAvatarView(image: image)
                            } else {
                                // Default placeholder avatar
                                Circle()
                                    .fill(.white.opacity(0.2))
                                    .frame(width: 160, height: 160)
                                    .overlay(
                                        Image(systemName: "face.smiling.inverse")
                                            .font(.system(size: 70))
                                            .foregroundStyle(.white.opacity(0.6))
                                    )
                            }

                            Text(L.childGreeting(viewModel.child?.name ?? ""))
                                .font(AppTheme.Fonts.childLarge)
                                .foregroundStyle(.white)

                            Text(L.readyForAdventure(gender: viewModel.child?.gender))
                                .font(AppTheme.Fonts.childBody)
                                .foregroundStyle(.white.opacity(0.9))
                        }
                        .padding(.top, AppTheme.Spacing.xxl)

                        // Mission selection — always shown
                        VStack(spacing: AppTheme.Spacing.md) {
                            Text(L.chooseYourMission)
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
            .fullScreenCover(isPresented: $viewModel.showConversation) {
                if let child = viewModel.child,
                   let mission = viewModel.selectedMission {
                    ConversationView(
                        viewModel: ConversationViewModel(child: child, mission: mission)
                    )
                }
            }
            .overlay {
                if viewModel.isStartingMission {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView()
                                .scaleEffect(1.5)
                                .tint(.white)
                            Text(L.gettingReady)
                                .font(AppTheme.Fonts.childBody)
                                .foregroundStyle(.white)
                        }
                    }
                }
            }
        }
    }
}
