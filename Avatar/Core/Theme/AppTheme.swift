import SwiftUI

enum AppTheme {

    enum Colors {
        static let primary = Color(hex: "6C5CE7")
        static let secondary = Color(hex: "00B894")
        static let accent = Color(hex: "FDCB6E")
        static let danger = Color(hex: "E17055")
        static let backgroundLight = Color(hex: "F8F9FA")
        static let backgroundDark = Color(hex: "2D3436")
        static let textPrimary = Color(hex: "2D3436")
        static let textSecondary = Color(hex: "636E72")
        static let cardBackground = Color.white

        static var backgroundGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: "A29BFE"), Color(hex: "6C5CE7")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }

        static var childGradient: LinearGradient {
            LinearGradient(
                colors: [Color(hex: "FD79A8"), Color(hex: "A29BFE"), Color(hex: "74B9FF")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    enum Fonts {
        static let title = Font.system(size: 32, weight: .bold, design: .rounded)
        static let heading = Font.system(size: 24, weight: .semibold, design: .rounded)
        static let body = Font.system(size: 17, weight: .regular, design: .rounded)
        static let bodyBold = Font.system(size: 17, weight: .semibold, design: .rounded)
        static let caption = Font.system(size: 14, weight: .regular, design: .rounded)
        static let childLarge = Font.system(size: 28, weight: .bold, design: .rounded)
        static let childBody = Font.system(size: 20, weight: .medium, design: .rounded)
    }

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 16
        static let lg: CGFloat = 24
        static let xl: CGFloat = 32
        static let xxl: CGFloat = 48
    }

    enum CornerRadius {
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 20
        static let xl: CGFloat = 28
        static let pill: CGFloat = 999
    }
}

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
