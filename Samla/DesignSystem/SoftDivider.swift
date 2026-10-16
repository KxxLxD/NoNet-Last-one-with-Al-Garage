import SwiftUI

/// Thin, centered separator used between sections across the app.
struct SoftDivider: View {
    var width: CGFloat = 300
    var opacity: Double = 0.70
    var verticalPadding: CGFloat = 8

    var body: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.border.opacity(opacity))
                .frame(width: width, height: 1)
            Spacer()
        }
        .padding(.vertical, verticalPadding)
    }
}
