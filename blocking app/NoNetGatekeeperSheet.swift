//
//  NoNetGatekeeperSheet.swift
//  blocking app
//
//  Shown when the user attempts to delete / disable / modify a Hard-Mode
//  list whose `gatekeeperType` is "nonet" (the default). Presents two
//  honest paths:
//
//    ⓐ "Strong reason" — write ≥200 chars explaining yourself.
//       The reason is saved to DeletionLogStore for later self-reflection,
//       and the action is executed immediately.
//
//    ⓑ "Wait 7 days" — kick off the EmergencyUnlockStore countdown.
//       The list shows a live countdown badge in HomeView. Once the
//       countdown matures the user can deactivate / delete normally.
//
//  The point of (a) is friction-as-feature: an impulsive user can't
//  blow through 200 chars in a moment of weakness, and a motivated
//  user gets out the same minute. (b) is the patient path for users
//  who don't trust their own immediate explanation.
//

import SwiftUI

/// Which Hard-Mode action triggered the gatekeeper sheet.
/// Identifiable so it can drive `.sheet(item:)` directly — the raw value
/// (delete/disable/modify) is the stable id.
enum GatekeeperAction: String, Identifiable {
    case delete
    case disable
    case modify

    var id: String { rawValue }

    func title(isArabic: Bool) -> String {
        switch self {
        case .delete:  return isArabic ? "طلب حذف القائمة" : "Request to delete list"
        case .disable: return isArabic ? "طلب إيقاف الحجب" : "Request to pause block"
        case .modify:  return isArabic ? "طلب تعديل القائمة" : "Request to modify list"
        }
    }

    /// Used as the "actionType" string in DeletionLogStore entries.
    var rawLogKey: String { rawValue }
}

