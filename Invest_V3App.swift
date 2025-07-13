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
        Task {
            await SupabaseManager.shared.initialize()
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
