import SwiftUI
import CoreData
import CloudKit
import os

/// Codable snapshot of CreateListSheet's in-progress state. Persisted to
/// AppStorage so an interruption (phone call, app switch, accidental dismiss)
/// doesn't waste the user's setup. Cleared on successful save.
///
/// Items (DraftBlockItem + FamilyActivitySelection) are intentionally NOT
/// persisted — Apple's opaque tokens require an active picker session to
/// round-trip reliably. Restoring those would silently produce a broken
/// selection. The user re-picks items; everything else is filled.
private struct CreateListDraftSnapshot: Codable {
    var name: String
    var protection: String
    var blockType: String
    var days: Int
    var hours: Int
    var minutes: Int
    var timeLimitMinutes: Int
    var breaksCount: Int
    var breakDurationMinutes: Int
    var selectedGatekeeper: String
    var savedAt: Date

    /// Drafts older than 24 hours are auto-discarded — if the user didn't come
    /// back the next day, they almost certainly forgot what they were doing.
    var isFresh: Bool {
        Date().timeIntervalSince(savedAt) < 24 * 3600
    }

    /// "Empty enough to ignore" — if the user opened the sheet, touched
    /// nothing, then dismissed, we don't want to offer to restore that.
    var isEmpty: Bool {
        name.isEmpty && blockType == "now" && protection == "noProtection"
            && days == 0 && hours == 0 && minutes == 15
    }
}

