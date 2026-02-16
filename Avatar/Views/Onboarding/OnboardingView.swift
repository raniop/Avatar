import SwiftUI

struct OnboardingView: View {
    @Environment(AppRouter.self) private var appRouter
    @State private var currentPage = 0

    let onComplete: () -> Void

    private var L: AppLocale { appRouter.currentLocale }

    private var pages: [OnboardingPageData] {
        [
            OnboardingPageData(
                id: 0,
                illustration: .avatarGrid([1, 5, 2, 6]),
                title: L.onboardingWelcomeTitle,
                subtitle: L.onboardingWelcomeSubtitle
            ),
            OnboardingPageData(
                id: 1,
                illustration: .sfSymbol("bubble.left.and.bubble.right.fill"),
                title: L.onboardingSafeConversationsTitle,
                subtitle: L.onboardingSafeConversationsSubtitle
            ),
            OnboardingPageData(
                id: 2,
                illustration: .sfSymbolWithExtras(
                    "map.fill",
                    extras: ["star.fill", "wand.and.stars", "book.fill"]
                ),
                title: L.onboardingAdventuresTitle,
                subtitle: L.onboardingAdventuresSubtitle
            ),
            OnboardingPageData(
                id: 3,
                illustration: .sfSymbol("shield.checkered"),
                title: L.onboardingParentDashboardTitle,
                subtitle: L.onboardingParentDashboardSubtitle
            )
        ]
    }

    var body: some View {
        ZStack {
            // Background gradient (child gradient)
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

            VStack(spacing: 0) {
                // Top bar: language toggle + skip
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                // Paged content
                TabView(selection: $currentPage) {
                    ForEach(pages) { page in
                        OnboardingPageView(page: page)
                            .tag(page.id)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))

                // Page indicator dots
                pageIndicator
                    .padding(.bottom, 24)

                // Bottom button
                bottomButton
            }
        }
        .environment(\.layoutDirection, L.layoutDirection)
    }

    // MARK: - Top Bar

    private var topBar: some View {
        // Always LTR so language toggle stays left, skip stays right
        HStack {
            LanguageToggleButton()

            Spacer()

            if currentPage < pages.count - 1 {
                Button {
                    onComplete()
                } label: {
                    Text(L.onboardingSkip)
                        .font(.system(size: 16, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .environment(\.layoutDirection, .leftToRight)
    }

    // MARK: - Page Indicator

    private var pageIndicator: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { index in
                Capsule()
                    .fill(.white.opacity(index == currentPage ? 1.0 : 0.4))
                    .frame(
                        width: index == currentPage ? 24 : 8,
                        height: 8
                    )
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: currentPage)
            }
        }
    }

    // MARK: - Bottom Button

    private var bottomButton: some View {
        Button {
            if currentPage < pages.count - 1 {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                    currentPage += 1
                }
            } else {
                onComplete()
            }
        } label: {
            Text(currentPage < pages.count - 1 ? L.next : L.onboardingGetStarted)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Capsule().fill(Color(hex: "6C5CE7")))
        }
        .padding(.horizontal, 40)
        .padding(.bottom, 40)
    }
}

// MARK: - Page Data Model

private struct OnboardingPageData: Identifiable {
    let id: Int
    let illustration: IllustrationType
    let title: String
    let subtitle: String

    enum IllustrationType {
        case sfSymbol(String)
        case avatarGrid([Int])
        case sfSymbolWithExtras(String, extras: [String])
    }
}

// MARK: - Single Page View

private struct OnboardingPageView: View {
    let page: OnboardingPageData
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Illustration
            illustrationView
                .offset(y: appeared ? 0 : 30)
                .opacity(appeared ? 1 : 0)

            Spacer().frame(height: 20)

            // Title
            Text(page.title)
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

            // Subtitle
            Text(page.subtitle)
                .font(.system(size: 17, weight: .medium, design: .rounded))
                .foregroundStyle(.white.opacity(0.85))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.horizontal, 40)
                .offset(y: appeared ? 0 : 20)
                .opacity(appeared ? 1 : 0)

            Spacer()
            Spacer()
        }
        .onAppear {
            appeared = false
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.15)) {
                appeared = true
            }
        }
    }

    @ViewBuilder
    private var illustrationView: some View {
        switch page.illustration {
        case .sfSymbol(let name):
            Image(systemName: name)
                .font(.system(size: 80))
                .foregroundStyle(.white)
                .shadow(color: .white.opacity(0.3), radius: 20)

        case .avatarGrid(let presets):
            LazyVGrid(columns: [
                GridItem(.fixed(110), spacing: 16),
                GridItem(.fixed(110), spacing: 16)
            ], spacing: 16) {
                ForEach(presets, id: \.self) { preset in
                    Image("avatar_preset_\(preset)")
                        .resizable()
                        .scaledToFill()
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(.white, lineWidth: 3))
                        .shadow(color: .white.opacity(0.3), radius: 8)
                }
            }

        case .sfSymbolWithExtras(let main, let extras):
            VStack(spacing: 16) {
                Image(systemName: main)
                    .font(.system(size: 80))
                    .foregroundStyle(.white)
                    .shadow(color: .white.opacity(0.3), radius: 20)

                HStack(spacing: 20) {
                    ForEach(extras, id: \.self) { icon in
                        Image(systemName: icon)
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
            }
        }
    }
}
