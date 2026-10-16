import SwiftUI

/// Block Forever on Home: a card with "Turn On" before, a small badge after.
struct ForeverCard: View {
    @Environment(ForeverStore.self) private var forever
    @State private var showSetup = false

    var body: some View {
        Group {
            if forever.isActive() {
                NavigationLink(value: HomeRoute.forever) {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.shield.fill")
                            .foregroundStyle(AppColors.active)
                        Text(badgeText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(AppColors.surface, in: Capsule())
                    .overlay(Capsule().stroke(AppColors.border, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    Text("“Tell the believing men to lower their gaze.”")
                        .font(.headline)
                        .foregroundStyle(AppColors.primary)
                    Text("Block Forever: porn, gambling and dating — blocked for good. Free forever.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                    Button("Turn On") { showSetup = true }
                        .buttonStyle(PrimaryButtonStyle(height: 44))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .card()
            }
        }
        .sheet(isPresented: $showSetup) {
            ForeverSetupView()
        }
    }

    private var badgeText: String {
        if let days = forever.daysUntilUnlock() {
            return String(localized: "Block Forever · unlocks in \(days) days", locale: .app)
        }
        return String(localized: "Block Forever is on")
    }
}