struct NoNetGatekeeperSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var lang: LanguageManager

    let listID: UUID
    let listName: String
    let action: GatekeeperAction
    /// Called when the user completes the "strong reason" path. The caller
    /// is responsible for actually performing the action (delete/disable/modify).
    /// The reason has already been persisted to DeletionLogStore by the time
    /// this fires.
    let onReasonAccepted: () -> Void
    /// Called when the user picks the "wait 7 days" path. The countdown has
    /// already been started in EmergencyUnlockStore by the time this fires —
    /// the caller may use it to refresh UI / show a confirmation toast.
    let onWaitStarted: () -> Void

    @State private var mode: Mode = .choice
    @State private var reason: String = ""
    @State private var showFinalConfirm: Bool = false

    private enum Mode {
        case choice          // initial — pick (a) or (b)
        case writingReason   // option (a) — textarea
    }

    var body: some View {
        NavigationStack {
            content
                .padding(NNSpacing.lg)
                .background(AppColors.uiBackground)
                .navigationTitle(action.title(isArabic: lang.isArabicEffective))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(lang.isArabicEffective ? "إلغاء" : "Cancel") { dismiss() }
                    }
                }
        }
        .alert(
            lang.isArabicEffective ? "تأكيد نهائي" : "Final confirmation",
            isPresented: $showFinalConfirm
        ) {
            Button(lang.isArabicEffective ? "نعم، نفّذ" : "Yes, proceed", role: .destructive) {
                acceptReason()
            }
            Button(lang.isArabicEffective ? "تراجعت" : "Go back", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective
                 ? "هذا قرار لا رجعة فيه. هل تريد المتابعة؟"
                 : "This is irreversible. Continue?")
        }
    }

    @ViewBuilder
    private var content: some View {
        switch mode {
        case .choice:       choiceView
        case .writingReason: reasonView
        }
    }

    // MARK: - Choice view (initial state)

    private var choiceView: some View {
        VStack(alignment: .leading, spacing: NNSpacing.lg) {
            // Lead-in copy explaining NoNet's role.
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.largeTitle)
                    .foregroundColor(AppColors.accent)

                Text(lang.isArabicEffective ? "NoNet هي حارستك" : "NoNet is your gatekeeper")
                    .font(.nnCardTitle)
                    .foregroundColor(AppColors.textPrimary)

                Text(lang.isArabicEffective
                     ? "للمضي بهذا الطلب، اختر طريقة:"
                     : "To proceed with this request, choose a path:")
                    .font(.subheadline)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

            // Option A
            optionCard(
                icon: "square.and.pencil",
                title: lang.isArabicEffective ? "أكتب عذراً قوياً" : "Write a strong reason",
                subtitle: lang.isArabicEffective
                    ? "اشرح بـ \(BlockingConstants.strongReasonMinCharacters)+ حرف، وسيُنفَّذ فوراً"
                    : "Explain in \(BlockingConstants.strongReasonMinCharacters)+ characters; executes immediately",
                isDestructive: true
            ) {
                mode = .writingReason
            }

            // Option B
            optionCard(
                icon: "clock.badge.checkmark",
                title: lang.isArabicEffective ? "انتظر ٧ أيام" : "Wait 7 days",
                subtitle: lang.isArabicEffective
                    ? "يبدأ عدّ تنازلي. بعده يتم التنفيذ تلقائياً. يمكنك إلغاؤه في أي وقت"
                    : "A countdown starts; executes automatically when it ends. Cancelable anytime",
                isDestructive: false
            ) {
                startWait()
            }

            Spacer()
        }
    }

    @ViewBuilder
    private func optionCard(icon: String, title: String, subtitle: String, isDestructive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: NNSpacing.md) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isDestructive ? AppColors.alertRed : AppColors.accent)
                    .frame(width: 36)

                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                }
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

                Image(systemName: lang.isArabicEffective ? "chevron.left" : "chevron.right")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(NNSpacing.md)
            .frame(minHeight: NNHitTarget.minimum + 16)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.control)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Reason view (option A)

    private var reasonView: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.md) {
            Text(lang.isArabicEffective
                 ? "اشرح بالتفصيل لماذا تحتاج هذا الإجراء. كلما كان الشرح أوضح، كان قرارك أصدق مع نفسك."
                 : "Explain in detail why you need this action. The clearer your reasoning, the more honest the decision with yourself.")
                .font(.footnote)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)

            TextEditor(text: $reason)
                .frame(minHeight: 200)
                .padding(NNSpacing.xs)
                .background(AppColors.uiSurface)
                .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                .overlay(
                    RoundedRectangle(cornerRadius: NNRadius.control)
                        .stroke(reasonIsLongEnough ? AppColors.successGreen : AppColors.uiBorder, lineWidth: NNBorder.input)
                )
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                .environment(\.layoutDirection, lang.isArabicEffective ? .rightToLeft : .leftToRight)

            // Live character counter
            HStack {
                if lang.isArabicEffective { Spacer() }
                Text("\(reason.count) / \(BlockingConstants.strongReasonMinCharacters)")
                    .font(.caption)
                    .foregroundColor(reasonIsLongEnough ? AppColors.successGreen : AppColors.textSecondary)
                    .monospacedDigit()
                if !lang.isArabicEffective { Spacer() }
            }

            Button(action: { showFinalConfirm = true }) {
                Text(lang.isArabicEffective ? "تأكيد العذر" : "Confirm reason")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: NNHitTarget.minimum + 4)
                    .background(reasonIsLongEnough ? AppColors.alertRed : AppColors.textDisabled)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            .buttonStyle(.plain)
            .disabled(!reasonIsLongEnough)

            Button(action: { mode = .choice; reason = "" }) {
                Text(lang.isArabicEffective ? "رجوع للخيارات" : "Back to options")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    private var reasonIsLongEnough: Bool {
        reason.trimmingCharacters(in: .whitespacesAndNewlines).count >= BlockingConstants.strongReasonMinCharacters
    }

    // MARK: - Actions

    private func acceptReason() {
        DeletionLogStore.append(
            listID: listID,
            listName: listName,
            actionType: action.rawLogKey,
            reason: reason.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        dismiss()
        // Defer the callback by one runloop tick so the dismiss animation
        // doesn't fight the caller's follow-up UI (e.g. Core Data delete +
        // HomeView refresh).
        DispatchQueue.main.async { onReasonAccepted() }
    }

    private func startWait() {
        EmergencyUnlockStore.requestUnlock(for: listID)
        dismiss()
        DispatchQueue.main.async { onWaitStarted() }
    }
}

#Preview {
    NoNetGatekeeperSheet(
        listID: UUID(),
        listName: "Focus Time",
        action: .delete,
        onReasonAccepted: {},
        onWaitStarted: {}
    )
    .environmentObject(LanguageManager.shared)
}
