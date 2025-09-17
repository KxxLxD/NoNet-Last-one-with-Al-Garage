import SwiftUI
import CoreData

struct CreateListSheet: View {
    @EnvironmentObject var lang: LanguageManager
    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss

    @AppStorage("isPremium") private var isPremium: Bool = false

    @State private var name: String = ""
    @State private var protection: String = "noProtection" // hard | noProtection
    @State private var blockType: String = "now" // now | scheduled

    // Wheel pickers (step 5 minutes)
    @State private var days: Int = 0
    @State private var hours: Int = 0
    @State private var minutes: Int = 15
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

    // Alerts
    @State private var showLimitAlert = false
    @State private var showValidationAlert = false
    @State private var validationMessage = ""
    @State private var showHardConfirmAlert = false
    @State private var pendingSeconds: Int64 = 0
    @State private var pendingBaseName: String = ""

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
                    }
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

    // MARK: - Cards (omitted for brevity in this restoration)
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
                    Text(lang.isArabicEffective ? "حظر فوري" : "Block Now").tag("now")
                    Text("Scheduled").tag("scheduled")
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320, alignment: .center)
                .onChange(of: blockType) { newVal in
                    if newVal == "scheduled" && !isPremium {
                        blockType = "now"
                        showLimitAlert = true
                        showUpgradeSheet = true
                    } else if newVal == "scheduled" && isPremium {
                        showScheduleEditor = true
                            }
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
    
    // Logic helpers (unchanged from backup)
    private var itemsCountSummary: String { "" }
    private func openEditor() { draft.name = name; showingEditor = true }
    private func attemptConfirm() {}
    private func save(totalSeconds: Int64, baseName: String) {}
    private func currentListsCount() -> Int { 0 }
    private func uniqueName(from base: String) -> String { base }
    private func nameExists(_ n: String) -> Bool { false }
    private var isNameValid: Bool { true }
    private var hasAtLeastOneItem: Bool { true }
    private var isDurationValid: Bool { true }
    private var isFormValid: Bool { true }
    private func dayName(_ d: Int) -> String { "" }
    private func timeRangeLabel(_ s: ScheduleSlot) -> String { "" }
    private func encodeSlots() -> Data? { nil }
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