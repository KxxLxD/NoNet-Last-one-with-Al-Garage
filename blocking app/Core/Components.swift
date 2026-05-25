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
