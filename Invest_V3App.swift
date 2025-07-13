//
//  Invest_V3App.swift
//  Invest_V3
//
//  Created by 林家麒 on 2025/7/9.
//

import SwiftUI
import BackgroundTasks

@main
struct Invest_V3App: App {
    @StateObject private var autoSettlementScheduler = AutoSettlementScheduler.shared
    @StateObject private var notificationService = SettlementNotificationService.shared
    
    init() {
        Task {
            await SupabaseManager.shared.initialize()
        }
        
        // 註冊背景任務
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            MainAppView()
                .environmentObject(AuthenticationService())
                .environmentObject(UserProfileService.shared)
                .environmentObject(PortfolioService.shared)
                .environmentObject(StockService.shared)
                .environmentObject(autoSettlementScheduler)
                .environmentObject(notificationService)
                .onAppear {
                    // 排程自動結算
                    autoSettlementScheduler.scheduleBackgroundSettlement()
                }
        }
    }
    
    // MARK: - 背景任務註冊
    private func registerBackgroundTasks() {
        // 註冊背景結算任務
        BGTaskScheduler.shared.register(forTaskWithIdentifier: "com.invest.v3.settlement", using: nil) { task in
            // 這個任務會在 AutoSettlementScheduler 中處理
        }
    }
}
