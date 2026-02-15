import SwiftUI

struct SplashView: View {
    @Environment(AppRouter.self) private var appRouter

    @State private var titleOffset: CGFloat = 20
    @State private var titleOpacity: Double = 0
    @State private var subtitleOpacity: Double = 0
    @State private var dotsOpacity: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    private var L: AppLocale { appRouter.currentLocale }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background — exact same image file the LaunchScreen.storyboard uses
                if let uiImage = UIImage(named: "LaunchBG") {
                    Image(uiImage: uiImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }

                // Animated content positioned below the logo in the BG image
                VStack(spacing: 10) {
                    // App name
                    Text("Avatar")
                        .font(.system(size: 42, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
                        .offset(y: titleOffset)
                        .opacity(titleOpacity)

                    // Tagline
                    Text(L.appTagline)
                        .font(.system(size: 17, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                        .opacity(subtitleOpacity)
                }
                .position(x: geo.size.width / 2, y: geo.size.height * 0.62)

                // Loading dots at bottom
                HStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { index in
                        Circle()
                            .fill(.white.opacity(0.8))
                            .frame(width: 8, height: 8)
                            .scaleEffect(pulseScale)
                            .animation(
                                .easeInOut(duration: 0.6)
                                .repeatForever(autoreverses: true)
                                .delay(Double(index) * 0.2),
                                value: pulseScale
                            )
                    }
                }
                .opacity(dotsOpacity)
                .position(x: geo.size.width / 2, y: geo.size.height - 70)
            }
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.4)) {
                titleOffset = 0
                titleOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.5).delay(0.65)) {
                subtitleOpacity = 1.0
            }
            withAnimation(.easeOut(duration: 0.4).delay(0.8)) {
                dotsOpacity = 1.0
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                pulseScale = 0.5
            }
        }
    }
}
