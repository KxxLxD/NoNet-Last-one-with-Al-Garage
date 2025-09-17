//
//  ContentView.swift
//  blocking app
//
//  Created by Khalid Khamid on 12/03/1447 AH.
//

import SwiftUI
import UIKit

struct ContentView: View {
    @StateObject private var lang = LanguageManager.shared
    @AppStorage("isAuthenticated") private var isAuthenticated: Bool = false
    @AppStorage("showOnboardingAfterLogin") private var showOnboardingAfterLogin: Bool = false
    @AppStorage("selectedTab") private var selectedTab: Int = 0
    @AppStorage("isPremium") private var isPremium: Bool = false
    @AppStorage("trialStartTs") private var trialStartTs: Double = 0
    @AppStorage("hasShownTrialExpiredAlert") private var hasShownTrialExpiredAlert: Bool = false

    @State private var showTrialExpiredAlert: Bool = false

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
                    .accentColor(AppColors.accentDark)
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
        }
        .onChange(of: lang.isArabicEffective) { isArabic in
            applySemanticDirection(isArabic: isArabic)
            configureTabBarAppearance()
        }
        .alert(lang.isArabicEffective ? "انتهت التجربة المجانية" : "Free Trial Expired", isPresented: $showTrialExpiredAlert) {
            Button(lang.isArabicEffective ? "ترقية الآن" : "Upgrade Now") {
                selectedTab = 2 // Settings tab
            }
            Button(lang.isArabicEffective ? "لاحقًا" : "Later", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective ? "انتهت تجربتك المجانية لمدة 7 أيام. ترقّ الآن للاستمرار في استخدام جميع الميزات." : "Your 7-day free trial has expired. Upgrade now to continue using all features.")
        }
        .preferredColorScheme(.light)
    }

    private func expireTrialIfNeeded() {
        guard isPremium else { return }
        guard trialStartTs > 0 else { return }
        let trialDuration: TimeInterval = 7 * 24 * 3600
        let start = Date(timeIntervalSince1970: trialStartTs)
        if Date().timeIntervalSince(start) >= trialDuration {
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

struct CustomTabBar: View {
    @Binding var selectedTab: Int
    @EnvironmentObject private var lang: LanguageManager

    private struct Item: Identifiable { let id: Int; let title: String; let systemImage: String }

    private var items: [Item] {
        [
            Item(id: 0, title: AppStrings.homeTitle(lang), systemImage: "house"),
            Item(id: 1, title: lang.isArabicEffective ? "NoNet AI" : "NoNet AI", systemImage: "sparkles"),
            Item(id: 2, title: AppStrings.settingsTitle(lang), systemImage: "gearshape")
        ]
    }

    var body: some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill(AppColors.uiBorder.opacity(0.35))
                .frame(height: 0.5)
                .edgesIgnoringSafeArea(.bottom)
            HStack(spacing: 0) {
                ForEach(items) { item in
                    Button(action: { withAnimation(.easeOut(duration: 0.15)) { selectedTab = item.id } }) {
                        VStack(spacing: 4) {
                            Image(systemName: item.systemImage)
                                .symbolRenderingMode(.monochrome)
                                .font(.system(size: 21, weight: .regular))
                                .foregroundColor(selectedTab == item.id ? AppColors.accentDark : AppColors.textSecondary)
                                .padding(.top, 14)
                            Text(item.title)
                                .font(.system(size: 12, weight: selectedTab == item.id ? .semibold : .regular))
                                .foregroundColor(selectedTab == item.id ? AppColors.accentDark : AppColors.textSecondary)
                                .lineLimit(1)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 60)
            .background(AppColors.uiSurface)
        }
        .background(AppColors.uiSurface)
    }
}
