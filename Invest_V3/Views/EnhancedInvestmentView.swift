//
//  EnhancedInvestmentView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  投資管理主視圖 - 包含五大功能模組的完整投資體驗

import SwiftUI

/// EnhancedInvestmentView - 新的投資總覽界面，取代現有的 InvestmentPanelView
/// 提供更完整的投資管理體驗，包含以下五大功能模組：
/// 1. InvestmentHomeView - 投資組合總覽
/// 2. InvestmentRecordsView - 交易記錄
/// 3. TournamentSelectionView - 錦標賽選擇
/// 4. TournamentRankingsView - 排行榜與動態牆
/// 5. PersonalPerformanceView - 個人績效分析

struct EnhancedInvestmentView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    // 錦標賽相關狀態
    @State private var showTournamentModeSelector = false
    @State private var showingTournamentDetail = false
    @State private var showingCreateTournament = false
    @State private var showingTournamentTrading = false
    @State private var showingTournamentSelection = false
    @State private var showTitle = false
    
    // 模擬數據 - 將來替換為真實數據
    let currentTournamentName = "2025年度投資錦標賽"
    let isAdminUser = false
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 1. 投資組合總覽
            NavigationStack {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("投資組合總覽")
                            .font(.title2)
                            .padding()
                        
                        Text("這裡將顯示投資組合內容")
                            .padding()
                    }
                }
                .navigationTitle("投資總覽")
                .toolbar {
                    ToolbarItem {
                        Button("關閉") {
                            dismiss()
                        }
                        .foregroundColor(.green)
                    }
                }
            }
            .tabItem {
                Label("投資總覽", systemImage: "chart.pie.fill")
            }
            .tag(0)
            
            // 2. 交易記錄
            NavigationStack {
                ScrollView(.vertical, showsIndicators: true) {
                    VStack {
                        Text("交易記錄")
                            .font(.title2)
                            .padding()
                        
                        Text("這裡將顯示交易記錄")
                            .padding()
                    }
                }
                .navigationTitle("交易記錄")
            }
            .tabItem {
                Label("交易記錄", systemImage: "list.bullet.clipboard")
            }
            .tag(1)
            
            // 3. 錦標賽選擇
            NavigationStack {
                ScrollView {
                    VStack {
                        Text("錦標賽選擇")
                            .font(.title2)
                            .padding()
                        
                        Text("這裡將顯示錦標賽選項")
                            .padding()
                    }
                }
                .navigationTitle("錦標賽")
            }
            .tabItem {
                Label("錦標賽", systemImage: "trophy.fill")
            }
            .tag(2)
            
            // 4. 排行榜
            NavigationStack {
                ScrollView {
                    VStack {
                        Text("排行榜")
                            .font(.title2)
                            .padding()
                        
                        Text("這裡將顯示排行榜")
                            .padding()
                    }
                }
                .navigationTitle("排行榜")
            }
            .tabItem {
                Label("排行榜", systemImage: "list.number")
            }
            .tag(3)
            
            // 5. 個人績效
            NavigationStack {
                ScrollView {
                    VStack {
                        Text("個人績效")
                            .font(.title2)
                            .padding()
                        
                        Text("這裡將顯示個人績效分析")
                            .padding()
                    }
                }
                .navigationTitle("我的績效")
            }
            .tabItem {
                Label("我的績效", systemImage: "chart.bar.fill")
            }
            .tag(4)
        }
        .accentColor(.blue)
    }
}

// MARK: - Preview
struct EnhancedInvestmentView_Previews: PreviewProvider {
    static var previews: some View {
        EnhancedInvestmentView()
    }
}