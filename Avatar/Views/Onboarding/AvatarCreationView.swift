import SwiftUI
import PhotosUI

struct AvatarCreationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppRouter.self) private var appRouter
    @State private var viewModel = AvatarCreationViewModel()
    @State private var selectedPhoto: PhotosPickerItem?

    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        ZStack {
            AppTheme.Colors.childGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Avatar preview — tapping the circle opens the photo picker
                PhotosPicker(selection: $selectedPhoto, matching: .images) {
                    ZStack {
                        if let image = viewModel.generatedAvatarImage {
                            // Generated cartoon avatar
                            Image(uiImage: image)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: 220, height: 220)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(.white.opacity(0.3), lineWidth: 3))
                                .shadow(color: .black.opacity(0.2), radius: 10)
                                .transition(.scale.combined(with: .opacity))

                            // Small change-photo badge
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundStyle(.white)
                                        .padding(10)
                                        .background(Circle().fill(.black.opacity(0.45)))
                                }
                            }
                            .frame(width: 220, height: 220)
                        } else {
                            // Placeholder
                            Circle()
                                .fill(.white.opacity(0.15))
                                .frame(width: 220, height: 220)
                                .overlay(
                                    VStack(spacing: 8) {
                                        Image(systemName: "camera.fill")
                                            .font(.system(size: 40))
                                        Text(L.tapToUploadPhoto)
                                            .font(AppTheme.Fonts.caption)
                                            .multilineTextAlignment(.center)
                                    }
                                    .foregroundStyle(.white.opacity(0.6))
                                )
                        }

                        if viewModel.isAnalyzingPhoto {
                            Circle()
                                .fill(.black.opacity(0.5))
                                .frame(width: 220, height: 220)
                            VStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                    .scaleEffect(1.5)
                                Text(L.creatingAvatar)
                                    .font(AppTheme.Fonts.caption)
                                    .foregroundStyle(.white)
                            }
                        }
                    }
                }
                .disabled(viewModel.isAnalyzingPhoto || viewModel.isCreating)
                .padding(.top, AppTheme.Spacing.lg)
                .onChange(of: selectedPhoto) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            await viewModel.generateAvatarFromPhoto(imageData: data)
                        }
                    }
                }

                if let error = viewModel.analysisError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(.horizontal, AppTheme.Spacing.lg)
                        .padding(.top, 4)
                }

                // Name + Create
                ScrollView {
                    VStack(spacing: AppTheme.Spacing.lg) {
                        VStack(alignment: .leading, spacing: AppTheme.Spacing.sm) {
                            Text(L.childNameLabel)
                                .font(AppTheme.Fonts.bodyBold)
                                .foregroundStyle(.white)

                            TextField(L.enterChildName, text: $viewModel.avatarName)
                                .textFieldStyle(.plain)
                                .padding()
                                .background(.white.opacity(0.2))
                                .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.md))
                                .foregroundStyle(.white)
                        }

                        // Create button
                        Button {
                            Task {
                                let success = await viewModel.createAvatar()
                                if success {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if viewModel.isCreating {
                                    ProgressView()
                                        .tint(canCreate ? AppTheme.Colors.primary : .white.opacity(0.5))
                                }
                                Text(viewModel.isCreating ? L.saving : L.createChild)
                            }
                            .font(AppTheme.Fonts.childBody)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(canCreate ? .white : .white.opacity(0.3))
                            .foregroundStyle(canCreate ? AppTheme.Colors.primary : .white.opacity(0.5))
                            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
                        }
                        .disabled(!canCreate || viewModel.isCreating)
                        .padding(.bottom, AppTheme.Spacing.xl)
                    }
                    .padding(.horizontal, AppTheme.Spacing.lg)
                    .padding(.top, AppTheme.Spacing.lg)
                }
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .navigationTitle(L.createChildTitle)
        .navigationBarTitleDisplayMode(.inline)
        .allowsHitTesting(!viewModel.isCreating)
        .onAppear {
            viewModel.childId = appRouter.selectedChild?.id
        }
    }

    private var canCreate: Bool {
        !viewModel.avatarName.isEmpty && viewModel.hasGeneratedAvatar
    }
}
