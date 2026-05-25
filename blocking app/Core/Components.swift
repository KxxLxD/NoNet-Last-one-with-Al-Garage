import SwiftUI

/// NoNet Design System — Shared View Components
///
/// Single home for tiny presentational components used across screens.
/// Previously these were duplicated as `private struct` in every View file
/// (7 SoftDivider copies, etc.), which created drift risk when tokens changed.

// MARK: - SoftDivider

/// A horizontal hairline divider with adjustable width and opacity.
///
/// `maxWidth` (default 300) caps the divider on large screens. On small
/// devices (e.g., iPhone SE) the divider auto-shrinks to the available
/// space — replaces the old `width: 300` which used to overflow.
///
/// Example:
/// ```
/// SoftDivider()                              // default: maxWidth 300, opacity 0.7
/// SoftDivider(maxWidth: 200, opacity: 0.35)  // narrower, fainter
/// ```
struct SoftDivider: View {
    var maxWidth: CGFloat = 300
    var opacity: Double = 0.7
    var verticalPadding: CGFloat = NNSpacing.xs

    // Backwards-compatible alias for the old `width:` parameter name. The
    // old API used a fixed width that overflowed on small screens; this
    // alias preserves the call sites while gaining responsive behaviour.
    init(width: CGFloat, opacity: Double, verticalPadding: CGFloat = NNSpacing.xs) {
        self.maxWidth = width
        self.opacity = opacity
        self.verticalPadding = verticalPadding
    }

    init(maxWidth: CGFloat = 300, opacity: Double = 0.7, verticalPadding: CGFloat = NNSpacing.xs) {
        self.maxWidth = maxWidth
        self.opacity = opacity
        self.verticalPadding = verticalPadding
    }

    var body: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.uiBorder.opacity(opacity))
                .frame(maxWidth: maxWidth, maxHeight: NNBorder.strong)
            Spacer()
        }
        .padding(.vertical, verticalPadding)
    }
}
