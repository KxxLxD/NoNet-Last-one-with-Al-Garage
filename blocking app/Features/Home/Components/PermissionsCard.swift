import SwiftUI

/// Collapsible card shown only while Screen Time or notification access is missing.
struct PermissionsCard: View {
    @Environment(ScreenTimeAuthorization.self) private var screenTime
    @Environment(NotificationService.self) private var notifications
    @Environment(ListsModel.self) private var lists

    @State private var isExpanded = true

    private var missingCount: Int {
        (screenTime.isApproved ? 0 : 1) + (notifications.isAuthorized ? 0 : 1)
    }

    var body: some View {
        if missingCount > 0 {
            VStack(spacing: 0) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
                } label: {
                    HStack(spacing: 12) {
                        Text("Permissions required")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColors.text)
                        Spacer()
                        Badge(systemImage: nil, text: "Required (\(missingCount))", tint: AppColors.scheduled)
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    .padding(16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityHint(isExpanded ? "Collapse" : "Expand")

                if isExpanded {
                    Divider()
                    row(
                        title: "Screen Time",
                        detail: "Required to block apps and websites.",
                        systemImage: "lock.iphone",
                        isGranted: screenTime.isApproved,
                        action: "Grant"
                    ) {
                        Task {
                            if await screenTime.request() { lists.refreshSystemState() }
                        }
                    }
                    Divider().padding(.horizontal, 16)
                    row(
                        title: "Notifications",
                        detail: "Get told when a session or break ends.",
                        systemImage: "bell",
                        isGranted: notifications.isAuthorized,
                        action: "Enable"
                    ) {
                        Task {
                            await notifications.request()
                            lists.refreshSystemState()
                        }
                    }
                }
            }
            .background(AppColors.surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(AppColors.border, lineWidth: 0.5))
        }
    }

    private func row(
        title: LocalizedStringKey,
        detail: LocalizedStringKey,
        systemImage: String,
        isGranted: Bool,
        action: LocalizedStringKey,
        perform: @escaping () -> Void
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(AppColors.primary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(AppColors.text)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
            }
            Spacer()
            if isGranted {
                Text("Granted")
                    .font(.footnote)
                    .foregroundStyle(AppColors.textSecondary)
            } else {
                Button(action: perform) {
                    Text(action).padding(.horizontal, 12)
                }
                .buttonStyle(PrimaryButtonStyle(height: 32))
                .fixedSize()
            }
        }
        .padding(16)
    }
}
