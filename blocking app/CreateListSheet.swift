import SwiftUI
import CoreData
import CloudKit
import os

struct CreateListSheet: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    // Personalization from onboarding (read-only, used to surface suggestions)
    @AppStorage(AppStorageKeys.obApps) private var obApps: String = ""
    @AppStorage(AppStorageKeys.obCats) private var obCats: String = ""

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
    @State private var startImmediately: Bool = false
    @State private var showSuccessToast: Bool = false

    // Alerts
    @State private var showLimitAlert = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showHardConfirmAlert = false
    @State private var showForeverFirstAlert = false   // First warning when user picks "Forever"
    @State private var showForeverConfirmAlert = false // Second warning before saving Forever
    @State private var pendingSeconds: Int64 = 0
    @State private var pendingBaseName: String = ""
    @State private var saveErrorMessage: String? = nil

    // Recovery Partner (Phase 2 of v1.3.0 — inline step inside CreateListSheet)
    @ObservedObject private var partnerStore = CloudKitPartnerStore.shared
    /// nil = no partner selected (the default). Otherwise the recordID.recordName
    /// of an existing Partnership the user picked to attach this list to.
    @State private var pendingPartnerID: String? = nil
    /// User selected "send invitation to a new partner" — the actual CKShare
    /// creation defers until after the list saves (we need the saved list's
    /// UUID to associate with the partnership record).
    @State private var pendingNewInvite: Bool = false
    /// Holds the CKShare after `createPartnership` resolves. When non-nil and
    /// `showShareSheet` is true, PartnerInviteView presents it.
    @State private var pendingShare: CKShare? = nil
    /// Drives the .sheet that wraps PartnerInviteView.
    @State private var showShareSheet: Bool = false
    /// User-facing error when CKShare creation fails (offline, iCloud signed out).
    @State private var partnerCreationError: String? = nil
    /// Post-save nudge: triggered when the user saved a Hard Mode list without
    /// selecting/inviting a partner. Reminds them once that the option exists.
    @State private var showPostSavePartnerNudge: Bool = false
    /// Passed to the nudge so it knows which list was just created (used when
    /// the user taps "Add partner" from the nudge — kicks off the same
    /// createPartnership + share flow as the inline option).
    @State private var savedListIDForNudge: UUID? = nil
    /// Display name used when creating the partnership (the list's name).
    @State private var savedListNameForNudge: String = ""

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
        return s7
            .successToast(isPresented: $showSuccessToast, message: lang.isArabicEffective ? "تم إنشاء القائمة" : "List created")
    }

    // MARK: - Attach helpers to reduce type-checking cost
    private func attachEditorSheet<V: View>(_ v: V) -> some View {
        v.sheet(isPresented: $showingEditor) {
            BlockItemsEditorView(draft: draft, onSave: { newDraft in self.draft = newDraft })
                .environmentObject(lang)
                .padding(16)
                .presentationDetents([.medium, .large])
            }
    }
    private func attachScheduleSheet<V: View>(_ v: V) -> some View {
        v.sheet(isPresented: $showScheduleEditor) {
            ScheduleEditorSheet(isArabic: lang.isArabicEffective, initialSlots: slots.map { ScheduleSlotModel(id: $0.id, day: $0.day, fromMinutes: $0.fromMinutes, toMinutes: $0.toMinutes) }) { newSlots in
                    slots = newSlots
                }
                .padding(16)
                .presentationDetents([.medium, .large])
            }
    }
    private func attachUpgradeSheet<V: View>(_ v: V) -> some View {
        v.sheet(isPresented: $showUpgradeSheet) {
                NavigationView { UpgradeView().environmentObject(lang) }
                    .padding(16)
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
                    durationSeconds: Int64(days * 86400 + hours * 3600 + minutes * 60),
                    websites: draft.websites.map { $0.displayName ?? $0.value },
                    apps: draft.apps.map { $0.displayName ?? $0.value },
                    categories: draft.categories.map { $0.displayName ?? $0.value },
                    slots: slots.map { ($0.day, $0.fromMinutes, $0.toMinutes) },
                    onBack: { showConfirmSheet = false },
                    onConfirm: {
                        let totalSeconds = Int64(days * 86400 + hours * 3600 + minutes * 60)
                        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                        pendingSeconds = totalSeconds
                        pendingBaseName = trimmedName
                        if protection == "hard" {
                            showConfirmSheet = false
                            showHardConfirmAlert = true
                        } else {
                            save(totalSeconds: totalSeconds, baseName: trimmedName)
                        }
                    },
                    startImmediately: $startImmediately
                )
                .padding(16)
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
            .alert(lang.isArabicEffective ? "تفعيل الوضع الصارم" : "Enable Hard Mode", isPresented: $showHardConfirmAlert) {
                Button(lang.isArabicEffective ? "فعّل الوضع الصارم" : "Enable Hard Mode") { save(totalSeconds: pendingSeconds, baseName: pendingBaseName) }
                Button(lang.isArabicEffective ? "تراجعت، رجّعني" : "No, go back", role: .cancel) {}
            } message: {
                Text(lang.isArabicEffective ? "الوضع الصارم يقفل القائمة طوال المدّة. لا تستطيع تعديلها أو حذفها أو إيقاف الحجب حتى ينتهي الوقت. هذا الإلزام متعمَّد، لتعزيز التزامك بالقرار." : "Hard Mode locks this list for the full duration. You can't edit, delete, or pause the block until time runs out. This is intentional, to strengthen your commitment.")
            }
            .alert(lang.isArabicEffective ? "الحجب الدائم قرار جادّ" : "Permanent block is serious", isPresented: $showForeverFirstAlert) {
                Button(lang.isArabicEffective ? "فهمت، أكمل" : "I understand, continue") { /* keep blockType = forever */ }
                Button(lang.isArabicEffective ? "إلغاء" : "Cancel", role: .cancel) { blockType = "now" }
            } message: {
                Text(lang.isArabicEffective
                     ? "الحجب الدائم يبقى فعّالاً حتى تحذف القائمة يدوياً. وإذا فعّلت الوضع الصارم أيضاً، فلن تستطيع حذفها على الإطلاق."
                     : "A permanent block stays active until you delete the list. With Hard Mode you cannot delete it at all.")
            }
            .alert(lang.isArabicEffective ? "تأكيد نهائي" : "Final Confirmation", isPresented: $showForeverConfirmAlert) {
                Button(lang.isArabicEffective ? "أوافق، فعّل الحجب الدائم" : "I agree — enable permanent block", role: .destructive) {
                    if protection == "hard" {
                        showForeverConfirmAlert = false
                        showHardConfirmAlert = true
                    } else {
                        save(totalSeconds: 0, baseName: pendingBaseName)
                    }
                }
                Button(lang.isArabicEffective ? "إلغاء" : "Cancel", role: .cancel) {}
            } message: {
                Text(lang.isArabicEffective
                     ? "بعد التفعيل، لن تعمل التطبيقات والمواقع المختارة على الإطلاق حتى تحذف القائمة يدوياً. ومع الوضع الصارم، حتى الحذف لن يكون متاحاً."
                     : "Once enabled, the selected apps and sites will never work until you manually delete this list. With Hard Mode, even deletion won't be available.")
            }
            .alert(
                lang.isArabicEffective ? "تعذّر حفظ القائمة" : "Couldn't save list",
                isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })
            ) {
                Button(lang.isArabicEffective ? "حاول مجدّداً" : "Try again", role: .cancel) { saveErrorMessage = nil }
            } message: {
                Text(saveErrorMessage ?? "")
            }
    }
    private func attachDoneBar<V: View>(_ v: V) -> some View {
        v.safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    EmptyView()
                    Button(action: { attemptConfirm() }) {
                        Text(lang.isArabicEffective ? "تم" : "Done")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                        .background(AppColors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                    .disabled(!isFormValid)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 16)
            .background(AppColors.uiBackground)
        }
    }

    /// Three partner-related modals:
    ///   1. PartnerInviteView (CKShare sheet) for the new-partner flow.
    ///   2. Post-save nudge when Hard Mode saves without a partner.
    ///   3. Error alert for partnership creation failures.
    private func attachPartnerSheets<V: View>(_ v: V) -> some View {
        v
            .sheet(isPresented: $showShareSheet) {
                // Same wiring as HomeView's invite flow.
                if let share = pendingShare {
                    PartnerInviteView(
                        share: share,
                        container: partnerStore.container,
                        isArabic: lang.isArabicEffective,
                        onCompletion: {
                            showShareSheet = false
                            pendingShare = nil
                            Task { await partnerStore.fetchPartnerships() }
                            // The user finished the share flow — dismiss the
                            // CreateListSheet to return them to HomeView.
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { dismiss() }
                        }
                    )
                    .ignoresSafeArea()
                }
            }
            .sheet(isPresented: $showPostSavePartnerNudge) {
                postSavePartnerNudge
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

    /// One-time reminder shown after a Hard Mode list saves with no partner.
    /// Resolved by either "Add partner" (opens PartnerInviteView preloaded
    /// with the saved list's UUID) or "Later" (just dismisses). Either way,
    /// the CreateListSheet itself dismisses after the nudge is resolved.
    @ViewBuilder
    private var postSavePartnerNudge: some View {
        VStack(spacing: NNSpacing.lg) {
            Spacer()
            Image(systemName: "person.2.fill")
                .font(.largeTitle)
                .foregroundColor(AppColors.accent)
                .frame(width: 72, height: 72)
                .background(AppColors.infoBg)
                .clipShape(Circle())

            Text(lang.isArabicEffective ? "هل تضيف شريك تعافي؟" : "Add a recovery partner?")
                .font(.title2.weight(.semibold))
                .multilineTextAlignment(.center)

            Text(lang.isArabicEffective
                 ? "تم تفعيل الوضع الصارم. إضافة شريك تعافي تزيد التزامك بالقرار، ويتولّى تنبيهك عند محاولة كسر الحجب."
                 : "Hard Mode is on. A recovery partner gets notified when you try to bypass the block — better accountability, stronger commitment.")
                .font(.subheadline)
                .foregroundColor(AppColors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, NNSpacing.lg)

            Spacer()

            VStack(spacing: NNSpacing.sm) {
                Button(action: {
                    // Close the nudge, then trigger the same share flow as
                    // the inline option (createPartnership → PartnerInviteView).
                    showPostSavePartnerNudge = false
                    guard let savedID = savedListIDForNudge else {
                        dismiss()
                        return
                    }
                    Task { await beginNewInviteFlow(listID: savedID, listName: savedListNameForNudge) }
                }) {
                    Text(lang.isArabicEffective ? "أضف شريكاً" : "Add partner")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                        .background(AppColors.accent)
                        .foregroundColor(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)

                Button(action: {
                    showPostSavePartnerNudge = false
                    dismiss()
                }) {
                    Text(lang.isArabicEffective ? "لاحقاً" : "Later")
                        .font(.subheadline)
                        .foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, NNSpacing.xl)
            .padding(.bottom, NNSpacing.lg)
        }
        .padding(.top, NNSpacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppColors.uiBackground)
        .environment(\.layoutDirection, lang.isArabicEffective ? .rightToLeft : .leftToRight)
        .presentationDetents([.medium])
    }

    private var contentView: some View {
        List {
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

            // ─── Section 4: Protection ─────────────────────────────
            protectionCard()
            partnerCard() // appears only when protection == "hard"

            // ─── Section 5: Breaks ─────────────────────────────────
            breaksCard()
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.uiBackground)
        .navigationTitle(lang.isArabicEffective ? "إنشاء قائمة" : "Create List")
        .listStyle(.insetGrouped)
        .padding(.bottom, 120)
    }

    /// "What to block" — replaces the previous nested-card structure.
    /// One section with: optional suggestion banner → "Add items" CTA →
    /// flat selected-items list grouped by type (chips). Eliminates the
    /// three sub-cards (websitesListCard, appsListCard, categoriesListCard)
    /// in favour of a single readable surface.
    private func whatToBlockCard() -> some View {
        Section(header: HStack(spacing: 8) {
            Image(systemName: "square.and.pencil")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "ما الذي تريد حجبه؟" : "What to block")
                .font(.nnCardTitle)
        }) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: NNSpacing.md) {
                if let suggestion = onboardingSuggestionText() {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "sparkles")
                            .foregroundColor(AppColors.accent)
                            .font(.body)
                        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 4) {
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
                    .padding(12)
                    .background(AppColors.infoBg)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }

                Button(action: { openEditor() }) {
                    HStack(spacing: 8) {
                        Image(systemName: "plus.circle.fill")
                        Text(draft.websites.isEmpty && draft.apps.isEmpty && draft.categories.isEmpty
                             ? (lang.isArabicEffective ? "أضف عناصر الحجب" : "Add items to block")
                             : (lang.isArabicEffective ? "تعديل العناصر" : "Edit items"))
                    }
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(AppColors.accent)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
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
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).stroke(AppColors.uiBorder, lineWidth: 0.5))
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
                HStack(spacing: 8) {
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
                .padding(.vertical, 4)
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
        HStack(spacing: 4) {
            Image(systemName: icon).font(.caption2)
            Text("\(count)").font(.caption.weight(.semibold)).monospacedDigit()
            Text(label).font(.caption)
        }
        .foregroundColor(AppColors.accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(AppColors.infoBg)
        .clipShape(Capsule())
    }

    private func nameCard() -> some View {
        Section(header: Text(lang.isArabicEffective ? "اسم القائمة" : "List Name")) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                TextField(lang.isArabicEffective ? "مثال: وقت التركيز" : "e.g., Focus Time", text: $name)
                    .textInputAutocapitalization(.words)
                    .disableAutocorrection(true)
                    .padding(12)
                    .background(AppColors.uiSurface)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(AppColors.uiBorder, lineWidth: 0.5))
                if !isNameValid, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(lang.isArabicEffective ? "الاسم قصير جداً" : "Name is too short")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
    }
            }
            .padding(20)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
        }
        .listRowBackground(Color.clear)
    }

    // MARK: - Cards (unchanged)
    private func timeToBlockCard() -> some View {
        Section(header: HStack(spacing: 8) {
            Image(systemName: "clock")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "وقت الحجب" : "Time to block")
                .font(.nnCardTitle)
        }) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                Picker("Time", selection: $blockType) {
                    Text(lang.isArabicEffective ? "فوري" : "Now").tag("now")
                    Text(lang.isArabicEffective ? "مجدول" : "Scheduled").tag("scheduled")
                    Text(lang.isArabicEffective ? "حد يومي" : "Daily Limit").tag("timeLimit")
                    Text(lang.isArabicEffective ? "دائم ♾️" : "Forever ♾️").tag("forever")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 420, alignment: .center)
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
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(AppColors.alertRed.opacity(0.25), lineWidth: 0.5))
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
            .padding(20)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
        }
        .listRowBackground(Color.clear)
    }

    private func durationCard() -> some View {
        Section(header: HStack(spacing: 8) {
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
            .padding(20)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
        }
        .listRowBackground(Color.clear)
    }

    /// Single column of the duration picker (label + compact wheel).
    /// Two overloads: contiguous Int range OR custom values array (used for
    /// the minutes column which steps by 5).
    @ViewBuilder
    private func durationWheelColumn(label: String, binding: Binding<Int>, range: ClosedRange<Int>) -> some View {
        VStack(alignment: .center, spacing: 4) {
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
        VStack(alignment: .center, spacing: 4) {
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
        Section(header: HStack(spacing: 8) {
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
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
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
            .padding(20)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
        }
        .listRowBackground(Color.clear)
    }

    private func protectionCard() -> some View {
        Section(header: HStack(spacing: 8) {
            Image(systemName: "shield.checkered")
                .font(.nnCardBody)
                .foregroundColor(AppColors.accent)
            Text(lang.isArabicEffective ? "الحماية" : "Protection")
                .font(.nnCardTitle)
        }) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                Picker("Protection", selection: $protection) {
                    Text(lang.isArabicEffective ? "بدون حماية" : "No Protection").tag("noProtection")
                    Text(lang.isArabicEffective ? "الوضع الصارم" : "Hard Mode").tag("hard")
                }
                .pickerStyle(.segmented)

                VStack(alignment: .leading, spacing: 4) {
                    Text(lang.isArabicEffective ? "بدون حماية: تعديل/حذف في أي وقت." : "No Protection: Edit/Delete anytime.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                    Text(lang.isArabicEffective ? "الوضع الصارم: صعب الإيقاف أثناء المدة." : "Hard Mode: Hard to stop during duration.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                }
                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                    }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            .padding(20)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
        }
        .listRowBackground(Color.clear)
    }

    /// Partner step — appears only when Hard Mode is selected. Designed per
    /// `docs/PARTNER_FEATURE_DESIGN_AR.md` lines 62-92 (Day 2 of the original
    /// rollout, finally landing in v1.3.0). Three choices:
    ///   1. None (default) — saves a Hard Mode list without a partner;
    ///      triggers a one-time post-save nudge.
    ///   2. Existing partner — appends this list to the partnership's
    ///      `associatedListIDs` via `CloudKitPartnerStore.attachPartnership`.
    ///   3. New invitation — opens `PartnerInviteView` for the CKShare flow.
    @ViewBuilder
    private func partnerCard() -> some View {
        if protection == "hard" {
            Section(header: HStack(spacing: 8) {
                Image(systemName: "person.2.fill")
                    .font(.nnCardBody)
                    .foregroundColor(AppColors.accent)
                Text(lang.isArabicEffective ? "شريك التعافي" : "Recovery Partner")
                    .font(.nnCardTitle)
            }) {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                    Text(lang.isArabicEffective
                         ? "يستلم شريكك إشعاراً عند محاولة كسر الحجب. حساب أفضل، التزام أقوى."
                         : "Your partner is notified when you try to bypass the block. Better accountability, stronger commitment.")
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

                    // Option 1 — None (default)
                    partnerOptionRow(
                        title: lang.isArabicEffective ? "بدون شريك" : "No partner",
                        subtitle: lang.isArabicEffective ? "يمكنك إضافته لاحقاً من تفاصيل القائمة" : "You can add one later from the list details",
                        isSelected: pendingPartnerID == nil && !pendingNewInvite,
                        action: {
                            pendingPartnerID = nil
                            pendingNewInvite = false
                        }
                    )

                    // Option 2 — Pick an existing partnership (only if any exist)
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

                    // Option 3 — Mark intent to send new invite. The actual
                    // CKShare creation defers until the list is saved (we need
                    // the new list's UUID to associate with the partnership).
                    partnerOptionRow(
                        title: lang.isArabicEffective ? "أرسل دعوة لشريك جديد" : "Send invitation to a new partner",
                        subtitle: lang.isArabicEffective ? "ينشأ رابط الدعوة بعد حفظ القائمة" : "The invite link is created after saving",
                        isSelected: pendingNewInvite,
                        action: {
                            pendingNewInvite = true
                            pendingPartnerID = nil
                        }
                    )
                }
                .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                .padding(20)
                .background(AppColors.uiSurface)
                .cornerRadius(20)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
            }
            .listRowBackground(Color.clear)
        }
    }

    /// Single tappable row inside `partnerCard`. Visual: title + subtitle + a
    /// checkmark when selected. Used for "No partner" + each existing partner.
    @ViewBuilder
    private func partnerOptionRow(title: String, subtitle: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
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
            .frame(minHeight: 44)
            .background(isSelected ? AppColors.infoBg : AppColors.uiBackground)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? AppColors.accent : AppColors.uiBorder, lineWidth: isSelected ? 1 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    private func breaksCard() -> some View {
        Section(header: HStack(spacing: 8) {
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
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 6) {
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
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 6) {
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
            .padding(20)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
        }
        .listRowBackground(Color.clear)
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
        // Forever skips the duration step but still goes through a hard confirm dialog before save.
        if blockType == "forever" {
            pendingBaseName = name.trimmingCharacters(in: .whitespacesAndNewlines)
            pendingSeconds = 0
            showForeverConfirmAlert = true
            return
        }
        // Time-Limit stores the daily quota in durationSeconds; skip the confirm sheet
        // (its duration display assumes a contiguous block, not a daily quota).
        if blockType == "timeLimit" {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            pendingBaseName = trimmed
            pendingSeconds = Int64(timeLimitMinutes * 60)
            if protection == "hard" {
                showHardConfirmAlert = true
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
            break
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

        // Recovery Partner wiring — applies only for Hard Mode lists (Phase 2):
        //   • Picked an existing partner → attach this list to that partnership.
        //   • Picked "send new invite" → create CKShare for this list, then
        //     present PartnerInviteView so the user can send via iMessage/etc.
        //   • Picked None → show one-time nudge after the toast.
        // Capture list metadata before we leave this scope (entity is owned by
        // the managed object context; passing the raw values is safer).
        let savedID = entity.id
        let savedName = entity.name
        if protection == "hard" {
            if let chosenPartnerID = pendingPartnerID {
                Task {
                    await partnerStore.attachPartnership(chosenPartnerID, toList: savedID)
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
            } else if pendingNewInvite {
                // Defer dismissal — the share flow needs to present first.
                Task { await beginNewInviteFlow(listID: savedID, listName: savedName) }
            } else {
                // None selected → store details for the nudge and trigger it.
                savedListIDForNudge = savedID
                savedListNameForNudge = savedName
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                    showPostSavePartnerNudge = true
                }
            }
        } else {
            // Non-Hard list — no partner consideration.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
        }
    }

    /// Creates a CKShare for the just-saved list and presents PartnerInviteView.
    /// Mirrors HomeView.invitePartner() but tailored to the post-save flow:
    /// the parent CreateListSheet stays open until the share controller fires
    /// `onCompletion`, after which both close together.
    private func beginNewInviteFlow(listID: UUID, listName: String) async {
        do {
            let (share, _) = try await partnerStore.createPartnership(
                ownerDisplayName: listName,
                associatedListID: listID
            )
            await MainActor.run {
                pendingShare = share
                showShareSheet = true
            }
        } catch {
            await MainActor.run {
                partnerCreationError = error.localizedDescription
                // Even on failure, the list was saved — dismiss after a beat
                // so the user isn't trapped staring at a stuck sheet.
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { dismiss() }
            }
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
            let total = days * 86400 + hours * 3600 + minutes * 60
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.black.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                        .padding(.bottom, 24)
                }
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isPresented.wrappedValue)
            }
        }
    }
} 