//
//  ContentView.swift
//  blocking app
//
//  Created by Khalid Khamid on 12/03/1447 AH.
//

import SwiftUI

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
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label(AppStrings.homeTitle(lang), systemImage: "house") }
                        .tag(0)

                    ChatBotView()
                        .tabItem { Label(lang.isArabicEffective ? "AI NoNet للتركيز" : "AI NoNet for Focusing", systemImage: "message") }
                        .tag(1)

                    Group {
                        if #available(iOS 17.0, *) {
                            SettingsView()
                        } else {
                            Text(lang.isArabicEffective ? "الإعدادات (تتطلب iOS 17+)" : "Settings (requires iOS 17+)")
                        }
                    }
                    .tabItem { Label(AppStrings.settingsTitle(lang), systemImage: "gear") }
                    .tag(2)
                }
            }
        }
        .environmentObject(lang)
        .accentColor(AppColors.primaryBlue)
        .onAppear {
            UIView.appearance().semanticContentAttribute = lang.isArabicEffective ? .forceRightToLeft : .forceLeftToRight
            expireTrialIfNeeded()
        }
        .alert(lang.isArabicEffective ? "انتهت التجربة المجانية" : "Free Trial Expired", isPresented: $showTrialExpiredAlert) {
            Button(lang.isArabicEffective ? "ترقية الآن" : "Upgrade Now") {
                selectedTab = 2 // Settings tab
            }
            Button(lang.isArabicEffective ? "لاحقًا" : "Later", role: .cancel) {}
        } message: {
            Text(lang.isArabicEffective ? "انتهت تجربتك المجانية لمدة 7 أيام. ترقّ الآن للاستمرار في استخدام جميع الميزات." : "Your 7-day free trial has expired. Upgrade now to continue using all features.")
        }
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
}

#Preview {
    ContentView()
}
