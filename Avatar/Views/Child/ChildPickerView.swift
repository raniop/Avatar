import SwiftUI

/// Kid-friendly child selection screen shown when tapping "ילד" role
/// and the parent has multiple children.
/// If only one child exists, auto-selects and skips this screen.
struct ChildPickerView: View {
    @Environment(AppRouter.self) private var appRouter

    @State private var children: [Child] = []
    @State private var isLoading = true
    @State private var animateCards = false

    private var L: AppLocale { appRouter.currentLocale }
    private let apiClient = APIClient.shared

    var body: some View {
        ZStack {
            // Same playful gradient as ChildHomeView
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

            VStack(spacing: 32) {
                // Back button to role selection
                HStack {
                    Button {
                        withAnimation(.spring(duration: 0.3)) {
                            appRouter.activeRole = nil
                        }
                    } label: {
                        Image(systemName: "chevron.backward.circle.fill")
                            .font(.system(size: 32))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)

                Spacer()

                // Title
                Text(L.choosePlayer)
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if isLoading {
                    ProgressView()
                        .tint(.white)
                        .scaleEffect(1.5)
                        .padding(.top, 40)
                } else if children.isEmpty {
                    // No children yet
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 56))
                            .foregroundStyle(.white.opacity(0.5))

                        Text(L.noChildrenYet)
                            .font(.system(size: 22, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)

                        Text(L.askParentToSetup)
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))

                        Button {
                            appRouter.activeRole = nil
                        } label: {
                            Text(L.goBack)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(.white.opacity(0.25))
                                .clipShape(Capsule())
                        }
                        .padding(.top, 8)
                    }
                } else {
                    // Child cards
                    let columns = [
                        GridItem(.flexible(), spacing: 20),
                        GridItem(.flexible(), spacing: 20)
                    ]
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(Array(children.enumerated()), id: \.element.id) { index, child in
                            ChildPickerCard(child: child, locale: L) {
                                selectChild(child)
                            }
                            .offset(y: animateCards ? 0 : 40)
                            .opacity(animateCards ? 1 : 0)
                            .animation(
                                .spring(duration: 0.5).delay(Double(index) * 0.12),
                                value: animateCards
                            )
                        }
                    }
                    .padding(.horizontal, 24)
                }

                Spacer()
                Spacer()
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
        .task {
            await loadChildren()
        }
    }

    private func loadChildren() async {
        do {
            children = try await apiClient.getChildren()

            // If only 1 child, auto-select and skip this screen
            if children.count == 1, let only = children.first {
                selectChild(only)
                return
            }

            isLoading = false
            withAnimation {
                animateCards = true
            }
        } catch {
            print("ChildPickerView: Failed to load children: \(error)")
            isLoading = false
        }
    }

    private func selectChild(_ child: Child) {
        withAnimation(.spring(duration: 0.4)) {
            appRouter.selectedChild = child
        }
    }
}

// MARK: - Child Picker Card

private struct ChildPickerCard: View {
    let child: Child
    let locale: AppLocale
    let action: () -> Void

    @State private var avatarImage: UIImage?

    var body: some View {
        Button(action: action) {
            VStack(spacing: 14) {
                // Avatar or placeholder
                if let image = avatarImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(.white.opacity(0.5), lineWidth: 3)
                        )
                        .shadow(color: .black.opacity(0.15), radius: 6, y: 3)
                } else {
                    Circle()
                        .fill(.white.opacity(0.2))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text(String(child.name.prefix(1)).uppercased())
                                .font(.system(size: 44, weight: .bold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.6))
                        )
                }

                Text(child.name)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 28)
            .background(
                RoundedRectangle(cornerRadius: 28)
                    .fill(.white.opacity(0.15))
                    .shadow(color: .black.opacity(0.08), radius: 8, y: 4)
            )
        }
        .buttonStyle(.plain)
        .task {
            // Load per-child avatar
            if let saved = await AvatarStorage.shared.loadAvatar(childId: child.id) {
                avatarImage = saved.image
            }
        }
    }
}
