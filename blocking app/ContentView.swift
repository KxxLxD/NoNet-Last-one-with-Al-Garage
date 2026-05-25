//
//  ContentView.swift
//  blocking app
//
//  Created by Khalid Khamid on 12/03/1447 AH.
//

import SwiftUI
import UIKit
import CloudKit

struct ContentView: View {
    @StateObject private var lang = LanguageManager.shared
    @AppStorage(AppStorageKeys.isAuthenticated) private var isAuthenticated: Bool = false
    @AppStorage(AppStorageKeys.showOnboardingAfterLogin) private var showOnboardingAfterLogin: Bool = false
    @AppStorage(AppStorageKeys.selectedTab) private var selectedTab: Int = 0
    @AppStorage(AppStorageKeys.isPremium) private var isPremium: Bool = false
    @AppStorage(AppStorageKeys.trialStartTs) private var trialStartTs: Double = 0
    @AppStorage(AppStorageKeys.hasShownTrialExpiredAlert) private var hasShownTrialExpiredAlert: Bool = false

    @State private var showTrialExpiredAlert: Bool = false

    /// Drives the PartnerAcceptSheet. We observe partnerStore.pendingShareMetadata
    /// (set by PartnerSceneDelegate when a CKShare invite arrives) and present
    /// the accept sheet so the invitee can pick a display name before the share
    /// is actually accepted.
    @ObservedObject private var partnerStore = CloudKitPartnerStore.shared

    var body: some View {
        Group {
            if !isAuthenticated {
                AuthView()
            } else if showOnboardingAfterLogin {
                OnboardingView()
            } else {
                ZStack {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label(AppStrings.homeTitle(lang), systemImage: "house") }
                        .tag(0)

                    ChatBotView()
                            .tabItem { Label(lang.isArabicEffective ? "NoNet AI" : "NoNet AI", systemImage: "sparkles") }
                        .tag(1)

                    Group {
                        if #available(iOS 17.0, *) {
                            SettingsView()
                        } else {
                                Text(lang.isArabicEffective ? "الإعدادات (تتطلب iOS 17+)" : "Settings (requires iOS 17+")
                        }
                    }
                    .id(lang.selected.rawValue)
                        .tabItem { Label(AppStrings.settingsTitle(lang), systemImage: "gearshape") }
                    .tag(2)
                    }
                    .accentColor(AppColors.accent)
                    .toolbar(.hidden, for: .tabBar)
                    .safeAreaInset(edge: .bottom) {
                        CustomTabBar(selectedTab: $selectedTab)
                            .environmentObject(lang)
                    }
                }
            }
        }
        .environmentObject(lang)
        .environment(\.layoutDirection, lang.isArabicEffective ? .rightToLeft : .leftToRight)
        .onAppear {
            applySemanticDirection(isArabic: lang.isArabicEffective)
            expireTrialIfNeeded()
            configureTabBarAppearance()
            Task { await bootstrapCloudKit() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .CKAccountChanged)) { _ in
            Task { await bootstrapCloudKit() }
        }
        .onChange(of: lang.isArabicEffective) { isArabic in
            applySemanticDirection(isArabic: isArabic)
            configureTabBarAppearance()
        }
        .alert(lang.isArabicEffective ? "انتهت تجربتك المجانية" : "Your free trial ended", isPresented: $showTrialExpiredAlert) {
            Button(lang.isArabicEffective ? "اشترك الآن" : "Subscribe now") {
                selectedTab = 2 // Settings tab
            }
            Button(lang.isArabicEffective ? "لاحقاً" : "Later", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective ? "نأمل أن NoNet ساعدك خلال هذه الأيام السبعة. اختر خطّة لتحتفظ بجميع المزايا، أو استمرّ بالنسخة المجانية." : "We hope NoNet helped you during these 7 days. Choose a plan to keep all features, or continue with the free version.")
        }
        .sheet(item: Binding(
            get: { partnerStore.pendingShareMetadata.map(MetadataWrapper.init) },
            set: { newValue in
                // Two paths land here: (a) PartnerAcceptSheet finished
                // (accept/reject/later) and nulled pendingShareMetadata
                // itself, (b) the user swiped the sheet down without
                // deciding. Treat both as "clear the metadata so the sheet
                // doesn't reappear" — the user can re-tap the original
                // share link if they want to reconsider.
                if newValue == nil {
                    partnerStore.pendingShareMetadata = nil
                }
            }
        )) { wrapper in
            PartnerAcceptSheet(metadata: wrapper.metadata, onFinished: {})
                .environmentObject(lang)
        }
        .preferredColorScheme(.light)
    }

    /// CKShare.Metadata isn't Identifiable, so we wrap it for use with
    /// `.sheet(item:)`. The id key is the share's recordID.recordName —
    /// stable, unique, and human-readable in logs.
    private struct MetadataWrapper: Identifiable {
        let metadata: CKShare.Metadata
        var id: String { metadata.share.recordID.recordName }
    }

    /// Centralized bootstrap so onAppear and CKAccountChanged share the same
    /// sequence. Pulls account state, registers push subscriptions, fetches
    /// partnerships, replays any queued BreakAttempts, and refreshes the two
    /// approval-workflow lists.
    private func bootstrapCloudKit() async {
        let store = CloudKitPartnerStore.shared
        await store.refreshAccountStatus()
        guard store.isAccountAvailable else { return }
        await store.setupSubscriptions()
        await store.fetchPartnerships()
        await store.flushPendingBreakAttempts()
        // Approval workflow surfaces (PR 2).
        await store.fetchPendingRequestsForMe()
        await store.fetchMyOutgoingRequests()
        // Drain any approved requests we may have missed while the app was
        // closed — e.g. partner approved while we were offline, or the
        // background push delivery failed. fetchMyOutgoingRequests above
        // populated the list this reads from.
        await ApprovalExecutor.executePendingApprovals()
    }

    private func expireTrialIfNeeded() {
        guard isPremium else { return }
        guard trialStartTs > 0 else { return }
        let start = Date(timeIntervalSince1970: trialStartTs)
        if Date().timeIntervalSince(start) >= BlockingConstants.trialDurationSeconds {
            isPremium = false
            trialStartTs = 0
            if !hasShownTrialExpiredAlert {
                hasShownTrialExpiredAlert = true
                showTrialExpiredAlert = true
            }
        }
    }

    private func applySemanticDirection(isArabic: Bool) {
        UIView.appearance().semanticContentAttribute = isArabic ? .forceRightToLeft : .forceLeftToRight
    }

    private func configureTabBarAppearance() {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()

        // Item appearance with slight title offset (moves label down a bit → إحساس مسافة فوق الأيقونة)
        let itemAppearance = UITabBarItemAppearance()
        itemAppearance.normal.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 6)
        itemAppearance.selected.titlePositionAdjustment = UIOffset(horizontal: 0, vertical: 6)
        appearance.stackedLayoutAppearance = itemAppearance
        appearance.inlineLayoutAppearance = itemAppearance
        appearance.compactInlineLayoutAppearance = itemAppearance

        UITabBar.appearance().standardAppearance = appearance
        if #available(iOS 15.0, *) {
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        // Unselected tint for elegance
        UITabBar.appearance().unselectedItemTintColor = UIColor(red: 107/255, green: 114/255, blue: 128/255, alpha: 1)
    }
}

