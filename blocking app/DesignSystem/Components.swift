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
    func card(padding: CGFloat = 20, cornerRadius: CGFloat = 20) -> some View {
        modifier(CardModifier(padding: padding, cornerRadius: cornerRadius))
    }

    /// Standard text field look.
    func inputFieldStyle() -> some View {
        padding(12)
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.border, lineWidth: 0.5))
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
            .foregroundStyle(.white)
            .contentShape(RoundedRectangle(cornerRadius: 14))

        if #available(iOS 26.0, *) {
            label
                .glassEffect(.regular.tint(tint.opacity(isEnabled ? 1 : 0.4)).interactive(), in: .rect(cornerRadius: 14))
        } else {
            label
                .background(tint.opacity(isEnabled ? 1 : 0.4), in: RoundedRectangle(cornerRadius: 14))
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
            .contentShape(RoundedRectangle(cornerRadius: 14))

        if #available(iOS 26.0, *) {
            label
                .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
        } else {
            label
                .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 14))
                .overlay(RoundedRectangle(cornerRadius: 14).stroke(tint.opacity(isEnabled ? 0.4 : 0.15), lineWidth: 1))
                .opacity(configuration.isPressed ? 0.7 : 1)
        }
    }
}

/// Small tinted square holding an SF Symbol (used for "+", play/stop buttons).
struct IconTile: View {
    let systemName: String
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: systemName)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(AppColors.primary)
            .frame(width: size, height: size)
            .background(AppColors.primarySoft, in: RoundedRectangle(cornerRadius: 9))
    }
}

// MARK: - Text

/// Section heading used above cards.
struct SectionTitle: View {
    let title: LocalizedStringKey

    var body: some View {
        Text(title)
            .font(.title3.weight(.semibold))
            .foregroundStyle(AppColors.primary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Branding

/// The Samla logo, falling back to a shield symbol if the image asset is missing.
struct BrandLogo: View {
    var size: CGFloat

    var body: some View {
        if UIImage(named: "nonet_logo") != nil {
            Image("nonet_logo")
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
    case active, onBreak, scheduled, stopped

    init(_ list: BlockList, at date: Date) {
        if list.isOnBreak(at: date) && list.isActive(at: date) {
            self = .onBreak
        } else if list.isActive(at: date) {
            self = .active
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
        case .stopped: AppColors.stopped
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .active: "Active"
        case .onBreak: "On break"
        case .scheduled: "Scheduled"
        case .stopped: "Stopped"
        }
    }
}

/// "● Active · Ends 6:00 AM"
struct StatusLine: View {
    let status: ListStatus
    var detail: String?

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)
            Text(status.title)
                .foregroundStyle(status.color)
                .fontWeight(.semibold)
            if let detail {
                Text("·").foregroundStyle(AppColors.textSecondary)
                Text(detail).foregroundStyle(AppColors.textSecondary)
            }
        }
        .font(.subheadline)
        .lineLimit(1)
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
