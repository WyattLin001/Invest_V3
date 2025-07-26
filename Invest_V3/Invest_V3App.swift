//
//  Invest_V3App.swift
//  Invest_V3
//
//  Created by 林家麒 on 2025/7/9.
//

import SwiftUI
import UserNotifications

@main
struct Invest_V3App: App {
    
    var body: some Scene {
        WindowGroup {
            // 使用新的啟動管理器，並注入主題管理器
            AppContainer()
                .withThemeManager()
        }
    }
}
