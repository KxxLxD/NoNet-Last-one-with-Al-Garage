import SwiftUI
import CoreData

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
        return s6
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
            .alert(lang.isArabicEffective ? "ترقية لفتح كامل طاقتك" : "Upgrade to unlock your full potential", isPresented: $showLimitAlert) {
                Button(lang.isArabicEffective ? "لاحقًا" : "Later", role: .cancel) {}
                Button("Upgrade") {}
            } message: {
                Text(lang.isArabicEffective ? "أنت قريب من انطلاقة إنتاجية أقوى! مع الترقية، حرر كامل طاقتك وأنشئ قوائم غير محدودة، ركّز أكثر وغيّر عاداتك الرقمية للأفضل." : "You’re close to a stronger productivity breakthrough! Upgrade to unlock unlimited lists, focus deeper, and transform your digital habits.")
            }
            .alert(lang.isArabicEffective ? "تحقق من الإدخالات" : "Check inputs", isPresented: $showValidationAlert) {
                Button(lang.isArabicEffective ? "حسنًا" : "OK", role: .cancel) {}
            } message: {
                Text(validationMessage)
            }
            .alert(lang.isArabicEffective ? "تأكيد الوضع الصارم" : "Confirm Hard Mode", isPresented: $showHardConfirmAlert) {
                Button(lang.isArabicEffective ? "تأكيد" : "Confirm") { save(totalSeconds: pendingSeconds, baseName: pendingBaseName) }
                Button(lang.isArabicEffective ? "رجوع" : "Back", role: .cancel) {}
            } message: {
                Text(lang.isArabicEffective ? "سيتم إنشاء قائمة بوضع صارم (Hard Mode). لن تتمكن من تعديلها أو حذفها خلال المدة." : "This list will be created in Hard Mode. You won’t be able to edit or delete it during the duration.")
            }
            .alert(lang.isArabicEffective ? "حجب دائم — هل أنت متأكد؟" : "Permanent Block — are you sure?", isPresented: $showForeverFirstAlert) {
                Button(lang.isArabicEffective ? "متابعة" : "Continue") { /* keep blockType = forever */ }
                Button(lang.isArabicEffective ? "إلغاء" : "Cancel", role: .cancel) { blockType = "now" }
            } message: {
                Text(lang.isArabicEffective
                     ? "الحجب الدائم يبقى فعالاً حتى تحذف القائمة. إذا اخترت الوضع الصارم أيضاً، لن تتمكن من حذفها إطلاقاً."
                     : "A permanent block stays active until you delete the list. With Hard Mode you cannot delete it at all.")
            }
            .alert(lang.isArabicEffective ? "تأكيد نهائي" : "Final Confirmation", isPresented: $showForeverConfirmAlert) {
                Button(lang.isArabicEffective ? "أؤكد، أنشئ الحجب" : "I confirm — create block", role: .destructive) {
                    if protection == "hard" {
                        showForeverConfirmAlert = false
                        showHardConfirmAlert = true
                    } else {
                        save(totalSeconds: 0, baseName: pendingBaseName)
                    }
                }
                Button(lang.isArabicEffective ? "تراجع" : "Back", role: .cancel) {}
            } message: {
                Text(lang.isArabicEffective
                     ? "هذه آخر فرصة. الحجب الدائم يعني أن التطبيقات والمواقع المختارة لن تعمل أبداً حتى تحذف هذه القائمة."
                     : "This is your last chance. A permanent block means the selected apps/sites will be blocked forever until you delete this list.")
            }
            .alert(
                lang.isArabicEffective ? "تعذّر إنشاء القائمة" : "Couldn't create list",
                isPresented: Binding(get: { saveErrorMessage != nil }, set: { if !$0 { saveErrorMessage = nil } })
            ) {
                Button(lang.isArabicEffective ? "حسناً" : "OK", role: .cancel) { saveErrorMessage = nil }
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
                        .background(AppColors.accentDark)
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

    private var contentView: some View {
        List {
            nameCard()

            // Add items Card
            Section(header: HStack(spacing: 8) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.accentDark)
                Text(lang.isArabicEffective ? "إنشاء قائمة الحجب" : "Create blocking list")
                    .font(.system(size: 20, weight: .semibold))
            }) {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 16) {
                    if let suggestion = onboardingSuggestionText() {
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "sparkles")
                                .foregroundColor(AppColors.accentDark)
                                .font(.system(size: 16, weight: .regular))
                            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 4) {
                                Text(lang.isArabicEffective ? "اقتراحات بناءً على تفضيلاتك" : "Based on your preferences")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundColor(AppColors.accentDark)
                                Text(suggestion)
                                    .font(.footnote)
                                    .foregroundColor(AppColors.textSecondary)
                                    .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                            }
                            Spacer(minLength: 0)
                        }
                        .padding(12)
                        .background(AppColors.infoBg)
                        .cornerRadius(10)
                    }

                    Button(action: { openEditor() }) {
                        Text(lang.isArabicEffective ? "أضف عناصر الحجب" : "Add items to block")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(AppColors.accentDark)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                    }
                    .buttonStyle(.plain)

                    websitesListCard()
                    appsListCard()
                    categoriesListCard()

        if draft.websites.isEmpty && draft.apps.isEmpty && draft.categories.isEmpty {
                        Text(lang.isArabicEffective ? "أضف عنصرًا واحدًا على الأقل" : "Add at least one item")
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

            timeToBlockCard()

            if blockType == "now" { durationCard() }
            if blockType == "timeLimit" { timeLimitCard() }

            protectionCard()
            breaksCard()
        }
        .scrollContentBackground(.hidden)
        .background(AppColors.uiBackground)
        .navigationTitle(lang.isArabicEffective ? "إنشاء قائمة" : "Create List")
        .listStyle(.insetGrouped)
        .padding(.bottom, 120)
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
                    Text(lang.isArabicEffective ? "الاسم قصير جدًا" : "Name is too short")
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
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(AppColors.accentDark)
            Text(lang.isArabicEffective ? "وقت الحجب" : "Time to block")
                .font(.system(size: 20, weight: .semibold))
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

                if blockType == "forever" {
                    VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 8) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(AppColors.alertRed)
                            Text(lang.isArabicEffective ? "حجب دائم — لا نهاية" : "Permanent block — no end")
                                .font(.subheadline.weight(.semibold))
                                .foregroundColor(AppColors.alertRed)
                        }
                        Text(lang.isArabicEffective
                             ? "يبقى الحجب فعالاً إلى أن تحذف القائمة. ينصح به للمحتوى الإباحي وتطبيقات القمار."
                             : "Block stays active until you delete the list. Recommended for adult content and gambling apps.")
                            .font(.footnote)
                            .foregroundColor(AppColors.textSecondary)
                            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        if protection == "hard" {
                            Text(lang.isArabicEffective
                                 ? "⚠️ مع الوضع الصارم لا يمكن حذف القائمة إلا عبر الدعم."
                                 : "⚠️ With Hard Mode you cannot delete this list except via support.")
                                .font(.footnote.weight(.semibold))
                                .foregroundColor(AppColors.alertRed)
                                .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
                        }
                    }
                    .padding(12)
                    .background(AppColors.alertRed.opacity(0.08))
                    .cornerRadius(12)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
                }

                if !isPremium {
                    Text(lang.isArabicEffective ? "الجدولة ضمن الترقية." : "Scheduling is in Upgrade.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Button(action: { showUpgradeSheet = true }) {
                        Text(lang.isArabicEffective ? "ترقية / تجربة 7 أيام" : "Upgrade / 7‑day Trial")
                }
                    .buttonStyle(.plain)
                    .foregroundColor(AppColors.primaryBlue)
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
                            .foregroundColor(.secondary)
                } else {
                        ForEach(slots) { s in
                        Group {
                                if lang.isArabicEffective {
                                    HStack { Text(timeRangeLabel(s)).foregroundColor(.secondary); Spacer(); Text(dayName(s.day)) }
                            } else {
                                    HStack { Text(dayName(s.day)); Spacer(); Text(timeRangeLabel(s)).foregroundColor(.secondary) }
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
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(AppColors.accentDark)
            Text(lang.isArabicEffective ? "المدة" : "Duration")
                .font(.system(size: 20, weight: .semibold))
        }) {
            VStack(alignment: .center, spacing: 12) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .center, spacing: 8) {
                        Text(lang.isArabicEffective ? "أيام" : "Days").font(.subheadline)
                        Picker("Days", selection: $days) { ForEach(0...360, id: \.self) { Text("\($0)") } }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 140)
                    }
                    VStack(alignment: .center, spacing: 8) {
                        Text(lang.isArabicEffective ? "ساعات" : "Hours").font(.subheadline)
                        Picker("Hours", selection: $hours) { ForEach(0...23, id: \.self) { Text("\($0)") } }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 140)
                    }
                    VStack(alignment: .center, spacing: 8) {
                        Text(lang.isArabicEffective ? "دقائق" : "Minutes").font(.subheadline)
                        Picker("Minutes", selection: $minutes) { ForEach(minuteOptions, id: \.self) { Text("\($0)") } }
                            .pickerStyle(.wheel)
                            .frame(width: 100, height: 140)
                    }
                }
                Text(lang.isArabicEffective ? "الحد الأدنى 5 دقائق." : "Minimum duration is 5 minutes.")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                if blockType == "now" && !isDurationValid {
                    Text(lang.isArabicEffective ? "اختر مدة لا تقل عن 5 دقائق" : "Select at least 5 minutes")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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

    private func timeLimitCard() -> some View {
        Section(header: HStack(spacing: 8) {
            Image(systemName: "hourglass.bottomhalf.filled")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(AppColors.accentDark)
            Text(lang.isArabicEffective ? "الحد اليومي" : "Daily Limit")
                .font(.system(size: 20, weight: .semibold))
        },
        footer: Text(lang.isArabicEffective
                     ? "يبدأ كل يوم بدون حجب. بعد استخدام التطبيقات/المواقع للمدة المحددة، يتفعّل الحجب حتى منتصف الليل."
                     : "Each day starts with no block. After using the selected apps/sites for this many minutes, the block kicks in until midnight.")
            .font(.footnote)
            .foregroundColor(.secondary)
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
                    .foregroundColor(.secondary)
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
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(AppColors.accentDark)
            Text(lang.isArabicEffective ? "الحماية" : "Protection")
                .font(.system(size: 20, weight: .semibold))
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
                        .foregroundColor(.secondary)
                    Text(lang.isArabicEffective ? "الوضع الصارم: صعب الإيقاف أثناء المدة." : "Hard Mode: Hard to stop during duration.")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    if protection == "hard" {
                        Text(lang.isArabicEffective
                             ? "💡 بعد الإنشاء يمكنك دعوة شريك تعافي من تفاصيل القائمة."
                             : "💡 After creating, invite a recovery partner from the list details.")
                            .font(.footnote)
                            .foregroundColor(AppColors.accentDark)
                            .padding(.top, 4)
                    }
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

    private func breaksCard() -> some View {
        Section(header: HStack(spacing: 8) {
            Image(systemName: "cup.and.saucer")
                .font(.system(size: 20, weight: .regular))
                .foregroundColor(AppColors.accentDark)
            Text(lang.isArabicEffective ? "الاستراحات المسموحة" : "Allows Breaks")
                .font(.system(size: 20, weight: .semibold))
        },
        footer: Text(lang.isArabicEffective ? "حدّد عدد الاستراحات خلال 24 ساعة ومدة كل استراحة." : "Choose number of breaks across 24h and the duration of each.")
            .font(.footnote)
            .foregroundColor(.secondary)
            .multilineTextAlignment(lang.isArabicEffective ? .trailing : .leading)
        ) {
            VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 12) {
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 6) {
                    Text(lang.isArabicEffective ? "العدد" : "Count")
                        .font(.footnote)
                        .foregroundColor(.secondary)
                    Picker("Breaks", selection: $breaksCount) { ForEach(0...5, id: \.self) { Text("\($0)") } }
                        .pickerStyle(.wheel)
                        .frame(height: 120)
                }
                VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 6) {
                    Text(lang.isArabicEffective ? "مدة كل استراحة" : "Duration of each break")
                        .font(.footnote)
                        .foregroundColor(.secondary)
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
                                                .foregroundColor(.secondary)
                                        }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            .padding(20)
            .background(AppColors.uiSurface)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.uiBorder, lineWidth: 0.5))
        }
        .listRowBackground(Color.clear)
    }
    
    private func websitesListCard() -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "globe")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.accentDark)
                Text(lang.isArabicEffective ? "مواقع الويب" : "Websites")
                    .font(.subheadline.weight(.semibold))
                Text("(\(draft.websites.count))")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

            if draft.websites.isEmpty {
                Text(lang.isArabicEffective ? "لا توجد مواقع بعد" : "No websites yet")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            } else {
                ForEach(Array(draft.websites.enumerated()), id: \.element.id) { idx, item in
                    VStack(spacing: 0) {
                        if idx > 0 { SoftDivider(width: 280, opacity: 0.7) }
                        HStack {
                            if lang.isArabicEffective {
                                        Spacer()
                                Text(item.displayName ?? item.value)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                    } else {
                                Text(item.displayName ?? item.value)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                        Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                        .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
    }

    private func appsListCard() -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "app.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.accentDark)
                Text(lang.isArabicEffective ? "التطبيقات" : "Apps")
                    .font(.subheadline.weight(.semibold))
                Text("(\(draft.apps.count))")
                                                .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                                        }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

            if draft.apps.isEmpty {
                Text(lang.isArabicEffective ? "لا توجد تطبيقات بعد" : "No apps yet")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            } else {
                ForEach(Array(draft.apps.enumerated()), id: \.element.id) { idx, item in
                    VStack(spacing: 0) {
                        if idx > 0 { SoftDivider(width: 280, opacity: 0.7) }
                        HStack {
                            if lang.isArabicEffective {
                                Spacer()
                                Text(item.displayName ?? item.value)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                            } else {
                                Text(item.displayName ?? item.value)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
                            }
                        }
                        .padding(.vertical, 4)
                        .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
    }

    private func categoriesListCard() -> some View {
        VStack(alignment: lang.isArabicEffective ? .trailing : .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 20, weight: .regular))
                    .foregroundColor(AppColors.accentDark)
                Text(lang.isArabicEffective ? "الفئات" : "Categories")
                    .font(.subheadline.weight(.semibold))
                Text("(\(draft.categories.count))")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)

            if draft.categories.isEmpty {
                Text(lang.isArabicEffective ? "لا توجد فئات بعد" : "No categories yet")
                    .font(.footnote)
                    .foregroundColor(AppColors.textSecondary)
                    .frame(maxWidth: .infinity, alignment: lang.isArabicEffective ? .trailing : .leading)
            } else {
                ForEach(Array(draft.categories.enumerated()), id: \.element.id) { idx, item in
                    VStack(spacing: 0) {
                        if idx > 0 { SoftDivider(width: 280, opacity: 0.7) }
                        HStack {
                            if lang.isArabicEffective {
                                Spacer()
                                Text(item.displayName ?? item.value)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
        } else {
                                Text(item.displayName ?? item.value)
                                    .lineLimit(1)
                                    .truncationMode(.tail)
                                Spacer()
        }
    }
                        .padding(.vertical, 4)
                        .foregroundColor(AppColors.textPrimary)
                    }
                }
            }
        }
    }

    // Logic helpers
    private var itemsCountSummary: String {
        draft.websites.count + draft.apps.count + draft.categories.count > 0 ? "ok" : "empty"
    }
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
            saveErrorMessage = lang.isArabicEffective
                ? "حدث خطأ أثناء الحفظ: \(error.localizedDescription)"
                : "An error occurred while saving: \(error.localizedDescription)"
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
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) { dismiss() }
    }
    private func currentListsCount() -> Int {
        let req: NSFetchRequest<ListEntity> = ListEntity.fetchRequest()
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

private struct SoftDivider: View {
    let width: CGFloat
    let opacity: Double
    var body: some View {
        HStack {
            Spacer()
            Rectangle()
                .fill(AppColors.uiBorder.opacity(opacity))
                .frame(width: width, height: 1)
            Spacer()
        }
        .padding(.vertical, 8)
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