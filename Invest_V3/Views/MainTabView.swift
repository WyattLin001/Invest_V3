//
//  MainTabView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct MainTabView: View {
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("首頁")
                }
            
            InvestmentGroupsView()
                .tabItem {
                    Image(systemName: "person.3.fill")
                    Text("投資群組")
                }
            
            PortfolioView()
                .tabItem {
                    Image(systemName: "chart.pie.fill")
                    Text("投資組合")
                }
            
            ArticlesView()
                .tabItem {
                    Image(systemName: "newspaper.fill")
                    Text("文章")
                }
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("個人")
                }
        }
        .accentColor(.blue)
    }
}

#Preview {
    MainTabView()
}