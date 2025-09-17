import SwiftUI

struct ConfirmCreateSheet: View {
    let isArabic: Bool
    let name: String
    let protection: String
    let blockType: String
    let durationSeconds: Int64
    let websites: [String]
    let apps: [String]
    let categories: [String]
    let slots: [(Int, Int, Int)]

    var onBack: () -> Void
    var onConfirm: () -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section(header: Text(isArabic ? "الاسم" : "Name")) { Text(name).frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading) }
                Section(header: Text(isArabic ? "الحماية" : "Protection")) {
                    let isHard = protection == "hard"
                    Label(isHard ? "Hard Mode" : "No Protection", systemImage: isHard ? "lock.fill" : "lock.open")
                        .foregroundColor(isHard ? AppColors.alertRed : AppColors.successGreen)
                    if isHard {
                        Text(isArabic ? "سيتم تفعيل الوضع الصارم ولا يمكن التعديل أو الحذف خلال المدة." : "Hard Mode will be enabled; no edits/deletes during duration.")
                            .font(.footnote).foregroundColor(.secondary)
                            .multilineTextAlignment(isArabic ? .trailing : .leading)
                    }
                }
                Section(header: Text(isArabic ? "وقت الحجب" : "Time to block")) {
                    if blockType == "now" {
                        Text(durationLabel).frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading)
                    } else {
                        if slots.isEmpty {
                            Text(isArabic ? "لا توجد فترات" : "No slots").frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading).foregroundColor(.secondary)
                        } else {
                            ForEach(0..<slots.count, id: \.self) { idx in
                                let s = slots[idx]
                                HStack(alignment: .firstTextBaseline) {
                                    if isArabic {
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(timeRangeLabel(from: s.1, to: s.2))
                                            Text(totalDurationLabel(from: s.1, to: s.2)).font(.footnote).foregroundColor(.secondary)
                                        }
                                        Spacer(); Text(dayName(s.0))
                                    } else {
                                        Text(dayName(s.0)); Spacer()
                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text(timeRangeLabel(from: s.1, to: s.2))
                                            Text(totalDurationLabel(from: s.1, to: s.2)).font(.footnote).foregroundColor(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
                if !websites.isEmpty { Section(header: Text("Websites")) { ForEach(websites, id: \.self) { Text($0).frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading) } } }
                if !apps.isEmpty { Section(header: Text("Apps")) { ForEach(apps, id: \.self) { Text($0).frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading) } } }
                if !categories.isEmpty { Section(header: Text(isArabic ? "الفئات" : "Categories")) { ForEach(categories, id: \.self) { Text($0).frame(maxWidth: .infinity, alignment: isArabic ? .trailing : .leading) } } }
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(isArabic ? "تأكيد الإنشاء" : "Confirm Create")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button(isArabic ? "رجوع" : "Back") { onBack() } }
                ToolbarItem(placement: .confirmationAction) { Button(isArabic ? "تأكيد" : "Confirm") { onConfirm() } }
            }
        }
    }

    private var durationLabel: String {
        let total = Int(durationSeconds)
        let d = total / 86400
        let h = (total % 86400) / 3600
        let m = (total % 3600) / 60
        if isArabic { return "\(d) يوم، \(h) ساعة، \(m) دقيقة" }
        return "\(d)d \(h)h \(m)m"
    }

    private func dayName(_ d: Int) -> String {
        let ar = ["الأحد","الاثنين","الثلاثاء","الأربعاء","الخميس","الجمعة","السبت"]
        let en = ["Sunday","Monday","Tuesday","Wednesday","Thursday","Friday","Saturday"]
        return isArabic ? ar[d] : en[d]
    }
    private func timeRangeLabel(from: Int, to: Int) -> String {
        func fmt(_ m: Int) -> String { String(format: "%02d:%02d", m/60, m%60) }
        return "\(fmt(from)) - \(fmt(to))"
    }
    private func totalDurationLabel(from: Int, to: Int) -> String {
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
} 