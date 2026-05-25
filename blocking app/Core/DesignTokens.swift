import SwiftUI

/// NoNet Design System — Tokens
///
/// Single source of truth for typography, spacing, and radius.
/// Mirror of `.cursor/rules/UI-Mode.mdc`. Use these tokens in all new code;
/// legacy raw `.system(size:)` and magic-number paddings should migrate gradually.
///
/// Why semantic Font tokens? `.system(size: 28)` does NOT respect Dynamic Type.
/// SwiftUI's semantic fonts (`.largeTitle`, `.title2`, etc.) scale automatically
/// with user's accessibility settings — a hard requirement for AA compliance.

// MARK: - Typography

extension Font {
    /// 28pt semibold — Hero titles (HomeView welcome). Dynamic Type ✅
    /// Replaces `.system(size: 28, weight: .semibold)`
    static let nnHero = Font.title.weight(.semibold)
    /// 22pt semibold — Section titles (Your Lists, Settings headers). Dynamic Type ✅
    /// Replaces `.system(size: 22, weight: .semibold)`
    static let nnSectionTitle = Font.title2.weight(.semibold)
    /// 20pt semibold — Card titles, sheet headers. Dynamic Type ✅
    /// Replaces `.system(size: 20, weight: .semibold)`
    static let nnCardTitle = Font.title3.weight(.semibold)
    /// 20pt regular — Large body text inside cards. Dynamic Type ✅
    /// Replaces `.system(size: 20, weight: .regular)`
    static let nnCardBody = Font.title3.weight(.regular)
    /// 18pt semibold — Sub-headers, picker headers. Dynamic Type ✅
    /// Replaces `.system(size: 18, weight: .semibold)`
    static let nnSubheader = Font.title3
    /// 17pt semibold — Inline headlines, prominent labels. Dynamic Type ✅
    static let nnHeadline = Font.headline
    /// 16pt semibold — Button labels, prominent body. Dynamic Type ✅
    /// Replaces `.system(size: 16, weight: .semibold)`
    static let nnButton = Font.callout.weight(.semibold)
    /// 17pt regular — Primary body copy. Dynamic Type ✅
    static let nnBody = Font.body
    /// 15pt regular — Secondary descriptive text. Dynamic Type ✅
    static let nnSubheadline = Font.subheadline
    /// 15pt semibold — Small action labels. Dynamic Type ✅
    /// Replaces `.system(size: 14, weight: .semibold)`
    static let nnSmallButton = Font.subheadline.weight(.semibold)
    /// 13pt regular — Captions, helper text. Dynamic Type ✅
    static let nnCaption = Font.footnote
    /// 11pt regular — Fine print (legal, timestamps). Dynamic Type ✅
    static let nnCaption2 = Font.caption2
}

// MARK: - Spacing

/// Spacing scale: 4 / 8 / 12 / 16 / 20 / 24 / 32 / 40
/// Use as `.padding(NNSpacing.md)` etc. Do not introduce off-scale values
/// (3, 6, 10, 14, 28) — round to the nearest token.
enum NNSpacing {
    /// 4pt — tight inline gaps (icon+text)
    static let xxs: CGFloat = 4
    /// 8pt — between related elements
    static let xs: CGFloat = 8
    /// 12pt — card internal gaps
    static let sm: CGFloat = 12
    /// 16pt — default padding
    static let md: CGFloat = 16
    /// 20pt — card padding (preferred)
    static let lg: CGFloat = 20
    /// 24pt — page horizontal padding
    static let xl: CGFloat = 24
    /// 32pt — section separation
    static let xxl: CGFloat = 32
    /// 40pt — major section break
    static let xxxl: CGFloat = 40
}

// MARK: - Radius

/// Corner radius tokens: 8 / 12 / 16 / 20
/// `card` (20) is documented even though the spec originally said 16 —
/// the codebase consistently uses 20 for Containers, so it is canonized
/// here. Use `chip` (8) for badges, `control` (12) for buttons/inputs,
/// `card` (20) for large containers.
enum NNRadius {
    /// 8pt — chips, small badges, tiny buttons
    static let chip: CGFloat = 8
    /// 12pt — buttons, inputs, small cards
    static let control: CGFloat = 12
    /// 16pt — medium cards (PermissionCard size)
    static let card: CGFloat = 16
    /// 20pt — large containers (Home sections, sheets)
    static let container: CGFloat = 20
}

// MARK: - Border

enum NNBorder {
    /// 0.5pt — card hairline (default)
    static let hairline: CGFloat = 0.5
    /// 0.7pt — input border
    static let input: CGFloat = 0.7
    /// 1pt — divider / strong border
    static let strong: CGFloat = 1
    /// 2pt — focus ring
    static let focus: CGFloat = 2
}

// MARK: - Hit Targets

enum NNHitTarget {
    /// Apple HIG minimum touch target (44×44). Apply to ALL interactive elements.
    static let minimum: CGFloat = 44
}
