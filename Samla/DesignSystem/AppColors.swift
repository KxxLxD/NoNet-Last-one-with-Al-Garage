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
    static let textSecondary = Color(hex: 0x6B7280)
    static let danger = Color(hex: 0xDC2626)

    // List status
    static let active = Color(hex: 0x16A34A)
    static let scheduled = Color(hex: 0xEA580C)
    static let stopped = Color(hex: 0x9CA3AF)
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
