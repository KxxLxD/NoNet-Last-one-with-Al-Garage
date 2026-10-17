import SwiftUI
import UIKit

/// Light haptics for the moments that matter: starting/stopping a block, saving, breaks.
enum Haptics {
    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }

    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    static func warning() {
        UINotificationFeedbackGenerator().notificationOccurred(.warning)
    }
}

extension View {
    /// A short "✓ List created" confirmation shown over the bottom of the view.
    func successToast(isPresented: Bool, message: LocalizedStringKey) -> some View {
        overlay(alignment: .bottom) {
            if isPresented {
                Label(message, systemImage: "checkmark.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, Spacing.l)
                    .padding(.vertical, Spacing.m)
                    .background(AppColors.primary, in: Capsule())
                    .padding(.bottom, Spacing.xl)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.3), value: isPresented)
    }
}

/// Live "01:24:10" countdown to `end`, ticking every second.
struct CountdownText: View {
    let end: Date

    var body: some View {
        Text(timerInterval: Date.now...max(end, .now), countsDown: true)
            .monospacedDigit()
            .lineLimit(1)
            .minimumScaleFactor(0.5)
    }
}

/// Wraps its children onto new lines, used for suggestion chips.
/// SwiftUI mirrors custom layouts automatically in right-to-left languages.
struct FlowLayout: Layout {
    var spacing: CGFloat = Spacing.s

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: bounds.minY + row.y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
        }
    }

    private struct Row {
        var indices: [Int] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width maxWidth: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                let last = rows[rows.count - 1]
                rows.append(Row(y: last.y + last.height + spacing))
            }
            rows[rows.count - 1].width = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            rows[rows.count - 1].height = max(rows[rows.count - 1].height, size.height)
            rows[rows.count - 1].indices.append(index)
        }
        return rows
    }
}

/// A toggleable capsule: outlined when off, navy with a checkmark when on.
struct ChipToggle: View {
    let title: String
    let isOn: Bool
    var action: () -> Void

    var body: some View {
        Button {
            Haptics.tap()
            action()
        } label: {
            HStack(spacing: Spacing.xs) {
                if isOn { Image(systemName: "checkmark").font(.caption.weight(.bold)) }
                Text(title)
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, Spacing.m)
            .padding(.vertical, Spacing.s)
            .foregroundStyle(isOn ? Color.white : AppColors.primary)
            .background(isOn ? AppColors.primary : AppColors.primarySoft, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