#Preview {
    ContentView()
}

/// Three-tab bottom navigation. SwiftUI's native TabView is hidden in favour
/// of this custom strip so we control:
///   • Hairline divider visibility (single 0.5pt line on top)
///   • Accent color matching the design system
///   • Press-feedback that's subtle (scale + tint) instead of a heavy overlay
///   • Vertical rhythm — icon stays centered, no .padding(.top, 14) hacks
/// Safe area: SwiftUI's `safeAreaInset(edge: .bottom)` (used by the parent
/// ContentView) automatically extends the background to cover the home
/// indicator, so the view itself doesn't need ignoresSafeArea games.
struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var lang: LanguageManager

    private struct Item: Identifiable { let id: Int; let title: String; let systemImage: String }

    private var items: [Item] {
        [
            Item(id: 0, title: AppStrings.homeTitle(lang), systemImage: "house.fill"),
            Item(id: 1, title: "NoNet AI", systemImage: "sparkles"),
            Item(id: 2, title: AppStrings.settingsTitle(lang), systemImage: "gearshape.fill")
        ]
    }

    @State private var pressedID: Int? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Top hairline — single 0.5pt divider between content and tab bar.
            Rectangle()
                .fill(AppColors.uiBorder.opacity(0.6))
                .frame(height: 0.5)

            HStack(spacing: 0) {
                ForEach(items) { item in
                    tabButton(for: item)
                }
            }
            .frame(height: 56)
            .background(AppColors.uiSurface)
        }
        .background(
            // Background extends behind the home indicator (safeAreaInset
            // already handles the inset; this just paints the surface
            // continuation so the bottom edge doesn't show the page bg).
            AppColors.uiSurface.ignoresSafeArea(edges: .bottom)
        )
    }

    @ViewBuilder
    private func tabButton(for item: Item) -> some View {
        let isSelected = selectedTab == item.id
        let isPressed = pressedID == item.id

        Button(action: {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            withAnimation(.easeOut(duration: 0.12)) { selectedTab = item.id }
        }) {
            VStack(spacing: 2) {
                Image(systemName: item.systemImage)
                    .symbolRenderingMode(.monochrome)
                    .font(.system(size: 22, weight: .regular))
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                    .scaleEffect(isPressed ? 0.92 : 1.0)
                Text(item.title)
                    .font(.caption2.weight(isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? AppColors.accent : AppColors.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // Custom press tracking — subtle scale on the icon, no overlay flash.
        // SimultaneousGesture so the button's tap action still fires.
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    withAnimation(.easeOut(duration: 0.1)) { pressedID = item.id }
                }
                .onEnded { _ in
                    withAnimation(.easeIn(duration: 0.15)) { pressedID = nil }
                }
        )
        .accessibilityLabel(item.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
