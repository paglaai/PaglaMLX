import SwiftUI
import AppKit

enum DesignTokens {

    // MARK: - Colors
    enum Color {
        static let accent     = SwiftUI.Color(hex: "#3366cc")
        static let destructive = SwiftUI.Color(hex: "#dd2222")
        static let secondaryText = SwiftUI.Color(hex: "#a0a0a0")
        static let border     = SwiftUI.Color(hex: "#ebeef1")

        static let success    = SwiftUI.Color.green
        static let warning    = SwiftUI.Color.orange
        static let error      = SwiftUI.Color.red

        static let dotFilled  = SwiftUI.Color(hex: "#3366cc")
        static let dotEmpty   = SwiftUI.Color(hex: "#ebeef1")
    }

    // MARK: - Fonts (SF Pro — macOS system font)
    enum Font {
        static let label      = SwiftUI.Font.system(size: 13)
        static let smallLabel = SwiftUI.Font.system(size: 11)
        static let caption    = SwiftUI.Font.caption
        static let caption2   = SwiftUI.Font.caption2
        static let headline   = SwiftUI.Font.headline
        static let subheadline = SwiftUI.Font.subheadline
        static let body       = SwiftUI.Font.body
        static let callout    = SwiftUI.Font.callout

        static let monospacedCaption    = SwiftUI.Font.system(.caption, design: .monospaced)
        static let monospacedSmall      = SwiftUI.Font.system(size: 9, design: .monospaced)
        static let monospacedTiny       = SwiftUI.Font.system(size: 10, design: .monospaced)
        static let monospacedBody       = SwiftUI.Font.system(.body, design: .monospaced)
        static let monospacedSubhead    = SwiftUI.Font.system(.subheadline, design: .monospaced)
        static let monospacedTitle2Bold = SwiftUI.Font.system(.title2, design: .monospaced).bold()

        static let title2    = SwiftUI.Font.title2
        static let largeIcon = SwiftUI.Font.system(size: 36)
    }

    // MARK: - Spacing (8px grid)
    enum Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat  = 4
        static let sm: CGFloat  = 6
        static let md: CGFloat  = 8
        static let lg: CGFloat  = 12
        static let xl: CGFloat  = 16
        static let xxl: CGFloat = 20
        static let xxxl: CGFloat = 24
    }

    // MARK: - Corner Radius
    enum Radius {
        static let sm: CGFloat = 4
        static let md: CGFloat = 6
        static let lg: CGFloat = 8
    }

    // MARK: - Icon Sizes
    enum Icon {
        static let dot: CGFloat      = 6
        static let dotSmall: CGFloat = 7
        static let dotLarge: CGFloat = 10
    }
}
