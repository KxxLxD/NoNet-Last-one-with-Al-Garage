import AuthenticationServices
import SwiftUI

/// Optional Sign in with Apple, sign out and account deletion (App Store Guideline 5.1.1(v)).
/// Rows for the Account section of Settings.
struct AccountSection: View {
    @Environment(AccountStore.self) private var account
    @Environment(ListsModel.self) private var lists
    @AppStorage(StorageKey.onboardingCompleted) private var onboardingCompleted = true

    @State private var confirmSignOut = false
    @State private var confirmDelete = false
    @State private var errorMessage: String?

    var body: some View {
        Group {
            if account.isSignedIn {
                HStack(spacing: Spacing.m) {
                    Image(systemName: "apple.logo")
                        .font(.title3)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.displayName ?? String(localized: "Apple Account"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColors.text)
                        Text("Signed in with Apple")
                            .font(.caption)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Button("Log out") { confirmSignOut = true }
            } else {
                VStack(alignment: .leading, spacing: Spacing.m) {
                    Text("Optional. Samla works fully without an account.")
                        .font(.footnote)
                        .foregroundStyle(AppColors.textSecondary)
                    SignInWithAppleButton(.signIn) { request in
                        account.configure(request)
                    } onCompletion: { result in
                        errorMessage = account.handle(result)
                    }
                    .signInWithAppleButtonStyle(.black)
                    .frame(height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(AppColors.danger)
                    }
                }
                .padding(.vertical, Spacing.xs)
            }

            Button("Delete Account & Data", role: .destructive) { confirmDelete = true }
        }
        .alert("Log out?", isPresented: $confirmSignOut) {
            Button("Log out", role: .destructive) { account.signOut() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Your lists stay on this device.")
        }
        .alert("Delete your account?", isPresented: $confirmDelete) {
            Button("Delete", role: .destructive, action: deleteAccount)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This permanently deletes your account details and block lists from this device. Lists that are locked right now stay until they end, and Block Forever keeps its own rules. To also stop using Sign in with Apple with Samla, open Settings › Apple Account › Sign in with Apple.")
        }
    }

    private func deleteAccount() {
        lists.deleteAllUnlocked()
        account.deleteAccount()
        onboardingCompleted = false
    }
}
