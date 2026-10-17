import SwiftUI

/// Builds the weekly slots for a scheduled list.
struct ScheduleEditorSheet: View {
    var initialSlots: [ScheduleSlot]
    var onSave: ([ScheduleSlot]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var working: [ScheduleSlot] = []
    @State private var selectedDays: Set<Int> = []
    @State private var from = ScheduleEditorSheet.date(hour: 9)
    @State private var to = ScheduleEditorSheet.date(hour: 17)

    private var fromMinutes: Int { Self.minutes(of: from) }
    private var toMinutes: Int { Self.minutes(of: to) }
    private var previewSlot: ScheduleSlot { ScheduleSlot(day: 0, fromMinutes: fromMinutes, toMinutes: toMinutes) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Days") {
                    ForEach(0..<7, id: \.self) { day in
                        Toggle(Formatters.weekday(day), isOn: Binding {
                            selectedDays.contains(day)
                        } set: { isOn in
                            if isOn { selectedDays.insert(day) } else { selectedDays.remove(day) }
                        })
                    }
                }

                Section {
                    DatePicker("From", selection: $from, displayedComponents: .hourAndMinute)
                    DatePicker("To", selection: $to, displayedComponents: .hourAndMinute)
                } footer: {
                    Text("Total: \(Formatters.duration(minutes: previewSlot.durationMinutes))")
                }

                Section {
                    Button {
                        addSlots()
                    } label: {
                        Label("Add Slot", systemImage: "plus.circle")
                    }
                    .disabled(selectedDays.isEmpty)
                }

                Section("Slots") {
                    if working.isEmpty {
                        Text("No slots").foregroundStyle(.secondary)
                    } else {
                        ForEach(working) { slot in
                            HStack {
                                Text(Formatters.weekday(slot.day))
                                Spacer()
                                Text(Formatters.timeRange(from: slot.fromMinutes, to: slot.toMinutes))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .onDelete { working.remove(atOffsets: $0) }
                    }
                }
            }
            .navigationTitle("Scheduling")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        // Days picked but "Add Slot" not tapped still count: never drop a choice silently.
                        if !selectedDays.isEmpty { addSlots() }
                        onSave(working)
                        dismiss()
                    }
                    .disabled(working.isEmpty && selectedDays.isEmpty)
                }
            }
            .onAppear { working = initialSlots }
        }
    }

    private func addSlots() {
        for day in selectedDays.sorted() {
            let slot = ScheduleSlot(day: day, fromMinutes: fromMinutes, toMinutes: toMinutes)
            let isDuplicate = working.contains { $0.day == day && $0.fromMinutes == slot.fromMinutes && $0.toMinutes == slot.toMinutes }
            if !isDuplicate { working.append(slot) }
        }
        working.sort { ($0.day, $0.fromMinutes) < ($1.day, $1.fromMinutes) }
        selectedDays.removeAll()
    }

    private static func date(hour: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: 0, second: 0, of: .now) ?? .now
    }

    private static func minutes(of date: Date) -> Int {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
        return (parts.hour ?? 0) * 60 + (parts.minute ?? 0)
    }
}
