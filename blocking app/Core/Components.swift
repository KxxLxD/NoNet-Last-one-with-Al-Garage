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
/// space — replaces the old fixed-width version which used to overflow.
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

// MARK: - LabeledTextField

/// Standard NoNet text input with a leading label, optional required asterisk,
/// optional helper text, and consistent NNRadius.control rounding. Designed
/// to be drop-in across CreateListSheet, PartnerInviteView, PartnerAcceptSheet,
/// AuthView — replaces ~10 inline duplications of the same TextField pattern.
///
/// Pass `secure: true` for password-style entry.
struct LabeledTextField: View {
    let title: String
    let placeholder: String
    @Binding var text: String
    var required: Bool = false
    var helper: String? = nil
    var secure: Bool = false
    var keyboardType: UIKeyboardType = .default
    var autocapitalization: TextInputAutocapitalization = .words

    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            HStack(spacing: 4) {
                Text(title)
                    .font(.footnote.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                if required {
                    Text("*").foregroundColor(AppColors.alertRed)
                }
                Spacer(minLength: 0)
            }
            Group {
                if secure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textInputAutocapitalization(autocapitalization)
            .keyboardType(keyboardType)
            .padding(NNSpacing.sm)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.control)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
            )
            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)

            if let helper = helper {
                Text(helper)
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
    }
}

// MARK: - SectionHeader

/// A section header with a leading SF Symbol + title. Replaces the
/// HStack { Image; Text } pattern duplicated in every Settings/About row.
/// Use inside `Section(header: SectionHeader(icon:text:))`.
struct SectionHeader: View {
    let icon: String
    let text: String
    var iconColor: Color = AppColors.accent
    var font: Font = .nnCardTitle

    var body: some View {
        HStack(spacing: NNSpacing.xs) {
            Image(systemName: icon)
                .font(.nnCardBody)
                .foregroundColor(iconColor)
            Text(text)
                .font(font)
                .foregroundColor(AppColors.textPrimary)
            Spacer(minLength: 0)
        }
        .textCase(nil) // List section headers default to uppercase otherwise.
    }
}

// MARK: - InfoBanner

/// Inline alert banner used throughout HomeView for permission warnings,
/// iCloud-unavailable notices, and similar system-state surfaces. Mirrors
/// HomeView's `slimAlertBanner` but available app-wide.
///
/// Default tone is `.alert` (red). Use `.info` (blue) for non-urgent context
/// and `.warning` (amber) for soft cautions.
struct InfoBanner: View {
    enum Tone {
        case alert
        case info
        case warning
        case success

        var foreground: Color {
            switch self {
            case .alert:   return AppColors.alertRed
            case .info:    return AppColors.accent
            case .warning: return AppColors.warningFg
            case .success: return AppColors.successGreen
            }
        }

        var background: Color {
            foreground.opacity(0.08)
        }

        var border: Color {
            foreground.opacity(0.3)
        }
    }

    let icon: String
    let title: String
    let detail: String?
    var tone: Tone = .alert

    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        HStack(alignment: .top, spacing: NNSpacing.sm) {
            Image(systemName: icon)
                .foregroundColor(tone.foreground)
                .font(.callout)
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                if let detail = detail {
                    Text(detail)
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, NNSpacing.md)
        .padding(.vertical, NNSpacing.sm)
        .background(tone.background)
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.control)
                .stroke(tone.border, lineWidth: NNBorder.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
    }
}

// MARK: - Badge

/// Visual semantic for `Badge` — drives fg/bg/border palette without
/// hard-coding colors at call sites.
enum BadgeStyle { case neutral, warning, danger, success }

/// Small icon+text chip used for protection state, list type, status, and
/// other inline state indicators. Stays under 24pt tall to slot inside a
/// list row without bumping line height.
///
/// Lives in Components so both HomeView (ListRowCore) and ListDetailView
/// can use the same visual without duplicating the definition.
struct Badge: View {
    let icon: String
    let text: String
    let style: BadgeStyle

    var body: some View {
        HStack(spacing: NNSpacing.xs - 2) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .monospacedDigit()
        }
        .padding(.horizontal, NNSpacing.sm - 2)
        .frame(height: 24)
        .foregroundColor(fg)
        .background(bg)
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.chip)
                .stroke(border, lineWidth: NNBorder.hairline)
        )
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.chip))
    }

    private var fg: Color {
        switch style {
        case .neutral: return AppColors.textPrimary
        case .warning: return AppColors.warningFg
        case .danger:  return AppColors.alertRed
        case .success: return AppColors.successGreen
        }
    }
    private var bg: Color {
        switch style {
        case .neutral: return AppColors.uiSurface
        case .warning: return AppColors.warningBg
        case .danger:  return AppColors.alertRed.opacity(0.10)
        case .success: return AppColors.successBg
        }
    }
    private var border: Color {
        switch style {
        case .neutral: return AppColors.uiBorder
        case .warning: return AppColors.warningFg.opacity(0.6)
        case .danger:  return AppColors.alertRed
        case .success: return AppColors.successGreen.opacity(0.6)
        }
    }
}

/// Pre-configured Badge for "Hard Mode" vs "No Protection" — the most common
/// badge in the app, used in HomeView rows and ListDetailView header. Wraps
/// `Badge` rather than duplicating its style logic.
struct ProtectionBadge: View {
    let isHard: Bool
    let isRTL: Bool