struct CreateListSheet: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    // Personalization from onboarding (read-only, used to surface suggestions)
    @AppStorage(AppStorageKeys.obApps) private var obApps: String = ""
    @AppStorage(AppStorageKeys.obCats) private var obCats: String = ""

    // Auto-save draft (JSON blob of CreateListDraftSnapshot)
    @AppStorage(AppStorageKeys.createListDraft) private var draftJSON: String = ""
    @State private var showRestoreDraftAlert: Bool = false

    @State private var name: String = ""
    @State private var protection: String = "noProtection" // hard | noProtection
    @State private var blockType: String = "now" // now | scheduled | timeLimit | forever

    // Wheel pickers (step 5 minutes)
    @State private var days: Int = 0
    @State private var hours: Int = 0
    @State private var minutes: Int = 15
    // Time-Limit (daily quota, in minutes)
    @State private var timeLimitMinutes: Int = 60
    // Breaks UI (UI only)
    @State private var breaksCount: Int = 0
    @State private var breakDurationMinutes: Int = 5
    private let breakDurationOptions: [Int] = [5, 10, 15]

    // Items draft
    @State private var draft = BlockItemsDraft()
    @State private var showingEditor = false

    // Scheduling
    typealias ScheduleSlot = ScheduleSlotModel
    @State private var slots: [ScheduleSlot] = []
    @State private var showScheduleEditor = false

    // Confirm sheet
    @State private var showConfirmSheet = false
    /// Default ON for "now" blocks — if the user picked a fixed-duration
    /// immediate block, the expected behavior is "start it now." Off-by-default
    /// turned the most common path into a 2-step dance.
    @State private var startImmediately: Bool = true
    @State private var showSuccessToast: Bool = false

    // Alerts
    @State private var showLimitAlert = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showForeverFirstAlert = false   // First warning when user picks "Forever"
    /// Unified "danger confirm" sheet — replaces the previous pair of
    /// showHardConfirmAlert + showForeverConfirmAlert. When either Hard Mode
    /// or Forever is in play at save time, this single sheet lists every
    /// consequence and requires explicit checkbox acknowledgement for each.
    @State private var showDangerConfirmSheet = false
    @State private var pendingSeconds: Int64 = 0
    @State private var pendingBaseName: String = ""
    @State private var saveErrorMessage: String? = nil

    // Gatekeeper choice (introduced when Hard Mode is selected). "nonet"
    // means NoNet itself guards the list (200-char reason or 7-day wait via
    // NoNetGatekeeperSheet). "partner" means a human Recovery Partner is
    // attached and will approve/deny delete/disable/modify requests.
    @State private var selectedGatekeeper: String = "nonet"

    // Recovery Partner — only relevant when selectedGatekeeper == "partner".
    @ObservedObject private var partnerStore = CloudKitPartnerStore.shared
    /// nil = no existing partner picked. Otherwise the recordID.recordName
    /// of an existing Partnership the user picked to attach this list to.
    @State private var pendingPartnerID: String? = nil
    /// User selected "send invitation to a new partner" — actual createPartnership
    /// is deferred to PartnerInviteView (which collects ownerName + partner
    /// nickname before calling it).
    @State private var pendingNewInvite: Bool = false
    /// Drives the .sheet that hosts PartnerInviteView. Set in save() after
    /// the list has been persisted; PartnerInviteView reads pendingInviteListID
    /// / pendingInviteListName to know which list to associate.
    @State private var showShareSheet: Bool = false
    @State private var pendingInviteListID: UUID? = nil
    @State private var pendingInviteListName: String = ""
    /// User-facing error when CKShare creation fails (offline, iCloud signed out).
    @State private var partnerCreationError: String? = nil

    // Upgrade sheet
    @State private var showUpgradeSheet = false

    private var minuteOptions: [Int] { Array(stride(from: 0, through: 55, by: 5)) }

    private var baseView: some View {
        NavigationStack {
            contentView
        }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(lang.isArabicEffective ? "إلغاء" : "Cancel") { dismiss() }
                }
            }
    }

    var body: some View {
        let s1 = attachEditorSheet(baseView)
        let s2 = attachScheduleSheet(s1)
        let s3 = attachUpgradeSheet(s2)
        let s4 = attachConfirmSheet(s3)
        let s5 = attachAlerts(s4)
        let s6 = attachDoneBar(s5)
        let s7 = attachPartnerSheets(s6)
        let s8 = attachDraftPersistence(s7)
        return s8
            .successToast(isPresented: $showSuccessToast, message: lang.isArabicEffective ? "تم إنشاء القائمة" : "List created")
    }

    /// Wires up auto-save draft: onAppear shows restore prompt if a fresh
    /// draft is on disk, onChange hooks save the simple form state to
    /// AppStorage on every meaningful edit, and the restore alert offers
    /// "Restore" / "Discard" with a one-line preview of what's saved.
    private func attachDraftPersistence<V: View>(_ v: V) -> some View {
        v
            .onAppear { handleAppearForDraft() }
            .onChange(of: name) { _ in saveDraft() }
            .onChange(of: protection) { _ in saveDraft() }
            .onChange(of: blockType) { _ in saveDraft() }
            .onChange(of: days) { _ in saveDraft() }
            .onChange(of: hours) { _ in saveDraft() }
            .onChange(of: minutes) { _ in saveDraft() }
            .onChange(of: timeLimitMinutes) { _ in saveDraft() }
            .onChange(of: breaksCount) { _ in saveDraft() }
            .onChange(of: breakDurationMinutes) { _ in saveDraft() }
            .onChange(of: selectedGatekeeper) { _ in saveDraft() }
            .alert(
                lang.isArabicEffective ? "استعادة المسوّدة؟" : "Restore draft?",
                isPresented: $showRestoreDraftAlert
            ) {
                Button(lang.isArabicEffective ? "استعادة" : "Restore") {
                    if let snap = readDraft() { applyDraft(snap) }
                }
                Button(lang.isArabicEffective ? "ابدأ من جديد" : "Start fresh", role: .destructive) {
                    clearDraft()
                }
            } message: {
                if let snap = readDraft() {
                    let preview = snap.name.isEmpty
                        ? (lang.isArabicEffective ? "بدون اسم" : "no name")
                        : "\"\(snap.name)\""
                    Text(lang.isArabicEffective
                         ? "وجدنا مسوّدة سابقة (\(preview)). تبي تكمّل من حيث وقفت؟ ملاحظة: عناصر الحجب لن تُسترجع — لازم تختارها مرة ثانية."
                         : "Found a previous draft (\(preview)). Continue where you left off? Note: blocked items won't be restored — you'll need to pick them again.")
                } else {
                    Text("")
                }
            }
    }

    // MARK: - Attach helpers to reduce type-checking cost
    private func attachEditorSheet<V: View>(_ v: V) -> some View {
        v.sheet(isPresented: $showingEditor) {
            BlockItemsEditorView(draft: draft, onSave: { newDraft in self.draft = newDraft })
                .environmentObject(lang)
                .padding(NNSpacing.md)
                .presentationDetents([.medium, .large])
            }
    }
    private func attachScheduleSheet<V: View>(_ v: V) -> some View {
        v.sheet(isPresented: $showScheduleEditor) {
            ScheduleEditorSheet(isArabic: lang.isArabicEffective, initialSlots: slots.map { ScheduleSlotModel(id: $0.id, day: $0.day, fromMinutes: $0.fromMinutes, toMinutes: $0.toMinutes) }) { newSlots in
                    slots = newSlots
                }
                .padding(NNSpacing.md)
                .presentationDetents([.medium, .large])
            }
    }
    private func attachUpgradeSheet<V: View>(_ v: V) -> some View {
        v.sheet(isPresented: $showUpgradeSheet) {
                NavigationView { UpgradeView().environmentObject(lang) }
                    .padding(NNSpacing.md)
                    .presentationDetents([.medium, .large])
            }
    }
    private func attachConfirmSheet<V: View>(_ v: V) -> some View {
        v.sheet(isPresented: $showConfirmSheet) {
                ConfirmCreateSheet(
                    isArabic: lang.isArabicEffective,
                    name: name,
                    protection: protection,
                    blockType: blockType,
                    durationSeconds: Int64(days * BlockingConstants.secondsPerDay + hours * BlockingConstants.secondsPerHour + minutes * BlockingConstants.secondsPerMinute),
                    websites: draft.websites.map { $0.displayName ?? $0.value },
                    apps: draft.apps.map { $0.displayName ?? $0.value },
                    categories: draft.categories.map { $0.displayName ?? $0.value },
                    slots: slots.map { ($0.day, $0.fromMinutes, $0.toMinutes) },
                    onBack: { showConfirmSheet = false },
                    onConfirm: {
                        let totalSeconds = Int64(days * BlockingConstants.secondsPerDay + hours * BlockingConstants.secondsPerHour + minutes * BlockingConstants.secondsPerMinute)
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        pendingSeconds = totalSeconds
                        pendingBaseName = trimmedName
                        if protection == "hard" {
                            // Funnel into the unified danger sheet — replaces
                            // the old showHardConfirmAlert path.
                            showConfirmSheet = false
                            showDangerConfirmSheet = true
                        } else {
                            save(totalSeconds: totalSeconds, baseName: trimmedName)
                        }
                    },
                    startImmediately: $startImmediately
                )
                .padding(NNSpacing.md)
                .presentationDetents([.medium, .large])
            }
    }
    private func attachAlerts<V: View>(_ v: V) -> some View {
        v
            .alert(lang.isArabicEffective ? "وصلت حدّ النسخة المجانية" : "Free plan limit reached", isPresented: $showLimitAlert) {
                Button(lang.isArabicEffective ? "لاحقاً" : "Later", role: .cancel) {}
                Button(lang.isArabicEffective ? "رقّي حسابي" : "Upgrade") {}
            } message: {
                Text(lang.isArabicEffective ? "النسخة المجانية تسمح بـ 3 قوائم. رقّي لـ Premium لقوائم غير محدودة وميزات الجدولة الذكية." : "The free plan allows up to 3 lists. Upgrade to Premium for unlimited lists and smart scheduling.")
            }
            .alert(lang.isArabicEffective ? "تحقق من الإدخالات" : "Check inputs", isPresented: $showValidationAlert) {
                Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert(lang.isArabicEffective ? "الحجب الدائم قرار جادّ" : "Permanent block is serious", isPresented: $showForeverFirstAlert) {
                Button(lang.isArabicEffective ? "فهمت، أكمل" : "I understand, continue") { /* keep blockType = forever */ }
                Button(lang.isArabicEffective ? "إلغاء" : "Cancel", role: .cancel) { blockType = "now" }
            } message: {
                Text(lang.isArabicEffective
                     ? "الحجب الدائم يبقى فعّالاً حتى تحذف القائمة يدوياً. وإذا فعّلت الوضع الصارم أيضاً، فلن تستطيع حذفها على الإطلاق."
                     : "A permanent block stays active until you delete the list. With Hard Mode you cannot delete it at all.")
            }
            .alert(
                lang.isArabicEffective ? "تعذّر حفظ القائمة" : "Couldn't save list",
                isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })
            ) {
                Button(lang.isArabicEffective ? "حاول مجدّداً" : "Try again", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
            .sheet(isPresented: $showDangerConfirmSheet) {
                ConfirmDangerSheet(
                    isArabic: lang.isArabicEffective,
                    isForever: blockType == "forever",
                    isHardMode: protection == "hard",
                    onCancel: { showDangerConfirmSheet = false },
                    onConfirm: {
                        showDangerConfirmSheet = false
                        save(totalSeconds: pendingSeconds, baseName: pendingBaseName)
                    }
                )
                .presentationDetents([.medium, .large])
            }
    }
    private func attachDoneBar<V: View>(_ v: V) -> some View {
        v.safeAreaInset(edge: .bottom) {
            Button(action: { attemptConfirm() }) {
                Text(lang.isArabicEffective ? "تم" : "Done")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .frame(height: NNHitTarget.minimum + 6)
                    // Disabled state: lighter accent + reduced opacity so the
                    // user gets a visual cue that the form isn't complete yet.
                    // Without this, the button looked tappable but did nothing.
                    .background(isFormValid ? AppColors.accent : AppColors.accent.opacity(0.4))
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            }
            .buttonStyle(.plain)
            .disabled(!isFormValid)
            .accessibilityLabel(lang.isArabicEffective ? "تم" : "Done")
            .accessibilityHint(isFormValid
                ? (lang.isArabicEffective ? "إنشاء القائمة" : "Create the list")
                : (lang.isArabicEffective ? "أكمل الاسم والعناصر والمدة لتفعيل الزر" : "Fill name, items, and duration to enable"))
            .padding(.horizontal, NNSpacing.md)
            .padding(.top, NNSpacing.xs)
            .padding(.bottom, NNSpacing.md)
            .background(AppColors.uiBackground)
        }
    }

    /// Two partner-related modals:
    ///   1. PartnerInviteView (CKShare sheet) for the new-partner flow.
    ///   2. Error alert for partnership creation failures.
    ///
    /// The post-save nudge that used to live here was removed when the gatekeeper
    /// choice moved upstream into partnerCard — the user now makes a conscious
    /// pick (NoNet vs Human) before saving, so there's nothing to nudge for.
    private func attachPartnerSheets<V: View>(_ v: V) -> some View {
        v
            .sheet(isPresented: $showShareSheet) {
                if let listID = pendingInviteListID {
                    PartnerInviteView(
                        listID: listID,
                        listName: pendingInviteListName,
                        onCompletion: {
                            showShareSheet = false
                            pendingInviteListID = nil
                            Task { await partnerStore.fetchPartnerships() }
                            // Return to HomeView after a beat — Task.sleep
                            // is cancellation-safe (dismiss on a dismissed
                            // sheet is a harmless no-op anyway, but this
                            // matches the modern pattern used elsewhere).
                            Task { @MainActor in
                                try? await Task.sleep(nanoseconds: 200_000_000)
                                dismiss()
                            }
                        }
                    )
                    .environmentObject(lang)
                }
            }
            .alert(
                lang.isArabicEffective ? "تعذّر إنشاء الشراكة" : "Couldn't create partnership",
                isPresented: Binding(
                    get: { partnerCreationError != nil },
                    set: { if !$0 { partnerCreationError = nil } }
                )
            ) {
                Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) {
                    partnerCreationError = nil
                }
            } message: {
                Text(partnerCreationError ?? "")
            }
    }

    /// True when the form is in its initial "fresh" state — no name, no items,
    /// no protection upgrade, default block type. Used to gate the Quick Start
    /// template row so it disappears once the user starts editing.
    private var isFreshForm: Bool {
        name.isEmpty
            && draft.websites.isEmpty && draft.apps.isEmpty && draft.categories.isEmpty
            && protection == "noProtection" && blockType == "now"
    }

    private var contentView: some View {
        List {
            // ─── Section 0: Quick Start Templates (visible only on fresh form)
            // Three one-tap starting points + a "Custom" escape hatch. Picking
            // a template pre-fills name + blockType + protection + categories
            // so the user is ~80% done before they touch any other card.
            if isFreshForm {
                quickStartTemplatesCard()
            }

            // ─── Section 1: Basics ─────────────────────────────────
            nameCard()

            // ─── Section 2: What to block ──────────────────────────
            // (Single card — was 4 nested cards before: outer "Create
            //  blocking list" wrapper + 3 sub-cards for websites/apps/
            //  categories. The outer wrapper duplicated the nav title.)
            whatToBlockCard()

            // ─── Section 3: When ───────────────────────────────────
            timeToBlockCard()
            if blockType == "now" { durationCard() }
            if blockType == "timeLimit" { timeLimitCard() }

            // ─── Section 4: Protection (+ inline partner choice) ───
            // protectionCard now includes the gatekeeper selection inline when
            // Hard Mode is picked — replaces the previous "two stacked cards"
            // pattern where partnerCard appeared as a separate section.
            protectionCard()

            // ─── Section 5: Breaks ─────────────────────────────────
            breaksCard()
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.uiBackground)
        .navigationTitle(lang.isArabicEffective ? "إنشاء قائمة" : "Create List")
        .listStyle(.insetGrouped)
        // Small bottom padding (24pt) so the last section's footer text
        // (breaksCard's "Choose number of breaks…" line) doesn't crowd up
        // against the sticky Done bar. safeAreaInset reserves the button's
        // height in the scroll area, but Section footer text sits in a
        // tighter zone that can read as "stuck on the button" without an
        // explicit gap. Earlier this was 120pt — that was overkill and
        // created a visible dead zone; 24pt is the sweet spot for a tidy
        // visual break without a ghost gap.
        .padding(.bottom, NNSpacing.xl)
    }

    /// "What to block" — replaces the previous nested-card structure.
    /// One section with: optional suggestion banner → "Add items" CTA →
    /// flat selected-items list grouped by type (chips). Eliminates the
    /// three sub-cards (websitesListCard, appsListCard, categoriesListCard)
    /// in favour of a single readable surface.
    private func whatToBlockCard() -> some View {
        Section(header: HStack(spacing: NNSpacing.xs) {
            Image(systemName: "square.and.pencil")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "ما الذي تريد حجبه؟" : "What to block")
                .font(.nnCardTitle)
        }) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.md) {
                if let suggestion = onboardingSuggestionText() {
                    HStack(alignment: .top, spacing: NNSpacing.xs + 2) {
                        Image(systemName: "sparkles")
                            .foregroundColor(AppColors.accent)
                            .font(.body)
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xxs) {
                            Text(lang.isArabicEffective ? "اقتراحات بناءً على تفضيلاتك" : "Based on your preferences")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(AppColors.accent)
                            Text(suggestion)
                                .font(.footnote)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(NNSpacing.sm)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                }

                Button(action: { openEditor() }) {
                    HStack(spacing: NNSpacing.xs) {
                        Image(systemName: "plus.circle.fill")
                        Text(draft.websites.isEmpty && draft.apps.isEmpty && draft.categories.isEmpty
                             ? (lang.isArabicEffective ? "أضف عناصر الحجب" : "Add items to block")
                             : (lang.isArabicEffective ? "تعديل العناصر" : "Edit items"))
                    }
                    .font(.nnButton)
                    .frame(maxWidth: .infinity)
                    .frame(height: NNHitTarget.minimum)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                }
                .buttonStyle(.plain)

                if draft.websites.isEmpty && draft.apps.isEmpty && draft.categories.isEmpty {
                    Text(lang.isArabicEffective ? "أضف عنصراً واحداً على الأقل" : "Add at least one item")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, NNSpacing.xs)
                } else {
                    selectedItemsSummary()
                }
            }
            .padding(NNSpacing.md)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.card)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .listRowBackground(Color.clear)
    }

    /// Replaces the three separate sub-cards (websites/apps/categories)
    /// with a single compact summary: type chips with counts + a flat
    /// list of selected items. Trusts SwiftUI's RTL handling — no manual
    /// `if isArabic { Spacer; Text } else { Text; Spacer }` hacks.
    @ViewBuilder
    private func selectedItemsSummary() -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            HStack(spacing: NNSpacing.xs) {
                if draft.websites.count > 0 { itemTypeChip(icon: "globe", count: draft.websites.count, label: lang.isArabicEffective ? "موقع" : "site") }
                if draft.apps.count > 0 { itemTypeChip(icon: "app.fill", count: draft.apps.count, label: lang.isArabicEffective ? "تطبيق" : "app") }
                if draft.categories.count > 0 { itemTypeChip(icon: "square.grid.2x2.fill", count: draft.categories.count, label: lang.isArabicEffective ? "فئة" : "category") }
                Spacer(minLength: 0)
            }
            ForEach(allSelectedItems, id: \.id) { item in
                HStack(spacing: NNSpacing.xs) {
                    Image(systemName: iconFor(kind: item.kind))
                        .foregroundColor(AppColors.textSecondary)
                        .font(.caption)
                    Text(item.displayName ?? item.value)
                        .font(.footnote)
                        .foregroundColor(AppColors.textPrimary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Spacer(minLength: 0)
                }
                .padding(.vertical, NNSpacing.xxs)
            }
        }
    }

    /// All selected items flattened into one array for the summary list.
    private var allSelectedItems: [DraftBlockItem] {
        draft.websites + draft.apps + draft.categories
    }

    private func iconFor(kind: DraftBlockItem.Kind) -> String {
        switch kind {
        case .website: return "globe"
        case .app: return "app.fill"
        case .category: return "square.grid.2x2.fill"
        }
    }

    @ViewBuilder
    private func itemTypeChip(icon: String, count: Int, label: String) -> some View {
        HStack(spacing: NNSpacing.xxs) {
            Image(systemName: icon).font(.caption2)
            Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption)
        }
        .foregroundColor(AppColors.accent)
        .padding(.horizontal, NNSpacing.xs)
        .padding(.vertical, NNSpacing.xxs)
        .background(AppColors.infoBg)
        .clipShape(Capsule())
    }

    private func nameCard() -> some View {
        Section(header: HStack(spacing: NNSpacing.xs) {
            Image(systemName: "tag")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "اسم القائمة" : "List Name")
                .font(.nnCardTitle)
        }) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                // Smart suggestions — render only when the user hasn't picked
                // a name yet AND the form has enough signal (items + blockType)
                // to generate a meaningful suggestion. Disappears the moment
                // they tap one or start typing.
                if name.isEmpty && !smartNameSuggestions().isEmpty {
                    smartNameSuggestionRow()
                }
                TextField(lang.isArabicEffective ? "مثال: وقت التركيز" : "e.g., Focus Time", text: $name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(NNSpacing.sm)
                    .background(AppColors.uiSurface)
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: NNRadius.control)
                            .stroke(AppColors.uiBorder, lineWidth: NNBorder.input)
                    )
                    // Cap at 40 chars so the list name fits visually on
                    // HomeView cards without truncation. Clamp via onChange
                    // rather than .textField API (which lacks a maxLength).
                    .onChange(of: name) { newValue in
                        if newValue.count > 40 {
                            name = String(newValue.prefix(40))
                        }
                    }
                HStack {
                    if !isNameValid, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(lang.isArabicEffective ? "الاسم قصير جداً" : "Name is too short")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                    }
                    Spacer()
                    Text("\(name.count)/40")
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                        .monospacedDigit()
                }
            }
            .padding(NNSpacing.lg)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.container)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Cards (unchanged)
    private func timeToBlockCard() -> some View {
        Section(header: HStack(spacing: NNSpacing.xs) {
            Image(systemName: "clock")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "وقت الحجب" : "Time to block")
                .font(.nnCardTitle)
        }) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                // 2×2 grid of block-type cards. Replaces the 4-segment picker
                // because (a) segments give every option equal visual weight,
                // letting "Forever" hide in plain sight next to "Now," and
                // (b) segments can't carry the short descriptions that make
                // the distinction between Now/Scheduled/Daily-Limit/Forever
                // legible without reading docs.
                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: NNSpacing.sm),
                        GridItem(.flexible(), spacing: NNSpacing.sm)
                    ],
                    spacing: NNSpacing.sm
                ) {
                    blockTypeCard(
                        tag: "now",
                        icon: "bolt.fill",
                        titleAr: "فوري", titleEn: "Now",
                        subtitleAr: "ابدأ الآن لمدة محددة",
                        subtitleEn: "Start now for a set time",
                        isDestructive: false
                    )
                    blockTypeCard(
                        tag: "scheduled",
                        icon: "calendar",
                        titleAr: "مجدول", titleEn: "Scheduled",
                        subtitleAr: "في أوقات محددة من الأسبوع",
                        subtitleEn: "At set times each week",
                        isDestructive: false
                    )
                    blockTypeCard(
                        tag: "timeLimit",
                        icon: "hourglass.bottomhalf.filled",
                        titleAr: "حد يومي", titleEn: "Daily Limit",
                        subtitleAr: "X دقيقة كل يوم ثم يقفل",
                        subtitleEn: "X minutes per day, then lock",
                        isDestructive: false
                    )
                    blockTypeCard(
                        tag: "forever",
                        icon: "infinity",
                        titleAr: "دائم", titleEn: "Forever",
                        subtitleAr: "بلا نهاية — حتى الحذف",
                        subtitleEn: "No end — until deleted",
                        isDestructive: true
                    )
                }
                .onChange(of: blockType) { newVal in
                    if newVal == "scheduled" && !isPremium {
                        blockType = "now"
                        showLimitAlert = true
                        showUpgradeSheet = true
                    } else if newVal == "scheduled" && isPremium {
                        showScheduleEditor = true
                    } else if newVal == "forever" {
                        // First warning fires immediately on selection so the user can revert
                        showForeverFirstAlert = true
                    }
                }

                // Forever-block notice — kept inline because it's tightly
                // coupled to the picker choice. Reduced padding + lighter
                // background tint so it reads as a callout, not a panic alert.
                if blockType == "forever" {
                    HStack(alignment: .top, spacing: NNSpacing.xs) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(AppColors.alertRed)
                            .font(.footnote)
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 2) {
                            Text(lang.isArabicEffective ? "حجب دائم — لا نهاية" : "Permanent block — no end")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(AppColors.alertRed)
                            Text(lang.isArabicEffective
                                 ? "يبقى الحجب فعّالاً حتى تحذف القائمة. مع الوضع الصارم لا يمكن الحذف."
                                 : "Stays active until you delete the list. With Hard Mode, deletion is blocked.")
                                .font(.caption)
                                .foregroundColor(AppColors.textSecondary)
                                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(NNSpacing.sm)
                    .background(AppColors.alertRed.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    .overlay(
                        RoundedRectangle(cornerRadius: NNRadius.control)
                            .stroke(AppColors.alertRed.opacity(0.25), lineWidth: NNBorder.hairline)
                    )
                }

                if !isPremium {
                    Text(lang.isArabicEffective ? "الجدولة ضمن الترقية." : "Scheduling is in Upgrade.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                    Button(action: { showUpgradeSheet = true }) {
                        Text(lang.isArabicEffective ? "ترقية / تجربة 7 أيام" : "Upgrade / 7‑day Trial")
                }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.accent)
                }

                if blockType == "scheduled" && isPremium {
                    if !slots.isEmpty {
                        Text(scheduleSummary(slots))
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                    }
                    if slots.isEmpty {
                        Text(lang.isArabicEffective ? "لا توجد فترات مجدولة بعد" : "No schedule slots yet")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                } else {
                        ForEach(slots) { s in
                        Group {
                                if lang.isArabicEffective {
                                    HStack { Text(timeRangeLabel(s)).foregroundColor(AppColors.textSecondary); Spacer(); Text(dayName(s.day)) }
                            } else {
                                    HStack { Text(dayName(s.day)); Spacer(); Text(timeRangeLabel(s)).foregroundColor(AppColors.textSecondary) }
                            }
                        }
                    }
                        .onDelete { indexSet in slots.remove(atOffsets: indexSet) }
                }
                    Button(action: { showScheduleEditor = true }) { Label(lang.isArabicEffective ? "تحرير الجدول" : "Edit Schedule", systemImage: "calendar") }
                }
            }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            .padding(NNSpacing.lg)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.container)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .listRowBackground(Color.clear)
    }

    /// Single cell in the 2×2 block-type grid (Now / Scheduled / Daily Limit /
    /// Forever). Tapping a card flips `blockType` to its tag; `.onChange` on
    /// `blockType` higher up still fires the schedule/upgrade/forever logic.
    ///
    /// Visual states:
    ///   - Inactive: hairline border + neutral background
    ///   - Active: accent border + tinted bg + accent icon
    ///   - Active + destructive (Forever): red border + red-tinted bg
    ///     so users see at a glance that this is the dangerous choice
    @ViewBuilder
    private func blockTypeCard(
        tag: String,
        icon: String,
        titleAr: String, titleEn: String,
        subtitleAr: String, subtitleEn: String,
        isDestructive: Bool
    ) -> some View {
        let isSelected = blockType == tag
        let activeColor = isDestructive ? AppColors.alertRed : AppColors.accent
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            blockType = tag
        }) {
            VStack(alignment: .center, spacing: NNSpacing.xxs) {
                Image(systemName: icon)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(isSelected ? activeColor : AppColors.textSecondary)
                    .frame(height: 28)
                Text(lang.isArabicEffective ? titleAr : titleEn)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(lang.isArabicEffective ? subtitleAr : subtitleEn)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .top)
            .padding(.horizontal, NNSpacing.sm)
            .padding(.vertical, NNSpacing.sm)
            .background(isSelected ? activeColor.opacity(0.12) : Color.clear)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.card)
                    .stroke(isSelected ? activeColor : AppColors.uiBorder,
                            lineWidth: isSelected ? NNBorder.input : NNBorder.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lang.isArabicEffective ? titleAr : titleEn)
        .accessibilityHint(lang.isArabicEffective ? subtitleAr : subtitleEn)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }

    private func durationCard() -> some View {
        Section(header: HStack(spacing: NNSpacing.xs) {
            Image(systemName: "hourglass")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "المدة" : "Duration")
                .font(.nnCardTitle)
        }) {
            VStack(alignment: .center, spacing: NNSpacing.sm) {
                // Three compact wheels — reduced from 140pt to 110pt height
                // and labels moved beside the pickers so total card height
                // shrinks from ~190pt to ~150pt on iPhone SE.
                HStack(alignment: .center, spacing: NNSpacing.sm) {
                    durationWheelColumn(label: lang.isArabicEffective ? "أيام" : "Days",
                                        binding: $days, range: 0...360)
                    durationWheelColumn(label: lang.isArabicEffective ? "ساعات" : "Hours",
                                        binding: $hours, range: 0...23)
                    durationWheelColumn(label: lang.isArabicEffective ? "دقائق" : "Min",
                                        binding: $minutes, values: minuteOptions)
                }
                Text(lang.isArabicEffective ? "الحد الأدنى 5 دقائق." : "Minimum duration is 5 minutes.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                if blockType == "now" && !isDurationValid {
                    Text(lang.isArabicEffective ? "اختر مدة لا تقل عن 5 دقائق" : "Select at least 5 minutes")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
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
        .listRowBackground(Color.clear)
    }

    /// Single column of the duration picker (label + compact wheel).
    /// Two overloads: contiguous Int range OR custom values array (used for
    /// the minutes column which steps by 5).
    @ViewBuilder
    private func durationWheelColumn(label: String, binding: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .center, spacing: NNSpacing.xxs) {
            Text(label).font(.caption).foregroundColor(AppColors.textSecondary)
            Picker(label, selection: binding) {
                ForEach(Array(range), id: \.self) { Text("\($0)").monospacedDigit() }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .clipped()
        }
    }

    @ViewBuilder
    private func durationWheelColumn(label: String, binding: Binding<Int>, values: [Int]) -> some View {
        VStack(alignment: .center, spacing: NNSpacing.xxs) {
            Text(label).font(.caption).foregroundColor(AppColors.textSecondary)
            Picker(label, selection: binding) {
                ForEach(values, id: \.self) { Text("\($0)").monospacedDigit() }
            }
            .pickerStyle(.wheel)
            .frame(maxWidth: .infinity)
            .frame(height: 110)
            .clipped()
        }
    }

    private func timeLimitCard() -> some View {
        Section(header: HStack(spacing: NNSpacing.xs) {
            Image(systemName: "hourglass.bottomhalf.filled")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "الحد اليومي" : "Daily Limit")
                .font(.nnCardTitle)
        },
        footer: Text(lang.isArabicEffective
                     ? "يبدأ كل يوم بدون حجب. بعد استخدام التطبيقات/المواقع للمدة المحددة، يتفعّل الحجب حتى منتصف الليل."
                     : "Each day starts with no block. After using the selected apps/sites for this many minutes, the block kicks in until midnight.")
            .font(.footnote)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
        ) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                Picker("DailyLimit", selection: $timeLimitMinutes) {
                    ForEach(BlockingConstants.timeLimitOptions, id: \.self) { v in
                        Text(lang.isArabicEffective ? "\(v) دقيقة" : "\(v) min").tag(v)
                    }
                }
                .pickerStyle(.segmented)

                let summaryAr = "سيسمح بـ \(timeLimitMinutes) دقيقة يومياً قبل تفعيل الحجب."
                let summaryEn = "Allows \(timeLimitMinutes) minute(s) per day before the block kicks in."
                Text(lang.isArabicEffective ? summaryAr : summaryEn)
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            .padding(NNSpacing.lg)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.container)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .listRowBackground(Color.clear)
    }

    /// Protection + gatekeeper, fused into one card. Replaces the previous
    /// pattern of two sequential cards (`protectionCard` + `partnerCard`)
    /// that broke the conceptual link between "Hard Mode" and "who guards it."
    ///
    /// Structure:
    ///   - Two top-level option rows (No Protection / Hard Mode)
    ///   - When Hard Mode is picked, a nested gatekeeper section reveals:
    ///       - NoNet (default)
    ///       - Human partner → sub-options for existing/new partner
    ///
    /// All visuals reuse the existing `partnerOptionRow` for consistency.
    private func protectionCard() -> some View {
        Section(header: HStack(spacing: NNSpacing.xs) {
            Image(systemName: "shield.checkered")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "الحماية" : "Protection")
                .font(.nnCardTitle)
        }) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                // Top-level protection choice — uses the same option-row visual
                // as the gatekeeper choices below so the whole card reads as
                // one nested decision tree.
                partnerOptionRow(
                    title: lang.isArabicEffective ? "بدون حماية" : "No Protection",
                    subtitle: lang.isArabicEffective ? "تعديل/حذف في أي وقت" : "Edit or delete anytime",
                    isSelected: protection == "noProtection",
                    action: { protection = "noProtection" }
                )

                partnerOptionRow(
                    title: lang.isArabicEffective ? "الوضع الصارم" : "Hard Mode",
                    subtitle: lang.isArabicEffective ? "صعب الإيقاف أثناء المدة" : "Hard to stop during duration",
                    isSelected: protection == "hard",
                    action: { protection = "hard" }
                )

                // Nested gatekeeper section — only visible when Hard Mode is on.
                // Indented (leading padding) so the user reads it as "sub-choice
                // of Hard Mode" rather than as a peer to the two options above.
                if protection == "hard" {
                    Divider()
                        .padding(.vertical, NNSpacing.xxs)

                    Text(lang.isArabicEffective ? "من يحرس قائمتك؟" : "Who guards this list?")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(AppColors.textPrimary)
                        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

                    Text(lang.isArabicEffective
                         ? "الحارس هو من يقرّر متى يمكن حذف/إيقاف/تعديل القائمة."
                         : "The gatekeeper decides when this list can be deleted, paused, or modified.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

                    // NoNet (default) gatekeeper option
                    partnerOptionRow(
                        title: lang.isArabicEffective ? "NoNet (افتراضي)" : "NoNet (default)",
                        subtitle: lang.isArabicEffective
                            ? "للحذف: عذر مفصّل (\(BlockingConstants.strongReasonMinCharacters)+ حرف) أو انتظار ٧ أيام"
                            : "To delete: a \(BlockingConstants.strongReasonMinCharacters)+ char reason or a 7-day wait",
                        isSelected: selectedGatekeeper == "nonet",
                        action: {
                            selectedGatekeeper = "nonet"
                            pendingPartnerID = nil
                            pendingNewInvite = false
                        }
                    )

                    // Human partner gatekeeper option
                    partnerOptionRow(
                        title: lang.isArabicEffective ? "شريك بشري" : "Human partner",
                        subtitle: lang.isArabicEffective
                            ? "صديق/قريب يوافق أو يرفض طلباتك — حساب اجتماعي أقوى"
                            : "A friend or family member approves or denies — stronger accountability",
                        isSelected: selectedGatekeeper == "partner",
                        action: { selectedGatekeeper = "partner" }
                    )

                    if selectedGatekeeper == "partner" {
                        partnerSubOptions
                            .padding(.top, NNSpacing.xs)
                            .padding(lang.isArabicEffective ? .trailing : .leading, NNSpacing.md)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            .padding(NNSpacing.lg)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.container)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .listRowBackground(Color.clear)
    }

    /// Sub-list shown beneath the "Human partner" option: existing accepted
    /// partnerships (if any) + the "send new invitation" entry. Picking one
    /// of these is required before save when `selectedGatekeeper == "partner"`.
    @ViewBuilder
    private var partnerSubOptions: some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs) {
            let existingPartnerships = partnerStore.partnerships.filter { $0.status == .accepted }
            if !existingPartnerships.isEmpty {
                ForEach(existingPartnerships, id: \.id) { partnership in
                    partnerOptionRow(
                        title: partnership.partnerDisplayName ?? (lang.isArabicEffective ? "شريك بدون اسم" : "Unnamed partner"),
                        subtitle: lang.isArabicEffective ? "شريك موجود" : "Existing partner",
                        isSelected: pendingPartnerID == partnership.id,
                        action: {
                            pendingPartnerID = partnership.id
                            pendingNewInvite = false
                        }
                    )
                }
            }

            partnerOptionRow(
                title: lang.isArabicEffective ? "أرسل دعوة لشريك جديد" : "Send invitation to a new partner",
                subtitle: lang.isArabicEffective ? "ينشأ رابط الدعوة بعد حفظ القائمة" : "The invite link is created after saving",
                isSelected: pendingNewInvite,
                action: {
                    pendingNewInvite = true
                    pendingPartnerID = nil
                }
            )

            if pendingPartnerID == nil && !pendingNewInvite {
                Text(lang.isArabicEffective
                     ? "اختر شريكاً موجوداً أو أرسل دعوة جديدة قبل الحفظ"
                     : "Pick an existing partner or send a new invite before saving")
                    .font(.caption)
                    .foregroundColor(AppColors.alertRed)
                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                    .padding(.top, NNSpacing.xxs)
            }
        }
    }

    /// Single tappable row inside `partnerCard`. Visual: title + subtitle + a
    /// checkmark when selected. Used for "No partner" + each existing partner.
    @ViewBuilder
    private func partnerOptionRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: NNSpacing.sm) {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(AppColors.textPrimary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppColors.textSecondary)
                }
                Spacer()
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
                            lineWidth: isSelected ? NNBorder.strong : NNBorder.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    private func breaksCard() -> some View {
        Section(header: HStack(spacing: NNSpacing.xs) {
            Image(systemName: "cup.and.saucer")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "الاستراحات المسموحة" : "Allows Breaks")
                .font(.nnCardTitle)
        },
        footer: Text(lang.isArabicEffective ? "حدّد عدد الاستراحات خلال 24 ساعة ومدة كل استراحة." : "Choose number of breaks across 24h and the duration of each.")
            .font(.footnote)
            .foregroundColor(AppColors.textSecondary)
            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
        ) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs - 2) {
                    Text(lang.isArabicEffective ? "العدد" : "Count")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                    // Range 0-5 fits a segmented picker perfectly — wheel
                    // was overkill for six discrete values.
                    Picker("Breaks", selection: $breaksCount) {
                        ForEach(0...5, id: \.self) { Text("\($0)").tag($0) }
                    }
                    .pickerStyle(.segmented)
                }
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xs - 2) {
                    Text(lang.isArabicEffective ? "مدة كل استراحة" : "Duration of each break")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                    Picker("Break Duration", selection: $breakDurationMinutes) {
                        ForEach(breakDurationOptions, id: \.self) { v in
                            Text(lang.isArabicEffective ? "\(v) دقائق" : "\(v) minutes").tag(v)
                        }
                    }
                    .pickerStyle(.segmented)
                }
                let summaryAr = "ستُتاح \(breaksCount) استراحة خلال 24 ساعة، مدة كل واحدة \(breakDurationMinutes) دقيقة."
                let summaryEn = "You can take \(breaksCount) break(s) across 24h, each for \(breakDurationMinutes) minutes."
                Text(lang.isArabicEffective ? summaryAr : summaryEn)
                                                .font(.footnote)
                                                .foregroundColor(AppColors.textSecondary)
                                        }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            .padding(NNSpacing.lg)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.container)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .listRowBackground(Color.clear)
    }
    
    // MARK: - Quick Start Templates
    //
    // One-tap presets that prefill 80% of the form. The user can still edit
    // any field after applying. Templates intentionally do NOT seed
    // FamilyActivitySelection tokens (Apple's API requires an active picker
    // session) — they prefill `draft.categories` instead, which the editor
    // picks up when the user opens it to add specific apps.

    /// Internal template descriptor. Lives at the bottom of the file as a
    /// static array (`Self.builtInTemplates`).
    fileprivate struct ListTemplate: Identifiable {
        let id: String
        let icon: String
        let iconColor: Color
        let titleAr: String
        let titleEn: String
        let subtitleAr: String
        let subtitleEn: String
        let suggestedNameAr: String
        let suggestedNameEn: String
        let blockType: String         // "now" | "scheduled" | "timeLimit" | "forever"
        let protection: String        // "noProtection" | "hard"
        let categoriesAr: [String]    // raw labels (must match CategoryOptionsAr in editor)
        let categoriesEn: [String]
        let durationMinutes: Int      // for "now" — converted to days/hours/minutes
        let timeLimitMinutes: Int     // for "timeLimit"
    }

    private static let builtInTemplates: [ListTemplate] = [
        ListTemplate(
            id: "focus",
            icon: "target",
            iconColor: .blue,
            titleAr: "تركيز",
            titleEn: "Focus",
            subtitleAr: "احجب السوشيال والمقاطع لساعة",
            subtitleEn: "Block social & shorts for an hour",
            suggestedNameAr: "وقت التركيز",
            suggestedNameEn: "Focus Time",
            blockType: "now",
            protection: "noProtection",
            categoriesAr: ["وسائل التواصل الاجتماعي", "الشورتس والريلز"],
            categoriesEn: ["Social Media", "Shorts & Reels"],
            durationMinutes: 60,
            timeLimitMinutes: 0
        ),
        ListTemplate(
            id: "sleep",
            icon: "moon.fill",
            iconColor: .purple,
            titleAr: "نوم",
            titleEn: "Sleep",
            subtitleAr: "حد يومي ٣٠ دقيقة للسوشيال",
            subtitleEn: "30 min/day cap on social",
            suggestedNameAr: "وضع النوم",
            suggestedNameEn: "Sleep Mode",
            blockType: "timeLimit",
            protection: "noProtection",
            categoriesAr: ["وسائل التواصل الاجتماعي", "الشورتس والريلز", "الألعاب"],
            categoriesEn: ["Social Media", "Shorts & Reels", "Games"],
            durationMinutes: 0,
            timeLimitMinutes: 30
        ),
        ListTemplate(
            id: "adult",
            icon: "shield.lefthalf.filled",
            iconColor: .red,
            titleAr: "حماية صارمة",
            titleEn: "Strict Block",
            subtitleAr: "محتوى للبالغين + قمار، دائم",
            subtitleEn: "Adult + gambling, permanent",
            suggestedNameAr: "حماية دائمة",
            suggestedNameEn: "Strict Protection",
            blockType: "forever",
            protection: "hard",
            categoriesAr: ["محتوى للبالغين", "تطبيقات المقامرة"],
            categoriesEn: ["Adult Content", "Gambling Apps"],
            durationMinutes: 0,
            timeLimitMinutes: 0
        )
    ]

    private func quickStartTemplatesCard() -> some View {
        Section(header: HStack(spacing: NNSpacing.xs) {
            Image(systemName: "wand.and.stars")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "بداية سريعة" : "Quick Start")
                .font(.nnCardTitle)
        }) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.sm) {
                Text(lang.isArabicEffective
                     ? "اختر قالباً جاهزاً (يمكنك التعديل بعد) أو ابدأ من الصفر."
                     : "Pick a template (editable after) or start from scratch.")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

                LazyVGrid(
                    columns: [
                        GridItem(.flexible(), spacing: NNSpacing.sm),
                        GridItem(.flexible(), spacing: NNSpacing.sm)
                    ],
                    spacing: NNSpacing.sm
                ) {
                    ForEach(Self.builtInTemplates) { template in
                        templateCard(template)
                    }
                    customStartCard()
                }
            }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            .padding(NNSpacing.lg)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.container))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.container)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private func templateCard(_ template: ListTemplate) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            applyTemplate(template)
        }) {
            VStack(alignment: .center, spacing: NNSpacing.xxs) {
                Image(systemName: template.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(template.iconColor)
                    .frame(height: 28)
                Text(lang.isArabicEffective ? template.titleAr : template.titleEn)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(lang.isArabicEffective ? template.subtitleAr : template.subtitleEn)
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .top)
            .padding(.horizontal, NNSpacing.sm)
            .padding(.vertical, NNSpacing.sm)
            .background(AppColors.uiBackground)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.card)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(lang.isArabicEffective ? template.titleAr : template.titleEn)
        .accessibilityHint(lang.isArabicEffective ? template.subtitleAr : template.subtitleEn)
    }

    /// Fourth grid cell — explicit "skip templates, build from scratch" option.
    /// Same visual register as the template cards so the choice doesn't feel
    /// asymmetric, but its action is a no-op that just dismisses the section
    /// by giving the form a sentinel character (a single space) — that flips
    /// `isFreshForm` to false so the templates row hides itself.
    @ViewBuilder
    private func customStartCard() -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            // Move the form out of "fresh" state without seeding anything —
            // a non-breaking space in `name` is invisible to the user but
            // flips isFreshForm to false. They'll replace it the moment they
            // start typing.
            name = "\u{00A0}"
            // Then immediately clear so the trim-based isNameValid still
            // shows them the "name is too short" hint when they save without
            // a real name. Async dispatch so the isFreshForm flip happens
            // first (one runloop later) before the field empties.
            DispatchQueue.main.async {
                self.name = ""
            }
        }) {
            VStack(alignment: .center, spacing: NNSpacing.xxs) {
                Image(systemName: "square.and.pencil")
                    .font(.title2.weight(.semibold))
                    .foregroundColor(AppColors.textSecondary)
                    .frame(height: 28)
                Text(lang.isArabicEffective ? "مخصصة" : "Custom")
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(AppColors.textPrimary)
                    .lineLimit(1)
                Text(lang.isArabicEffective ? "ابدأ من الصفر" : "Start from scratch")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, minHeight: 100, alignment: .top)
            .padding(.horizontal, NNSpacing.sm)
            .padding(.vertical, NNSpacing.sm)
            .background(AppColors.uiBackground)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.card))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.card)
                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
            )
        }
        .buttonStyle(.plain)
    }

    /// Apply a template's prefill values to the form state. Items aren't
    /// seeded into FamilyActivitySelection (Apple requires an active picker
    /// session), but `draft.categories` IS populated so the editor opens with
    /// the category set already ticked.
    private func applyTemplate(_ template: ListTemplate) {
        // Name + block type + protection
        name = lang.isArabicEffective ? template.suggestedNameAr : template.suggestedNameEn
        blockType = template.blockType
        protection = template.protection

        // Duration / time-limit prefill
        if template.durationMinutes > 0 {
            let total = template.durationMinutes
            days = total / (24 * 60)
            let rem1 = total % (24 * 60)
            hours = rem1 / 60
            minutes = rem1 % 60
            // Round minutes to nearest 5 (picker step) so the wheel snaps
            // to a valid value when the user opens it.
            if !minuteOptions.contains(minutes) {
                minutes = minuteOptions.min(by: { abs($0 - minutes) < abs($1 - minutes) }) ?? 15
            }
        }
        if template.timeLimitMinutes > 0 {
            timeLimitMinutes = template.timeLimitMinutes
        }

        // Categories prefill — uses raw labels matching BlockItemsEditorView's
        // category options. The editor reads `draft.categories` on open and
        // ticks matching entries automatically.
        let labels = lang.isArabicEffective ? template.categoriesAr : template.categoriesEn
        draft.categories = labels.map {
            DraftBlockItem(kind: .category, value: $0, displayName: $0)
        }
    }

    // MARK: - Smart name suggestions
    //
    // Picks 2-4 plausible names from the user's selections + block type. Pure
    // heuristic, no ML — the patterns cover the most common list intents
    // (social detox, study mode, sleep mode, permanent porn block, etc.).

    /// Returns 0-4 suggested names, ordered by relevance to the current draft.
    /// Returns empty if there's not enough signal yet (no items + default
    /// settings) — empty list hides the chip row entirely.
    private func smartNameSuggestions() -> [String] {
        let isAr = lang.isArabicEffective
        var out: [String] = []

        // Heuristics on selected categories — match against the raw value
        // strings since they're consistent across languages (we localize at
        // display time, not at category-key time).
        let catValues = draft.categories.map { $0.value }
        let hasSocial = catValues.contains { $0.contains("التواصل") || $0.lowercased().contains("social") }
        let hasShorts = catValues.contains { $0.contains("الشورتس") || $0.lowercased().contains("shorts") }
        let hasGames = catValues.contains { $0.contains("الألعاب") || $0.lowercased().contains("game") }
        let hasAdult = catValues.contains { $0.contains("للبالغين") || $0.lowercased().contains("adult") }
        let hasGambling = catValues.contains { $0.contains("المقامرة") || $0.lowercased().contains("gambling") }
        let hasShopping = catValues.contains { $0.contains("التسوق") || $0.lowercased().contains("shopping") }

        // Block-type-driven names take priority because they describe the
        // intent more strongly than the items do (Forever = "permanent X",
        // Daily Limit = "daily quota," etc.).
        if blockType == "forever" {
            if hasAdult { out.append(isAr ? "حجب دائم للبالغين" : "Permanent Adult Block") }
            if hasGambling { out.append(isAr ? "حجب القمار" : "Block Gambling") }
            out.append(isAr ? "حجب دائم" : "Permanent Block")
        } else if blockType == "scheduled" {
            if hasSocial || hasShorts { out.append(isAr ? "وقت التركيز" : "Focus Time") }
            out.append(isAr ? "ساعات العمل" : "Work Hours")
            out.append(isAr ? "وقت النوم" : "Sleep Mode")
        } else if blockType == "timeLimit" {
            if hasSocial { out.append(isAr ? "حد السوشيال" : "Social Limit") }
            if hasShorts { out.append(isAr ? "حد المقاطع القصيرة" : "Shorts Limit") }
            out.append(isAr ? "حد يومي" : "Daily Quota")
        } else { // "now"
            if hasSocial || hasShorts { out.append(isAr ? "ابتعد عن السوشيال" : "Social Detox") }
            if hasGames { out.append(isAr ? "وقت الدراسة" : "Study Time") }
            if hasShopping { out.append(isAr ? "ابتعد عن التسوق" : "No-Spend Hours") }
            out.append(isAr ? "وقت التركيز" : "Focus Time")
        }

        // Hard Mode adds urgency to the name — prefix one suggestion.
        if protection == "hard", let first = out.first {
            out[0] = (isAr ? "إقفال: " : "Lock: ") + first
        }

        // Dedupe + cap at 4 to keep the chip row from wrapping into 2 lines.
        var seen: Set<String> = []
        let unique = out.filter { seen.insert($0).inserted }
        return Array(unique.prefix(4))
    }

    /// Horizontal scrollable row of suggestion chips. Tapping one fills the
    /// name field; the row hides itself the moment `name` becomes non-empty
    /// (driven by the parent's `if name.isEmpty` guard, not this view).
    @ViewBuilder
    private func smartNameSuggestionRow() -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.xxs) {
            HStack(spacing: NNSpacing.xxs) {
                Image(systemName: "sparkles")
                    .font(.caption2)
                    .foregroundColor(AppColors.accent)
                Text(lang.isArabicEffective ? "اقتراحات" : "Suggestions")
                    .font(.caption.weight(.medium))
                    .foregroundColor(AppColors.textSecondary)
            }
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: NNSpacing.xs) {
                    ForEach(smartNameSuggestions(), id: \.self) { suggestion in
                        Button(action: {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            name = suggestion
                        }) {
                            Text(suggestion)
                                .font(.caption.weight(.medium))
                                .foregroundColor(AppColors.accent)
                                .padding(.horizontal, NNSpacing.sm)
                                .padding(.vertical, NNSpacing.xs - 2)
                                .background(AppColors.infoBg)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule()
                                        .stroke(AppColors.accent.opacity(0.3), lineWidth: NNBorder.hairline)
                                )
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(suggestion)
                        .accessibilityHint(lang.isArabicEffective ? "املأ الاسم بهذا الاقتراح" : "Fill name with this suggestion")
                    }
                }
            }
        }
    }

    // MARK: - Draft auto-save
    //
    // Persist the simple form state to AppStorage on every meaningful change.
    // Items aren't persisted (FamilyActivitySelection tokens are opaque), so
    // restoring a draft fills name/duration/protection/breaks but the user
    // must re-pick the items to block.

    private func currentSnapshot() -> CreateListDraftSnapshot {
        CreateListDraftSnapshot(
            name: name,
            protection: protection,
            blockType: blockType,
            days: days,
            hours: hours,
            minutes: minutes,
            timeLimitMinutes: timeLimitMinutes,
            breaksCount: breaksCount,
            breakDurationMinutes: breakDurationMinutes,
            selectedGatekeeper: selectedGatekeeper,
            savedAt: Date()
        )
    }

    private func saveDraft() {
        let snap = currentSnapshot()
        // Don't persist truly empty drafts — would just clutter AppStorage and
        // surface useless restore prompts.
        guard !snap.isEmpty else { return }
        guard let data = try? JSONEncoder().encode(snap),
              let json = String(data: data, encoding: .utf8) else { return }
        draftJSON = json
    }

    private func clearDraft() {
        draftJSON = ""
    }

    /// Read the persisted draft if it exists and is fresh + non-empty. Returns
    /// nil if there's nothing to restore.
    private func readDraft() -> CreateListDraftSnapshot? {
        guard !draftJSON.isEmpty,
              let data = draftJSON.data(using: .utf8),
              let snap = try? JSONDecoder().decode(CreateListDraftSnapshot.self, from: data),
              snap.isFresh, !snap.isEmpty
        else { return nil }
        return snap
    }

    private func applyDraft(_ snap: CreateListDraftSnapshot) {
        name = snap.name
        protection = snap.protection
        blockType = snap.blockType
        days = snap.days
        hours = snap.hours
        minutes = snap.minutes
        timeLimitMinutes = snap.timeLimitMinutes
        breaksCount = snap.breaksCount
        breakDurationMinutes = snap.breakDurationMinutes
        selectedGatekeeper = snap.selectedGatekeeper
    }

    /// Called on first appearance — if a fresh, non-empty draft exists, prompt
    /// the user to restore. They can dismiss to start fresh (which also clears
    /// the draft so the prompt won't reappear).
    private func handleAppearForDraft() {
        if readDraft() != nil {
            showRestoreDraftAlert = true
        }
    }

    // Logic helpers
    private func openEditor() { draft.name = name; showingEditor = true }

    /// Build a localized list of categories+apps the user selected during onboarding,
    /// so we can hint at relevant blocking targets when they create their first list.
    /// Returns nil when the user skipped onboarding or selected nothing actionable.
    private func onboardingSuggestionText() -> String? {
        let catIDs = obCats.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0 != "other" }
        let appIDs = obApps.split(separator: ",").map { String($0).trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty && $0 != "other" }
        var labels: [String] = []
        labels.append(contentsOf: catIDs.compactMap { localizedCategoryLabel(for: $0) })
        labels.append(contentsOf: appIDs.compactMap { localizedAppLabel(for: $0) })
        guard !labels.isEmpty else { return nil }
        let joined = labels.joined(separator: lang.isArabicEffective ? "، " : ", ")
        return lang.isArabicEffective
            ? "اخترت سابقاً: \(joined). افتح \"أضف عناصر\" وحدّدها من المختار."
            : "You previously chose: \(joined). Open \"Add items\" to select them in the picker."
    }

    private func localizedCategoryLabel(for id: String) -> String? {
        let ar: [String: String] = ["social": "السوشيال", "short_videos": "المقاطع القصيرة", "gaming": "الألعاب", "adult": "الإباحية", "gambling": "القمار", "shopping": "التسوق", "news": "الأخبار"]
        let en: [String: String] = ["social": "Social", "short_videos": "Short Videos", "gaming": "Gaming", "adult": "Adult", "gambling": "Gambling", "shopping": "Shopping", "news": "News"]
        return lang.isArabicEffective ? ar[id] : en[id]
    }

    private func localizedAppLabel(for id: String) -> String? {
        let labels: [String: String] = ["tiktok": "TikTok", "youtube": "YouTube", "instagram": "Instagram", "snapchat": "Snapchat", "x": "X", "games": lang.isArabicEffective ? "الألعاب" : "Games"]
        return labels[id]
    }
    private func attemptConfirm() {
        // Free-tier monetization gates — enforced here so the user never reaches
        // the confirm sheet or save() without the upgrade alert when they've hit
        // their limit. Premium users skip both checks.
        if !isPremium {
            if currentListsCount() >= BlockingConstants.freeTierListLimit {
                showLimitAlert = true
                showUpgradeSheet = true
                return
            }
            if protection == "hard" && currentHardListsCount() >= BlockingConstants.freeTierHardLimit {
                showLimitAlert = true
                showUpgradeSheet = true
                return
            }
        }

        // Validation
        if blockType == "scheduled" && isPremium && slots.isEmpty {
            validationMessage = lang.isArabicEffective ? "أضف فترة جدولة واحدة على الأقل" : "Add at least one schedule slot"
            showValidationAlert = true
            return
        }
        guard isFormValid else {
            validationMessage = lang.isArabicEffective ? "تحقق من الاسم والعناصر والمدة" : "Check name, items and duration"
            showValidationAlert = true
            return
        }
        // Gatekeeper validation — when the user picked "Human partner" but no
        // sub-option (existing or new invite), refuse to proceed. The inline
        // error already nudges them; this just stops a silent save.
        if protection == "hard" && selectedGatekeeper == "partner" && pendingPartnerID == nil && !pendingNewInvite {
            validationMessage = lang.isArabicEffective
                ? "اختر شريكاً موجوداً أو أرسل دعوة جديدة"
                : "Pick an existing partner or send a new invite"
            showValidationAlert = true
            return
        }
        // Forever skips the duration step but still goes through the unified
        // danger sheet (replaces showForeverConfirmAlert + showHardConfirmAlert).
        if blockType == "forever" {
            pendingBaseName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            pendingSeconds = 0
            showDangerConfirmSheet = true
            return
        }
        // Time-Limit stores the daily quota in durationSeconds; skip the confirm sheet
        // (its duration display assumes a contiguous block, not a daily quota).
        if blockType == "timeLimit" {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            pendingBaseName = trimmed
            pendingSeconds = Int64(timeLimitMinutes * 60)
            if protection == "hard" {
                // Unified danger sheet covers Hard Mode confirmation here too.
                showDangerConfirmSheet = true
            } else {
                save(totalSeconds: pendingSeconds, baseName: trimmed)
            }
            return
        }
        showConfirmSheet = true
    }
    private func save(totalSeconds: Int64, baseName: String) {
        let finalName = uniqueName(from: baseName)
        let entity = ListEntity(context: context)
        entity.id = UUID()
        entity.name = finalName
        entity.protection = protection
        entity.blockType = blockType
        entity.durationSeconds = totalSeconds
        entity.scheduleSlots = encodeSlots()
        entity.createdAt = Date()
        entity.updatedAt = Date()
        // Gatekeeper is meaningful only for Hard Mode. For non-protected lists
        // we still persist "nonet" so the attribute is never empty (Core Data
        // requires it). Reading code branches on `protection == "hard"` first.
        entity.gatekeeperType = (protection == "hard") ? selectedGatekeeper : "nonet"
        // Persist items
        var itemsSet: Set<BlockItemEntity> = []
        for w in draft.websites {
            let it = BlockItemEntity(context: context)
            it.id = UUID(); it.kind = "website"; it.value = w.value; it.displayName = w.displayName; it.list = entity
            itemsSet.insert(it)
        }
        for a in draft.apps {
            let it = BlockItemEntity(context: context)
            it.id = UUID(); it.kind = "app"; it.value = a.value; it.displayName = a.displayName; it.list = entity
            itemsSet.insert(it)
        }
        for c in draft.categories {
            let it = BlockItemEntity(context: context)
            it.id = UUID(); it.kind = "category"; it.value = c.value; it.displayName = c.displayName; it.list = entity
            itemsSet.insert(it)
        }
        entity.items = itemsSet
        // Persist breaks (UserDefaults store by list id)
        BreaksStore.save(for: entity.id, count: breaksCount, durationMinutes: breakDurationMinutes)
        // Persist the FamilyActivitySelection (apps/categories/web tokens chosen via picker).
        FamilySelectionStore.save(draft.familySelection, for: entity.id)
        switch context.saveIfNeeded() {
        case .failure(let error):
            // Log technical details internally; show the user a friendly, actionable message.
            // List name is PII (user might pick a sensitive label) → .private.
            // Error description may contain internal paths/keys → also .private.
            Logger(subsystem: "app.nonet.blocking", category: "CreateListSheet")
                .error("Core Data save failed while creating list '\(pendingBaseName, privacy: .private)': \(error.localizedDescription, privacy: .private)")
            saveErrorMessage = lang.isArabicEffective
                ? "لم نتمكّن من حفظ القائمة الآن. جرّب مرّة ثانية، وإذا تكرّر الخطأ أعد تشغيل التطبيق."
                : "We couldn't save the list right now. Try again, and if it keeps failing, restart the app."
            return
        case .success:
            // Clear the auto-save draft now that the list is persisted —
            // the next CreateListSheet open should be a clean form.
            clearDraft()
        }
        // Apply blocking immediately when appropriate.
        let shouldStartNow = blockType == "now" && (startImmediately || protection == "hard")
        if shouldStartNow {
            if protection != "hard" {
                ManualStateStore.toggle(for: entity.id)
            }
            BlockingEngine.shared.activate(list: entity)
        }
        // For scheduled lists, register the schedule (shields apply only inside the window).
        if blockType == "scheduled" {
            BlockingEngine.shared.activate(list: entity)
        }
        // Forever blocks always activate immediately and stay until the list is purged.
        if blockType == "forever" {
            BlockingEngine.shared.activate(list: entity)
        }
        // Time-Limit registers the daily quota monitor; the monitor extension applies
        // the shield only after the user crosses the threshold.
        if blockType == "timeLimit" {
            BlockingEngine.shared.activate(list: entity)
        }
        showSuccessToast = true

        // Recovery Partner wiring — applies only for Hard Mode lists with the
        // human-partner gatekeeper. With `selectedGatekeeper == "nonet"` the
        // app itself guards the list (NoNetGatekeeperSheet at delete time);
        // no CloudKit hand-off needed.
        // Capture list metadata before we leave this scope (entity is owned by
        // the managed object context; passing the raw values is safer).
        let savedID = entity.id
        let savedName = entity.name
        if protection == "hard" && selectedGatekeeper == "partner" {
            if let chosenPartnerID = pendingPartnerID {
                Task {
                    await partnerStore.attachPartnership(chosenPartnerID, toList: savedID)
                }
                dismissAfterToastDelay()
            } else if pendingNewInvite {
                // Defer dismissal — the share flow needs to present first.
                Task { await beginNewInviteFlow(listID: savedID, listName: savedName) }
            } else {
                // attemptConfirm() guards against this case (refuses to save
                // when "Human partner" is picked with no sub-option), so we
                // never reach here in normal flow. Dismiss defensively.
                dismissAfterToastDelay()
            }
        } else {
            // Non-Hard list, OR Hard list with NoNet gatekeeper — no partner consideration.
            dismissAfterToastDelay()
        }
    }

    /// 1.2s pause then dismiss — gives the success toast time to be seen
    /// before the sheet slides out. Task.sleep replaces DispatchQueue.main.
    /// asyncAfter so the dismiss is cancellation-safe if the view goes away
    /// for any other reason in the meantime.
    private func dismissAfterToastDelay() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_200_000_000)
            dismiss()
        }
    }

    /// Hand off to PartnerInviteView, which collects ownerDisplayName +
    /// proposedPartnerName, calls createPartnership itself, and then presents
    /// the Apple share sheet. The parent CreateListSheet stays open until
    /// PartnerInviteView fires `onCompletion`, after which both close.
    private func beginNewInviteFlow(listID: UUID, listName: String) async {
        await MainActor.run {
            pendingInviteListID = listID
            pendingInviteListName = listName
            showShareSheet = true
        }
    }
    private func currentListsCount() -> Int {
        let req: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        return (try? context.count(for: req)) ?? 0
    }
    private func currentHardListsCount() -> Int {
        let req: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        req.predicate = NSPredicate(format: "protection ==[c] %@", "hard")
        return (try? context.count(for: req)) ?? 0
    }
    private func uniqueName(from base: String) -> String {
        let trimmed = base.isEmpty ? (lang.isArabicEffective ? "قائمة جديدة" : "New List") : base
        if !nameExists(trimmed) { return trimmed }
        var idx = 2
        while nameExists("\(trimmed) (\(idx))") { idx += 1 }
        return "\(trimmed) (\(idx))"
    }
    private func nameExists(_ n: String) -> Bool {
        let req: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
        req.predicate = NSPredicate(format: "name ==[c] %@", n)
        req.fetchLimit = 1
        let count = (try? context.count(for: req)) ?? 0
        return count > 0
    }
    private var isNameValid: Bool {
        name.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2
    }
    private var hasAtLeastOneItem: Bool {
        !draft.websites.isEmpty || !draft.apps.isEmpty || !draft.categories.isEmpty
    }
    private var isDurationValid: Bool {
        if blockType == "now" {
            let total = days * BlockingConstants.secondsPerDay + hours * BlockingConstants.secondsPerHour + minutes * BlockingConstants.secondsPerMinute
            return total >= 300 // >= 5 minutes
        }
        if blockType == "timeLimit" {
            return timeLimitMinutes >= 5
        }
        return true
    }
    private var isFormValid: Bool {
        isNameValid && hasAtLeastOneItem && isDurationValid
    }
    private func dayName(_ d: Int) -> String {
        let ar = ["الأحد","الاثنين","الثلاثاء","الأربعاء","الخميس","الجمعة","السبت"]
        let en = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        return lang.isArabicEffective ? ar[d] : en[d]
    }
    private func timeRangeLabel(_ s: ScheduleSlot) -> String {
        func fmt(_ m: Int) -> String { String(format: "%02d:%02d", m/60, m%60) }
        return "\(fmt(s.fromMinutes)) - \(fmt(s.toMinutes))"
    }
    private func encodeSlots() -> Data? {
        guard blockType == "scheduled", !slots.isEmpty else { return nil }
        let payload = slots.map { ScheduleSlotV1(id: $0.id, day: $0.day, fromMinutes: $0.fromMinutes, toMinutes: $0.toMinutes) }
        return SchedulePersistence.encode(payload)
    }
    private func scheduleSummary(_ list: [ScheduleSlot]) -> String {
        let uniqueTimes = Set(list.map { "\($0.fromMinutes)-\($0.toMinutes)" })
        func fmt(_ m: Int) -> String { String(format: "%02d:%02d", m/60, m%60) }
        if uniqueTimes.count == 1, let first = list.first {
            let from = first.fromMinutes, to = first.toMinutes
            let days = Array(Set(list.map { $0.day })).sorted()
            func contiguous(_ ds: [Int]) -> Bool { guard ds.count >= 2 else { return false }; for i in 1..<ds.count { if ds[i] != ds[i-1]+1 { return false } } ; return true }
            let daysDesc: String
            if contiguous(days) && days.count >= 2, let firstDay = days.first, let lastDay = days.last {
                daysDesc = dayName(firstDay) + "–" + dayName(lastDay)
            } else if days.count <= 3 {
                daysDesc = days.map { dayName($0) }.joined(separator: lang.isArabicEffective ? "، " : ", ")
            } else {
                return lang.isArabicEffective ? "\(days.count) أيام مجدولة" : "\(days.count) scheduled days"
            }
            return daysDesc + " " + fmt(from) + "–" + fmt(to)
        }
        return lang.isArabicEffective ? "\(list.count) فترات" : "\(list.count) slots"
    }
}

