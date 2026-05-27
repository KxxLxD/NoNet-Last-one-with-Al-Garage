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
    @EnvironmentObject var lang: LanguageManager
    var onClose: () -> Void
    var isOnBreak: Bool = false
    var upcomingBreakMinutes: Int? = nil
    // Context props — when provided, surface the list name + remaining time
    // under the title so the user knows WHICH commitment is firing and WHEN
    // it ends. Both optional so legacy call sites still compile.
    var listName: String? = nil
    var minutesRemaining: Int? = nil
    // Break button UI-only props
    var totalBreaks: Int? = nil
    var remainingBreaks: Int? = nil
    var breakDurationMinutes: Int? = nil
    var onTakeBreak: (() -> Void)? = nil
    @State private var flashBreak: Bool = false
    /// Gentle breathing animation on the hero logo so the screen feels alive
    /// rather than frozen — the user is meant to pause here for a beat, not
    /// stare at static pixels.
    @State private var heroBreath: Bool = false

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
            if lang.isArabicEffective { Spacer(minLength: 0) }
            if let total = totalBreaks, let remain = remainingBreaks, let minutes = breakDurationMinutes, total > 0 {
                breakButton(total: total, remain: remain, minutes: minutes)
            }
            if !lang.isArabicEffective { Spacer(minLength: 0) }
        }
        .frame(minHeight: NNHitTarget.minimum) // reserve the top-bar slot even when no pill — stable hero position
    }

    @ViewBuilder
    private func breakButton(total: Int, remain: Int, minutes: Int) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Flash on → wait → flash off. Task.sleep gives us cancellation
            // semantics for free (matters if the view dismisses mid-flash)
            // and aligns timing more reliably than DispatchQueue.asyncAfter,
            // which can drift under load.
            Task { @MainActor in
                withAnimation(.easeOut(duration: 0.5)) { flashBreak = true }
                try? await Task.sleep(nanoseconds: 500_000_000)
                withAnimation(.easeIn(duration: 0.5)) { flashBreak = false }
            }
            onTakeBreak?()
        }) {
            // Compact label: "Break (2 left)" — duration lives in
            // accessibility only. The dense "Break · 2/2 · 15m" version was
            // ~28 chars and visually cluttered for a moment-of-friction screen.
            HStack(spacing: NNSpacing.xxs) {
                Image(systemName: "cup.and.saucer.fill")
                    .font(.footnote)
                Text(lang.isArabicEffective ? "استراحة (\(remain) متبقية)" : "Break (\(remain) left)")
                    .font(.footnote.weight(.semibold))
                    .monospacedDigit()
            }
            .foregroundColor(AppColors.textPrimary)
            .padding(.horizontal, NNSpacing.sm + 2)
            .frame(minHeight: NNHitTarget.minimum)
            .background(flashBreak ? AppColors.accent.opacity(0.18) : AppColors.infoBg)
            .overlay(Capsule().stroke(AppColors.accent.opacity(0.25), lineWidth: NNBorder.hairline))
            .clipShape(Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lang.isArabicEffective
            ? "استراحة \(remain) من \(total)، \(minutes) دقيقة لكل استراحة"
            : "Break \(remain) of \(total), \(minutes) minutes each")
    }

    // MARK: - Hero

    /// Adaptive logo circle — diameter clamped to 180–220pt based on screen
    /// width. The clamp keeps it readable on iPhone SE and not absurdly large
    /// on iPad/Plus models.
    private func heroView() -> some View {
        // Clamped 160-200pt (tighter than the previous 180-220pt) so the
        // hero leaves room for the listName + minutesRemaining context lines
        // without pushing the CTA off-screen on iPhone SE.
        let screenWidth = UIScreen.main.bounds.width
        let diameter = max(160, min(screenWidth * 0.42, 200))
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
        // Subtle "breath" — scale 1.0↔1.02 on a 4s cycle. Too small to
        // notice consciously, but lifts the screen from "frozen" to "alive"
        // — matches the meditation-app pattern of always-moving negative space.
        .scaleEffect(heroBreath ? 1.02 : 1.0)
        .onAppear {
            withAnimation(.easeInOut(duration: 4.0).repeatForever(autoreverses: true)) {
                heroBreath = true
            }
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
            Text(lang.isArabicEffective ? "وضع التركيز مفعَّل" : "Focus mode is on")
                .font(.title2.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
                .multilineTextAlignment(.center)

            // Context lines: list name + remaining time as a single quiet
            // chip beneath the title — answers "which commitment is firing
            // and when does it end" without dominating the hierarchy.
            if listName != nil || minutesRemaining != nil {
                contextChip
            }

            // SF Symbol sparkles renders consistently across fonts and
            // Dynamic Type sizes; the ✨ emoji rendered inconsistently
            // (some fonts fell back to a monochrome glyph).
            HStack(spacing: NNSpacing.xxs) {
                Text(lang.isArabicEffective ? "استمرّ — أنت ماضٍ في الطريق الصحيح" : "Keep going — you're on track")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                Image(systemName: "sparkles")
                    .font(.footnote)
                    .foregroundColor(AppColors.accent)
            }
            .multilineTextAlignment(.center)
            .accessibilityElement(children: .combine)
        }
        .padding(.horizontal, NNSpacing.xl)
    }

    /// Compact chip combining the list name and remaining time, separated
    /// by a soft middot. Hidden when both inputs are nil so we don't render
    /// an empty pill.
    @ViewBuilder
    private var contextChip: some View {
        let nameText: String? = listName.flatMap { $0.isEmpty ? nil : $0 }
        let timeText: String? = minutesRemaining.flatMap { mins in
            guard mins > 0 else { return nil }
            return lang.isArabicEffective ? "متبقي \(mins) دقيقة" : "\(mins)m remaining"
        }
        let parts = [nameText, timeText].compactMap { $0 }
        if !parts.isEmpty {
            Text(parts.joined(separator: " · "))
                .font(.caption.weight(.semibold))
                .foregroundColor(AppColors.accent)
                .monospacedDigit()
                .padding(.horizontal, NNSpacing.sm)
                .padding(.vertical, NNSpacing.xxs + 2)
                .background(AppColors.infoBg)
                .clipShape(Capsule())
                .accessibilityElement()
                .accessibilityLabel(parts.joined(separator: ", "))
        }
    }

    // MARK: - Hint

    /// Single-line contextual hint shown under the title. Returns the most
    /// relevant message: break-in-progress > break-upcoming > general purpose.
    private func displayHint() -> String? {
        if isOnBreak {
            return lang.isArabicEffective
                ? "هذه فترة استراحة — ارجع للتركيز بعد انتهائها."
                : "This is a break — get back to focus once it's over."
        }
        if let minutes = upcomingBreakMinutes, minutes > 0 {
            return lang.isArabicEffective
                ? "استراحة قصيرة بعد قليل — ابقَ على التركيز حتى تبدأ."
                : "A short break is coming soon — stay focused until it starts."
        }
        return lang.isArabicEffective
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
            Text(lang.isArabicEffective ? "أعدني للتركيز" : "Get back to focus")
                .font(.nnButton)
                .frame(maxWidth: .infinity)
                .frame(height: NNHitTarget.minimum + 6)
                .background(AppColors.accent)
                .foregroundColor(.white)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    BlockScreenView(
        onClose: {},
        isOnBreak: false,
        upcomingBreakMinutes: nil,
        listName: "وقت التركيز",
        minutesRemaining: 38,
        totalBreaks: 2,
        remainingBreaks: 2,
        breakDurationMinutes: 15
    )
    .environmentObject(LanguageManager.shared)
}
