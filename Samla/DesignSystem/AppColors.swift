import SwiftUI

/// Samla palette: dark navy for buttons and headings, cool greys everywhere else,
/// and clear traffic-light colors for list status. See docs/PLAN.md › Design.
enum AppColors {
    static let primary = Color(hex: 0x0F1B3D) // Dark navy
    static let secondary = Color(hex: 0x3B4A6B) // Light navy
    static let primarySoft = primary.opacity(0.08)

    static let background = Color(hex: 0xF3F4F6)
    static let surface = Color.white
    static let border = Color(hex: 0xE5E7EB)
    static let text = Color(hex: 0x111827)
    /// 6.1:1 on white and 5.5:1 on the grey page background (WCAG AA for small text on both).
    static let textSecondary = Color(hex: 0x5B6270)
    /// Fills and destructive buttons; use `dangerText` for red text.
    static let danger = Color(hex: 0xDC2626)
    static let dangerText = Color(hex: 0xB91C1C)

    // List status: the bright shades for dots and icons…
    static let active = Color(hex: 0x16A34A)
    static let scheduled = Color(hex: 0xEA580C)
    static let stopped = Color(hex: 0x9CA3AF)
    // …and darker ones for text, so small text passes WCAG AA (4.5:1) on white.
    static let activeText = Color(hex: 0x166534)
    static let scheduledText = Color(hex: 0xC2410C)
}

extension Color {
    /// `Color(hex: 0x0F1B3D)`
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}
