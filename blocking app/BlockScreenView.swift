import SwiftUI

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
            VStack(spacing: 16) {
                // Top bar with break pill aligned per locale
                HStack {
                    if isArabic { Spacer() }
                    if let total = totalBreaks, let remain = remainingBreaks, let minutes = breakDurationMinutes, total > 0 {
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeOut(duration: 0.5)) { flashBreak = true }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeIn(duration: 0.5)) { flashBreak = false }
                            }
                            onTakeBreak?()
                        }) {
                            breakPill(total: total, remain: remain, minutes: minutes)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 12)
                    } else {
                        Spacer(minLength: 0)
                            .frame(height: 0)
                            .padding(.top, 12)
                    }
                    if !isArabic { Spacer() }
                }
                Spacer()
                heroView()
                    .padding(.top, -24)
                    .padding(.bottom, 12)
                VStack(spacing: 8) {
                    Text(isArabic ? "وضع التركيز مفعّل — وضع السكينة مفعّل" : "Focus mode is ON — Peace mode is ON")
                        .font(.nnCardTitle)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                    Text(isArabic ? "استمر… إنت ماشي صح ✨" : "Stay in focus — keep going ✨")
                        .font(.nnSubheader)
                        .foregroundColor(AppColors.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                if let hint = breakHint() {
                    infoCard(text: hint)
                } else {
                    infoCard(text: isArabic ? "نحجب المشتّتات لنحمي تركيزك." : "Distractions are blocked to protect your focus.")
                }

                Spacer()
                Button(action: {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    onClose()
                }) {
                    Text(isArabic ? "تمام — لنكمل" : "Okay — let’s continue")
                        .font(.nnButton)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
            }
        }
        .interactiveDismissDisabled(true)
    }

    // Adaptive hero: circle diameter clamped to 180–220 based on screen width
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
        }
    }

    private func infoCard(text: String) -> some View {
        VStack(spacing: 0) {
            Text(text)
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(AppColors.uiSurface)
        .cornerRadius(20)
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(AppColors.uiBorder, lineWidth: 0.5)
        )
        .padding(.horizontal, 24)
    }

    private func breakPill(total: Int, remain: Int, minutes: Int) -> some View {
        let countText = "\(remain)/\(total)"
        let durText = isArabic ? "\(minutes) دقيقة" : "\(minutes) min"
        return HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer")
                .font(.footnote)
                .foregroundColor(AppColors.textPrimary)
            Text(isArabic ? "استراحة" : "Break")
                .font(.footnote.weight(.semibold))
                .foregroundColor(AppColors.textPrimary)
            Text(countText)
                .font(.nnCaption)
                .foregroundColor(AppColors.textSecondary)
            Text(durText)
                .font(.nnCaption)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 12)
        .frame(height: 32)
        .background(flashBreak ? AppColors.accent.opacity(0.4) : Color.clear)
        .overlay(
            Capsule().stroke(AppColors.uiBorder, lineWidth: 0.5)
        )
        .clipShape(Capsule())
        .contentShape(Capsule())
    }

    private func breakHint() -> String? {
        if isOnBreak {
            return isArabic ? "هذه فترة استراحة — ارجع للتركيز بعد انتهائها." : "This is a break — get back to focus once it’s over."
        }
        if let minutes = upcomingBreakMinutes, minutes > 0 {
            if isArabic {
                return "استراحة قصيرة بعد قليل — خلك مكمل لين تبدأ."
            } else {
                return "A short break is coming soon — stay on it till it starts."
            }
        }
        return nil
    }
}

#Preview {
    BlockScreenView(isArabic: true, onClose: {}, isOnBreak: false, upcomingBreakMinutes: nil, totalBreaks: 2, remainingBreaks: 2, breakDurationMinutes: 15)
} 