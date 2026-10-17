import SwiftUI
import UIKit

// MARK: - Card

private struct CardModifier: ViewModifier {
    var padding: CGFloat
    var cornerRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: cornerRadius))
            .overlay(RoundedRectangle(cornerRadius: cornerRadius).stroke(AppColors.border, lineWidth: 0.5))
    }
}

extension View {
    /// White rounded surface with a hairline border — the app's standard container.
    func card(padding: CGFloat = Spacing.l, cornerRadius: CGFloat = Radius.card) -> some View {
        modifier(CardModifier(padding: padding, cornerRadius: cornerRadius))
    }

    /// Standard text field look.
    func inputFieldStyle() -> some View {
        padding(Spacing.m)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.control))
            .overlay(RoundedRectangle(cornerRadius: Radius.control).stroke(AppColors.border, lineWidth: 0.5))
    }
}

// MARK: - Section text

extension View {
    /// Section header/footer color: iOS's default grey is 3.3:1 on the grouped background;
    /// this one is 5.5:1, so headers and footers pass WCAG AA.
    func sectionCaption() -> some View {
        foregroundStyle(AppColors.textSecondary)
    }
}

// MARK: - Buttons

/// Main action: navy, rendered as tinted Liquid Glass on iOS 26 and later.
struct PrimaryButtonStyle: ButtonStyle {
    var height: CGFloat = 50
    var tint: Color = AppColors.primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(isEnabled ? Color.white : AppColors.textSecondary)
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))

        if !isEnabled {
            // Disabled: grey text on a light fill, so it stays readable.
            label.background(AppColors.border, in: RoundedRectangle(cornerRadius: Radius.control))
        } else if #available(iOS 26.0, *) {
            label
                .glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: Radius.control))
        } else {
            label
                .background(tint, in: RoundedRectangle(cornerRadius: Radius.control))
                .opacity(configuration.isPressed ? 0.85 : 1)
        }
    }
}

/// Secondary action: clear Liquid Glass on iOS 26 and later, an outline before that.
struct SecondaryButtonStyle: ButtonStyle {
    var height: CGFloat = 50
    var tint: Color = AppColors.primary
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        let label = configuration.label
            .font(.body.weight(.semibold))
            .frame(maxWidth: .infinity, minHeight: height)
            .foregroundStyle(tint.opacity(isEnabled ? 1 : 0.4))
            .contentShape(RoundedRectangle(cornerRadius: Radius.control))

        if #available(iOS 26.0, *) {
            label
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: Radius.control))
        } else {
            label
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: Radius.control))
                .overlay(RoundedRectangle(cornerRadius: Radius.control).stroke(tint.opacity(isEnabled ? 0.4 : 0.15), lineWidth: 1))
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

// MARK: - Branding

/// The Samla logo, falling back to a shield symbol if the image asset is missing.
struct BrandLogo: View {
    var size: CGFloat

    var body: some View {
        if UIImage(named: "samla_logo") != nil {
            Image("samla_logo")
                .resizable()
                .scaledToFit()
                .frame(width: size, height: size)
                .accessibilityLabel("Samla")
        } else {
            Image(systemName: "shield.lefthalf.filled")
                .resizable()
                .scaledToFit()
                .foregroundStyle(AppColors.primary)
                .frame(width: size * 0.8, height: size * 0.8)
                .frame(width: size, height: size)
                .accessibilityLabel("Samla")
        }
    }
}

// MARK: - Status

/// How a list looks in the UI right now. Colors follow traffic-light rules.
enum ListStatus {
    case active, onBreak, skipped, scheduled, stopped

    init(_ list: BlockList, at date: Date) {
        if list.isOnBreak(at: date) && list.isActive(at: date) {
            self = .onBreak
        } else if list.isActive(at: date) {
            self = .active
        } else if list.isSkipped(at: date) {
            self = .skipped
        } else if list.kind == .scheduled {
            self = .scheduled
        } else {
            self = .stopped
        }
    }

    var color: Color {
        switch self {
        case .active: AppColors.active
        case .onBreak, .scheduled: AppColors.scheduled
        case .skipped, .stopped: AppColors.stopped
        }
    }

    /// Darker than `color`, for readable status text.
    var textColor: Color {
        switch self {
        case .active: AppColors.activeText
        case .onBreak, .scheduled: AppColors.scheduledText
        case .skipped, .stopped: AppColors.textSecondary
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .active: "Active"
        case .onBreak: "On break"
        case .skipped: "Skipped today"
        case .scheduled: "Scheduled"
        case .stopped: "Stopped"
        }
    }
}

/// "● Active · Ends 6:00 AM"
struct StatusLine: View {
    let status: ListStatus
    var detail: String?
    /// Off where a section header already names the status: "● Ends 6:00 AM".
    var showsTitle = true

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
                .accessibilityHidden(true)
            if showsTitle {
                Text(status.title)
                    .foregroundStyle(status.textColor)
                    .fontWeight(.semibold)
            }
            if let detail {
                if showsTitle {
                    Text("·")
                        .foregroundStyle(AppColors.textSecondary)
                        .accessibilityHidden(true)
                }
                Text(detail).foregroundStyle(AppColors.textSecondary)
            }
        }
        .font(.subheadline)
        // One line normally; at accessibility sizes wrap instead of cutting off the time.
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
    }
}

// MARK: - Badges

struct Badge: View {
    let systemImage: String?
    let text: LocalizedStringKey
    var tint: Color = AppColors.primary

    var body: some View {
        HStack(spacing: 6) {
            if let systemImage {
                Image(systemName: systemImage).font(.caption2.weight(.semibold))
            }
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .frame(minHeight: 24)
        .foregroundStyle(tint)
        .background(tint.opacity(0.1), in: Capsule())
    }
}

extension ProtectionMode {
    var title: LocalizedStringKey {
        switch self {
        case .none: "No Protection"
        case .hard: "Hard Mode"
        case .partner: "Partner"
        }
    }

    var systemImage: String {
        switch self {
        case .none: "lock.open"
        case .hard: "lock.fill"
        case .partner: "person.2.fill"
        }
    }
}

/// iOS Settings–style icon: a white symbol on a rounded colored square.
struct IconSquare: View {
    let systemName: String
    var color: Color = AppColors.primary

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 30, height: 30)
            .background(color, in: RoundedRectangle(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}
