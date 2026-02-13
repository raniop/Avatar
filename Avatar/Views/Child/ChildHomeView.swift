import SwiftUI

struct ChildHomeView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var viewModel = ChildHomeViewModel()

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
                        // Avatar greeting
                        if viewModel.hasAvatar {
                            VStack(spacing: AppTheme.Spacing.md) {
                                // Show the AI-generated cartoon avatar
                                if let image = viewModel.avatarImage {
                                    Image(uiImage: image)
                                        .resizable()
                                        .aspectRatio(contentMode: .fill)
                                        .frame(width: 200, height: 200)
                                        .clipShape(Circle())
                                        .overlay(Circle().stroke(.white.opacity(0.4), lineWidth: 3))
                                        .shadow(color: .black.opacity(0.2), radius: 10)
                                }

                                Text("Hi there! I'm \(viewModel.avatarName ?? "")!")
                                    .font(AppTheme.Fonts.childLarge)
                                    .foregroundStyle(.white)

                                Text("Ready for an adventure?")
                                    .font(AppTheme.Fonts.childBody)
                                    .foregroundStyle(.white.opacity(0.9))

                                // Option to recreate avatar
                                NavigationLink {
                                    AvatarCreationView()
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: "arrow.triangle.2.circlepath")
                                        Text("Change Avatar")
                                    }
                                    .font(AppTheme.Fonts.caption)
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(.white.opacity(0.15))
                                    .clipShape(Capsule())
                                }
                            }
                            .padding(.top, AppTheme.Spacing.xxl)
                        } else {
                            // No avatar yet - show create prompt
                            VStack(spacing: AppTheme.Spacing.md) {
                                Image(systemName: "wand.and.stars")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.white)

                                Text("Create Your Avatar!")
                                    .font(AppTheme.Fonts.childLarge)
                                    .foregroundStyle(.white)

                                NavigationLink {
                                    AvatarCreationView()
                                } label: {
                                    Text("Let's Go!")
                                        .font(AppTheme.Fonts.childBody)
                                        .foregroundStyle(AppTheme.Colors.primary)
                                        .padding(.horizontal, AppTheme.Spacing.xl)
                                        .padding(.vertical, AppTheme.Spacing.md)
                                        .background(.white)
                                        .clipShape(Capsule())
                                }
                            }
                            .padding(.top, AppTheme.Spacing.xxl)
                        }

                        // Mission selection
                        if viewModel.hasAvatar {
                            VStack(spacing: AppTheme.Spacing.md) {
                                Text("Choose Your Mission")
                                    .font(AppTheme.Fonts.childBody)
                                    .foregroundStyle(.white)

                                MissionCarouselView(
                                    missions: viewModel.availableMissions,
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
            .navigationBarHidden(true)
            .task {
                await viewModel.loadData()
            }
        }
    }
}
