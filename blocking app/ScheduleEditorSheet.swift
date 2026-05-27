import SwiftUI

struct ScheduleSlotModel: Codable, Identifiable { let id: UUID; var day: Int; var fromMinutes: Int; var toMinutes: Int }

struct ScheduleEditorSheet: View {
    let isArabic: Bool
    var initialSlots: [ScheduleSlotModel]
    var onSave: ([ScheduleSlotModel]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var working: [ScheduleSlotModel] = []

    @State private var selectedDays: Set<Int> = []
    @State private var fromHour: Int = 9
    @State private var fromMinute: Int = 0
    @State private var toHour: Int = 17
    @State private var toMinute: Int = 0

    private var minuteOptions: [Int] { Array(stride(from: 0, through: 55, by: 5)) }
    private var totalDurationLabel: String {
        let from = fromHour * 60 + fromMinute
        let to = toHour * 60 + toMinute
        let minutes: Int = {
            if to == from { return 24 * 60 }
            if to > from { return to - from }
            return (24 * 60 - from) + to
        }()
        let h = minutes / 60
        let m = minutes % 60
        if isArabic { return "المجموع: \(h) ساعة \(m) دقيقة" }
        return "Total: \(h)h \(m)m"
    }

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(isArabic ? "الأيام" : "Days")) {
                    ForEach(0...6, id: \.self) { d in
                        Toggle(isOn: Binding(get: { selectedDays.contains(d) }, set: { v in
                            if v { selectedDays.insert(d) } else { selectedDays.remove(d) }
                        })) {
                            Text(dayName(d))
                        }
                    }
                }
                Section {
                    HStack(alignment: .top, spacing: NNSpacing.md) {
                        VStack(alignment: .leading, spacing: NNSpacing.xs) {
                            Text(isArabic ? "من" : "From").font(.footnote).foregroundColor(AppColors.textSecondary)
                            HStack {
                                Picker("h", selection: $fromHour) { ForEach(0...23, id: \.self) { Text("\($0)") } }
                                    .frame(width: 90, height: 120)
                                    .pickerStyle(.wheel)
                                Picker("m", selection: $fromMinute) { ForEach(minuteOptions, id: \.self) { Text("\($0)") } }
                                    .frame(width: 90, height: 120)
                                    .pickerStyle(.wheel)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                        VStack(alignment: .leading, spacing: NNSpacing.xs) {
                            Text(isArabic ? "إلى" : "To").font(.footnote).foregroundColor(AppColors.textSecondary)
                            HStack {
                                Picker("h", selection: $toHour) { ForEach(0...23, id: \.self) { Text("\($0)") } }
                                    .frame(width: 90, height: 120)
                                    .pickerStyle(.wheel)
                                Picker("m", selection: $toMinute) { ForEach(minuteOptions, id: \.self) { Text("\($0)") } }
                                    .frame(width: 90, height: 120)
                                    .pickerStyle(.wheel)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                    }
                    .padding(.vertical, NNSpacing.xxs)
                    Text(totalDurationLabel)
                        .font(.footnote)
                        .foregroundColor(AppColors.textSecondary)
                        .padding(.top, NNSpacing.xxs + 2)
                        .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                }
                Button(action: addSlotsForSelectedDays) {
                    Label(isArabic ? "إضافة فترة" : "Add Slot", systemImage: "plus.circle")
                }
                .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                .disabled(selectedDays.isEmpty)
                if selectedDays.isEmpty {
                    // Without this hint the disabled Add button looks like a
                    // bug — users couldn't tell they needed to pick days first.
                    Text(isArabic ? "اختر يوماً واحداً على الأقل قبل الإضافة" : "Pick at least one day before adding")
                        .font(.caption)
                        .foregroundColor(AppColors.warningFg)
                        .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                }
                if working.isEmpty {
                    Text(isArabic ? "لا توجد فترات" : "No slots").foregroundColor(AppColors.textSecondary)
                        .frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                } else {
                    ForEach(working) { s in
                        Group {
                            if isArabic {
                                HStack { Text(timeRangeLabel(s)).foregroundColor(AppColors.textSecondary); Spacer(); Text(dayName(s.day)) }
                            } else {
                                HStack { Text(dayName(s.day)); Spacer(); Text(timeRangeLabel(s)).foregroundColor(AppColors.textSecondary) }
                            }
                        }
                        // Swipe-to-delete with an explicit destructive
                        // action button instead of the bare onDelete handler.
                        // Adding a slot is multi-step (day + from + to + add),
                        // so deletion deserves the same visible affordance —
                        // a single-finger slide can't undo someone's setup
                        // by mistake.
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                if let idx = working.firstIndex(where: { $0.id == s.id }) {
                                    working.remove(at: idx)
                                }
                            } label: {
                                Label(isArabic ? "حذف" : "Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(isArabic ? "الجدولة" : "Scheduling")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(isArabic ? "إلغاء" : "Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button(isArabic ? "تم" : "Done") { onSave(working); dismiss() } }
            }
            .onAppear { working = initialSlots }
        }
    }

    private func addSlotsForSelectedDays() {
        let from = fromHour * 60 + fromMinute
        let to = toHour * 60 + toMinute
        for d in selectedDays.sorted() { working.append(.init(id: UUID(), day: d, fromMinutes: from, toMinutes: to)) }
    }

    private func dayName(_ d: Int) -> String {
        let ar = ["الأحد","الاثنين","الثلاثاء","الأربعاء","الخميس","الجمعة","السبت"]
        let en = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        return isArabic ? ar[d] : en[d]
    }
    private func timeRangeLabel(_ s: ScheduleSlotModel) -> String {
        func fmt(_ m: Int) -> String { String(format: "%02d:%02d", m/60, m%60) }
        return "\(fmt(s.fromMinutes)) - \(fmt(s.toMinutes))"
    }
} 