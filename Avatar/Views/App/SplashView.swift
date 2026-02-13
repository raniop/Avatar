import SwiftUI

struct SplashView: View {
    @State private var scale: CGFloat = 0.8
    @State private var opacity: Double = 0.5

    var body: some View {
        ZStack {
            AppTheme.Colors.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Image(systemName: "face.smiling.inverse")
                    .font(.system(size: 80))
                    .foregroundStyle(AppTheme.Colors.primary)
                    .scaleEffect(scale)

                Text("Avatar")
                    .font(AppTheme.Fonts.title)
                    .foregroundStyle(AppTheme.Colors.primary)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) {
                scale = 1.0
                opacity = 1.0
            }
        }
    }
}
