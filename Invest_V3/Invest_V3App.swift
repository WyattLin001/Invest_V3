//
//  Invest_V3App.swift
//  Invest_V3
//
//  Created by 林家麒 on 2025/7/9.
//

import SwiftUI

@main
struct Invest_V3App: App {
    init() {
        // 在 app 啟動時初始化 Supabase
        Task { @MainActor in
            do {
                try await SupabaseManager.shared.initialize()
                print("✅ App 啟動：Supabase 初始化完成")
            } catch {
                print("❌ App 啟動：Supabase 初始化失敗 - \(error.localizedDescription)")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(AuthenticationService())
                .environmentObject(UserProfileService.shared)
                .environmentObject(PortfolioService.shared)
                .environmentObject(StockService.shared)
        }
    }
}
