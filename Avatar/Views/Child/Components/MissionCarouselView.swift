import SwiftUI

struct MissionCarouselView: View {
    let missions: [Mission]
    let onSelect: (Mission) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: AppTheme.Spacing.md) {
                ForEach(missions) { mission in
                    MissionCardView(mission: mission) {
                        onSelect(mission)
                    }
                }
            }
            .padding(.horizontal, AppTheme.Spacing.lg)
        }
        .frame(height: 200)
    }
}

struct MissionCardView: View {
    let mission: Mission
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppTheme.Spacing.sm) {
                Text(mission.theme.emoji)
                    .font(.system(size: 50))

                Text(mission.titleEn)
                    .font(AppTheme.Fonts.bodyBold)
                    .foregroundStyle(AppTheme.Colors.textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                Text("\(mission.durationMinutes) min")
                    .font(AppTheme.Fonts.caption)
                    .foregroundStyle(AppTheme.Colors.textSecondary)
            }
            .frame(width: 150, height: 180)
            .background(.white)
            .clipShape(RoundedRectangle(cornerRadius: AppTheme.CornerRadius.lg))
            .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(minimumDuration: .infinity, pressing: { pressing in
            withAnimation(.spring(duration: 0.2)) {
                isPressed = pressing
            }
        }, perform: {})
    }
}