// MARK: - ConfirmDangerSheet
//
// Single sheet that replaces the previous trio of alerts
// (showForeverFirstAlert + showForeverConfirmAlert + showHardConfirmAlert).
// Shows ALL consequences in one view with checkboxes the user must tick
// before the destructive button enables.
//
// Why one sheet instead of stacked alerts: testers in the original flow
// reflexively tapped "OK" through 3 modals without reading. A single sheet
// with consequence rows + checkboxes forces the eye to land on each
// consequence and explicitly acknowledge it before the confirm enables.
private struct ConfirmDangerSheet: View {
    let isArabic: Bool
    let isForever: Bool
    let isHardMode: Bool
    var onCancel: () -> Void
    var onConfirm: () -> Void

    @State private var ackForever: Bool = false
    @State private var ackHard: Bool = false

    private var requiresAckForever: Bool { isForever }
    private var requiresAckHard: Bool { isHardMode }

    /// Confirm enabled only when every applicable consequence has been ticked.
    private var canConfirm: Bool {
        (requiresAckForever ? ackForever : true) && (requiresAckHard ? ackHard : true)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: NNSpacing.lg) {
                // Header — large warning icon + title that names what's about
                // to happen in plain language.
                VStack(spacing: NNSpacing.xs) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .font(.system(size: 44))
                        .foregroundColor(AppColors.alertRed)
                        .padding(.top, NNSpacing.md)
                    Text(headerTitle)
                        .font(.title2.weight(.bold))
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.textPrimary)
                    Text(headerSubtitle)
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.horizontal, NNSpacing.md)
                }

                // Consequences list — one row per applicable danger. Each row
                // is icon + headline + body so the consequence reads as a
                // discrete fact, not a wall of warning text.
                VStack(spacing: NNSpacing.sm) {
                    if isForever {
                        consequenceRow(
                            icon: "infinity",
                            headline: isArabic ? "بلا نهاية تلقائية" : "No automatic end",
                            body: isArabic
                                ? "يبقى الحجب فعّالاً حتى تحذف القائمة يدوياً من شاشة التطبيق."
                                : "Stays active until you manually delete the list from inside the app."
                        )
                    }
                    if isHardMode {
                        consequenceRow(
                            icon: "lock.fill",
                            headline: isArabic ? "صعب الإيقاف" : "Hard to stop",
                            body: isArabic
                                ? "لا يمكن تعديل أو حذف القائمة بسهولة خلال المدة. الحذف يتطلب عذراً مفصّلاً أو انتظار ٧ أيام."
                                : "You can't simply edit or delete the list during the duration. Deletion requires a detailed reason or a 7-day wait."
                        )
                    }
                    if isForever && isHardMode {
                        consequenceRow(
                            icon: "exclamationmark.octagon.fill",
                            headline: isArabic ? "الجمع بين الاثنين = إقفال شبه دائم" : "Combining both = near-permanent lock",
                            body: isArabic
                                ? "مع تفعيل الوضع الصارم + الحجب الدائم، تصبح القائمة شبه مستحيلة الإزالة قبل ٧ أيام."
                                : "With Hard Mode + Permanent block, this list becomes nearly impossible to remove before 7 days.",
                            tone: .severe
                        )
                    }
                }
                .padding(.horizontal, NNSpacing.md)

                // Checkboxes — one per danger. canConfirm gates the confirm
                // button on these. Order: forever first, then hard mode.
                VStack(spacing: NNSpacing.sm) {
                    if requiresAckForever {
                        ackToggle(
                            isOn: $ackForever,
                            label: isArabic
                                ? "فهمت أن الحجب يبقى حتى أحذف القائمة يدوياً."
                                : "I understand the block stays until I manually delete the list."
                        )
                    }
                    if requiresAckHard {
                        ackToggle(
                            isOn: $ackHard,
                            label: isArabic
                                ? "فهمت أن إيقاف الحجب يتطلب عذراً مفصّلاً أو انتظار ٧ أيام."
                                : "I understand stopping the block requires a detailed reason or a 7-day wait."
                        )
                    }
                }
                .padding(.horizontal, NNSpacing.md)

                // Action buttons — destructive primary on top because that's
                // the "I really want this" action; cancel below so an accidental
                // tap on the wrong side of the screen doesn't trigger it.
                VStack(spacing: NNSpacing.xs) {
                    Button(action: { if canConfirm { onConfirm() } }) {
                        Text(confirmLabel)
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: NNHitTarget.minimum + 6)
                            .background(canConfirm ? AppColors.alertRed : AppColors.alertRed.opacity(0.4))
                            .foregroundColor(.white)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canConfirm)

                    Button(action: { onCancel() }) {
                        Text(isArabic ? "تراجعت، رجّعني" : "Cancel")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: NNHitTarget.minimum + 6)
                            .background(AppColors.uiSurface)
                            .foregroundColor(AppColors.textPrimary)
                            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                            .overlay(
                                RoundedRectangle(cornerRadius: NNRadius.control)
                                    .stroke(AppColors.uiBorder, lineWidth: NNBorder.hairline)
                            )
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, NNSpacing.md)
                .padding(.bottom, NNSpacing.lg)
            }
        }
        .background(AppColors.uiBackground.ignoresSafeArea())
    }

    private var headerTitle: String {
        switch (isForever, isHardMode) {
        case (true, true):
            return isArabic ? "حجب دائم + وضع صارم" : "Permanent + Hard Mode"
        case (true, false):
            return isArabic ? "حجب دائم" : "Permanent Block"
        case (false, true):
            return isArabic ? "تفعيل الوضع الصارم" : "Enable Hard Mode"
        default:
            return isArabic ? "تأكيد" : "Confirm"
        }
    }

    private var headerSubtitle: String {
        switch (isForever, isHardMode) {
        case (true, true):
            return isArabic
                ? "اقرأ كل نقطة ووافق قبل التفعيل."
                : "Read each point and acknowledge before activating."
        case (true, false):
            return isArabic
                ? "قرار جادّ — راجع التفاصيل ثم وافق."
                : "Serious decision — review and acknowledge."
        case (false, true):
            return isArabic
                ? "الوضع الصارم يقلّل سيطرتك أثناء المدة بشكل متعمَّد."
                : "Hard Mode intentionally reduces your control during the duration."
        default:
            return ""
        }
    }

    private var confirmLabel: String {
        if isForever && isHardMode {
            return isArabic ? "نعم، فعّل الإثنين" : "Yes, enable both"
        } else if isForever {
            return isArabic ? "فعّل الحجب الدائم" : "Enable permanent block"
        } else {
            return isArabic ? "فعّل الوضع الصارم" : "Enable Hard Mode"
        }
    }

    /// Visual tone for a consequence row — `.standard` uses muted red text,
    /// `.severe` uses solid red background for the combined-danger case.
    private enum ConsequenceTone { case standard, severe }

    @ViewBuilder
    private func consequenceRow(icon: String, headline: String, body: String, tone: ConsequenceTone = .standard) -> some View {
        HStack(alignment: .top, spacing: NNSpacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(tone == .severe ? .white : AppColors.alertRed)
                .frame(width: 32, alignment: .center)
                .padding(.top, 2)
            VStack(alignment: isArabic ? .trailing : .leading, spacing: 4) {
                Text(headline)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(tone == .severe ? .white : AppColors.textPrimary)
                Text(body)
                    .font(.footnote)
                    .foregroundColor(tone == .severe ? Color.white.opacity(0.9) : AppColors.textSecondary)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
            }
            .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
        }
        .padding(NNSpacing.md)
        .background(tone == .severe ? AppColors.alertRed : AppColors.alertRed.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
        .overlay(
            RoundedRectangle(cornerRadius: NNRadius.control)
                .stroke(tone == .severe ? Color.clear : AppColors.alertRed.opacity(0.25), lineWidth: NNBorder.hairline)
        )
    }

    @ViewBuilder
    private func ackToggle(isOn: Binding<Bool>, label: String) -> some View {
        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            isOn.wrappedValue.toggle()
        }) {
            HStack(alignment: .top, spacing: NNSpacing.sm) {
                Image(systemName: isOn.wrappedValue ? "checkmark.square.fill" : "square")
                    .font(.title3)
                    .foregroundColor(isOn.wrappedValue ? AppColors.accent : AppColors.textSecondary)
                Text(label)
                    .font(.footnote)
                    .foregroundColor(AppColors.textPrimary)
                    .multilineTextAlignment(isArabic ? .trailing : .leading)
                    .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
            }
            .padding(NNSpacing.sm)
            .frame(minHeight: NNHitTarget.minimum)
            .background(AppColors.uiSurface)
            .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
            .overlay(
                RoundedRectangle(cornerRadius: NNRadius.control)
                    .stroke(isOn.wrappedValue ? AppColors.accent : AppColors.uiBorder,
                            lineWidth: isOn.wrappedValue ? NNBorder.input : NNBorder.hairline)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    CreateListSheet()
        .environmentObject(LanguageManager.shared)
}

// MARK: - Toast Overlay
extension View {
    func successToast(isPresented: Binding<Bool>, message: String) -> some View {
        ZStack {
            self
            if isPresented.wrappedValue {
                VStack {
                    Spacer()
                    Text(message)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, NNSpacing.md)
                        .padding(.vertical, NNSpacing.sm)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: NNRadius.control))
                        .padding(.bottom, NNSpacing.lg + 4)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isPresented.wrappedValue)
            }
        }
    }
}