    var body: some View {
        let label = isHard
            ? (isRTL ? "الوضع الصارم" : "Hard Mode")
            : (isRTL ? "بدون حماية" : "No Protection")
        Group {
            if isHard {
                Badge(icon: "lock.fill", text: label, style: .danger)
            } else {
                Badge(icon: "lock.open", text: label, style: .neutral)
            }
        }
        // Combine icon + text into one VoiceOver element so the badge reads
        // as "Hard Mode" instead of "Image. Hard Mode."
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityHint(isHard
                           ? (isRTL ? "لا يمكن إيقاف هذه القائمة بدون الحارس" : "This list can't be paused without the gatekeeper")
                           : (isRTL ? "يمكن إيقاف أو حذف هذه القائمة في أي وقت" : "This list can be paused or deleted anytime"))
    }
}

// MARK: - EmptyState

/// Standard empty-state card: SF Symbol + title + optional message + optional
/// CTA button. Used wherever a screen has no rows/items yet. Replaces the
/// per-screen ad-hoc empty placeholders (HomeView's EmptyStateView, etc.)
/// so the language and rhythm match everywhere.
///
/// Example:
/// ```
/// EmptyState(
///     icon: "trophy",
///     title: "No challenges yet",
///     message: "Pick a challenge to start earning points.",
///     actionTitle: "Add a challenge",
///     action: { showPicker = true }
/// )
/// ```
struct EmptyState: View {
    let icon: String
    let title: String
    var message: String? = nil
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        VStack(spacing: NNSpacing.sm) {
            Image(systemName: icon)
                .font(.title)
                .foregroundColor(AppColors.textSecondary)
                .accessibilityHidden(true)
            Text(title)
                .font(.headline)
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)
            if let message = message {
                Text(message)
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
            }
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.nnSmallButton)
                        .padding(.horizontal, NNSpacing.md)
                        .frame(minHeight: NNHitTarget.minimum - 8)
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                }
                .buttonStyle(.plain)
                .padding(.top, NNSpacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(NNSpacing.lg)
        .background(AppColors.uiSurface)
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.container)
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
    }
}

// MARK: - FlowChipsRow

/// Tiny chip with an icon + label — single building block for the
/// `FlowChipsRow` below. Kept private to this file since the wrapped row
/// is the only sanctioned use; raw chips would invite divergent styles.
private struct FlowChip: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: NNSpacing.xxs) {
            Image(systemName: icon)
                .font(.caption2)
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
                .truncationMode(.tail)
        }
        .foregroundColor(AppColors.textPrimary)
        .padding(.horizontal, NNSpacing.xs + 2)
        .padding(.vertical, NNSpacing.xxs + 2)
        .background(AppColors.uiBackground)
        .overlay(
            Capsule()
                .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
        )
        .clipShape(Capsule())
    }
}

/// Horizontal wrap of chips with an optional "+N more" trailing chip.
/// Used in ListDetailView's items preview and anywhere else the app needs
/// to show a few representative items + an overflow count.
///
/// Items are passed as tuples (id, icon, text) so the caller doesn't have
/// to introduce a new model type for one display.
struct FlowChipsRow: View {
    let items: [(id: UUID, icon: String, text: String)]
    let extraCount: Int
    let extraLabel: String
    let isRTL: Bool

    var body: some View {
        // FlowLayout-style wrap via HStack-of-LazyVGrid replacement: we use a
        // single-line HStack that scrolls horizontally on overflow, which is
        // the simplest cross-version solution (true FlowLayout needs iOS 16+
        // and care around RTL).
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: NNSpacing.xs) {
                ForEach(items, id: \.id) { item in
                    FlowChip(icon: item.icon, text: item.text)
                }
                if extraCount > 0 {
                    FlowChip(icon: "ellipsis", text: extraLabel)
                }
            }
            .padding(.horizontal, NNSpacing.xxs)
        }
        .environment(\.layoutDirection, isRTL ? .rightToLeft : .leftToRight)
    }
}

// MARK: - OptionRow

/// Radio-style selectable row used by partnerCard, gatekeeper picker, and
/// any "pick one of several" UI. Captures the same pattern as
/// CreateListSheet's `partnerOptionRow` — call sites can migrate to this
/// shared version as they touch the surrounding code.
struct OptionRow: View {
    let title: String
    let subtitle: String?
    let isSelected: Bool
    let action: () -> Void
    var icon: String? = nil

    @EnvironmentObject private var lang: LanguageManager

    var body: some View {
        Button(action: action) {
            HStack(spacing: NNSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                        .frame(width: 28)
                }
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textPrimary)
                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                    }
                }
                Spacer(minLength: 0)
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(AppColors.accent)
                        .font(.title3)
                }
            }
            .padding(.horizontal, NNSpacing.md)
            .padding(.vertical, NNSpacing.sm)
            .frame(minHeight: NNHitTarget.minimum)
            .background(isSelected ? AppColors.infoBg : AppColors.uiBackground)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.control)
                    .stroke(isSelected ? AppColors.accent : AppColors.uiBorder,
                            lineWidth: isSelected ? NNBorder.input : NNBorder.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}
