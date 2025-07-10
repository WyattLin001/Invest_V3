//
//  EnhancedMainTabView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct EnhancedMainTabView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            EnhancedHomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("主頁")
                }
                .tag(0)
            
            EnhancedChatView()
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "message.fill" : "message")
                    Text("聊天")
                }
                .tag(1)
            
            EnhancedArticlesView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "doc.text.fill" : "doc.text")
                    Text("資訊")
                }
                .tag(2)
            
            EnhancedWalletView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "creditcard.fill" : "creditcard")
                    Text("錢包")
                }
                .tag(3)
            
            EnhancedSettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "gearshape.fill" : "gearshape")
                    Text("設定")
                }
                .tag(4)
        }
        .accentColor(Color(hex: "#00B900"))
        .onAppear {
            // Customize tab bar appearance
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            // Selected item color
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color(hex: "#00B900"))
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color(hex: "#00B900"))
            ]
            
            // Normal item color
            appearance.stackedLayoutAppearance.normal.iconColor = UIColor.systemGray
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: UIColor.systemGray
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
    }
}

#Preview {
    EnhancedMainTabView()
}