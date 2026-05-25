import SwiftUI

/// The full-screen "you're blocked" surface. Shown when the user lands on a
/// blocked app/site via the FamilyControls shield. Single purpose: confirm
/// the block is intentional, optionally offer a planned break, then let the
/// user dismiss back to the system.
///
/// Layout rhythm (top → bottom):
///   1. Top bar  — optional break pill (if breaks are configured)
///   2. Hero     — adaptive logo circle
///   3. Title    — single concise focus message
///   4. Hint     — contextual one-liner (break upcoming / general)
///   5. CTA      — primary "dismiss" button
///
/// One vertical Spacer between the top bar and hero, one between hint and
/// CTA — that's it. The previous version stacked three Spacers + a negative
/// .padding(.top, -24) which made the layout unpredictable on different
/// screen sizes.
struct BlockScreenView: View {
    let isArabic: Bool
    var onClose: () -> Void
    var isOnBreak: Bool = false
    var upcomingBreakMinutes: Int? = nil
    // Break button UI-only props
    var totalBreaks: Int? = nil
    var remainingBreaks: Int? = nil
    var breakDurationMinutes: Int? = nil
    var onTakeBreak: (() -> Void)? = nil
    @State private var flashBreak: Bool = false

    var body: some View {
        ZStack {
            AppColors.uiSurface.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar()
                    .padding(.horizontal, NNSpacing.xl)
                    .padding(.top, NNSpacing.sm)

                Spacer(minLength: NNSpacing.lg)

                VStack(spacing: NNSpacing.lg) {
                    heroView()
                    titleBlock()
                    if let hint = displayHint() {
                        Text(hint)
                            .font(.subheadline)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, NNSpacing.xl)
                    }
                }

                Spacer(minLength: NNSpacing.lg)

                primaryCTA()
                    .padding(.horizontal, NNSpacing.xl)
                    .padding(.bottom, NNSpacing.xl)
            }
        }
        .interactiveDismissDisabled(true)
    }

    // MARK: - Top bar

    /// Holds the break pill (when breaks are configured) aligned per locale.
    /// Uses a single HStack with conditional Spacers so the pill sits at the
    /// trailing edge in Arabic, leading in English, with no asymmetric padding.
    @ViewBuilder
    private func topBar() -> some View {
        HStack(spacing: 0) {
            if isArabic { Spacer(minLength: 0) }
            if let total = totalBreaks, let remain = remainingBreaks, let minutes = breakDurationMinutes, total > 0 {
                breakButton(total: total, remain: remain, minutes: minutes)
            }
            if !isArabic { Spacer(minLength: 0) }
        }
        .frame(minHeight: 44) // reserve the top-bar slot even when no pill — stable hero position
    }

    @ViewBuilder
    private func breakButton(total: Int, remain: Int, minutes: Int) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.5)) { flashBreak = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeIn(duration: 0.5)) { flashBreak = false }
            }
            onTakeBreak?()
        }) {
            HStack(spacing: 6) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.footnote)
                Text(isArabic ? "استراحة" : "Break")
                    .font(.footnote.weight(.semibold))
                Text("\(remain)/\(total)")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()
                Text("·")
                    .foregroundColor(AppColors.textSecondary)
                Text(isArabic ? "\(minutes) د" : "\(minutes)m")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
                    .monospacedDigit()
            }
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, NNSpacing.md)
            .frame(minHeight: 44) // HIG touch target
            .background(flashBreak ? AppColors.accent.opacity(0.18) : AppColors.infoBg)
            .overlay(Capsule().stroke(AppColors.accent.opacity(0.25), lineWidth: 0.5))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isArabic
            ? "استراحة \(remain) من \(total)، \(minutes) دقيقة لكل استراحة"
            : "Break \(remain) of \(total), \(minutes) minutes each")
    }

    // MARK: - Hero

    /// Adaptive logo circle — diameter clamped to 180–220pt based on screen
    /// width. The clamp keeps it readable on iPhone SE and not absurdly large
    /// on iPad/Plus models.
    private func heroView() -> some View {
        let screenWidth = UIScreen.main.bounds.width
        let diameter = max(180, min(screenWidth * 0.42, 220))
        let logoSize = diameter * 0.75
        return ZStack {
            Circle()
                .fill(AppColors.infoBg)
                .frame(width: diameter, height: diameter)
            Image("nonet_logo")
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
                .accessibilityHidden(true)
        }
    }

    // MARK: - Title block

    /// Two-line title block: a primary state line and a brief encouragement.
    /// Previous copy was "وضع التركيز مفعّل — وضع السكينة مفعّل" which read
    /// repetitive (two phrases saying the same thing with "—") and used the
    /// unusual "وضع السكينة"; replaced with a single clear primary state +
    /// short encouragement.
    @ViewBuilder
    private func titleBlock() -> some View {
        VStack(spacing: NNSpacing.xs) {
            Text(isArabic ? "وضع التركيز مفعَّل" : "Focus mode is on")
                .font(.title2.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            Text(isArabic ? "استمرّ — أنت ماضٍ في الطريق الصحيح ✨" : "Keep going — you're on track ✨")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, NNSpacing.xl)
    }

    // MARK: - Hint

    /// Single-line contextual hint shown under the title. Returns the most
    /// relevant message: break-in-progress > break-upcoming > general purpose.
    private func displayHint() -> String? {
        if isOnBreak {
            return isArabic
                ? "هذه فترة استراحة — ارجع للتركيز بعد انتهائها."
                : "This is a break — get back to focus once it's over."
        }
        if let minutes = upcomingBreakMinutes, minutes > 0 {
            return isArabic
                ? "استراحة قصيرة بعد قليل — ابقَ على التركيز حتى تبدأ."
                : "A short break is coming soon — stay focused until it starts."
        }
        return isArabic
            ? "نحجب المشتّتات لنحمي تركيزك."
            : "Distractions are blocked to protect your focus."
    }

    // MARK: - Primary CTA

    @ViewBuilder
    private func primaryCTA() -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            onClose()
        }) {
            Text(isArabic ? "تمام — لنكمل" : "Okay — let's continue")
                .font(.nnButton)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(AppColors.accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BlockScreenView(isArabic: true, onClose: {}, isOnBreak: false, upcomingBreakMinutes: nil, totalBreaks: 2, remainingBreaks: 2, breakDurationMinutes: 15)
}
