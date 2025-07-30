//
//  StatisticsBanner.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//  智能投資管理平台 - 統計橫幅組件
//

import SwiftUI

/// 智能投資管理平台統計橫幅
/// 顯示總資產和活躍交易者數量，用於 TabView 頂部
struct StatisticsBanner: View {
    @ObservedObject var statisticsManager: StatisticsManager
    @ObservedObject var portfolioManager: ChatPortfolioManager
    @ObservedObject private var syncService = PortfolioSyncService.shared
    let currentTournamentName: String
    
    // MARK: - Properties
    
    private let bannerHeight: CGFloat = 60
    private let cornerRadius: CGFloat = 0
    
    // MARK: - Body
    
    var body: some View {
        ZStack {
            // 背景漸層
            bannerBackground
            
            // 內容
            bannerContent
        }
        .frame(height: bannerHeight)
        .onAppear {
            // 確保統計管理器已啟動
            if !statisticsManager.isLoading && statisticsManager.lastUpdated == nil {
                Task { @MainActor in
                    await statisticsManager.refreshData()
                }
            }
        }
    }
    
    // MARK: - Background
    
    private var bannerBackground: some View {
        LinearGradient(
            gradient: Gradient(colors: [
                Color(red: 0.118, green: 0.478, blue: 0.549), // #1E7A8C
                Color(red: 0.106, green: 0.427, blue: 0.490)  // 稍微深一點的藍綠色
            ]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .cornerRadius(cornerRadius)
    }
    
    // MARK: - Content
    
    private var bannerContent: some View {
        HStack(spacing: 0) {
            // 左側：總資產
            totalAssetsSection
            
            Spacer()
            
            // 中央標題
            platformTitle
            
            Spacer()
            
            // 右側：活躍交易者
            activeUsersSection
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
    
    // MARK: - Platform Title
    
    private var platformTitle: some View {
        VStack(spacing: 4) {
            Text(currentTournamentName)
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.8)
            
            // 更新狀態指示器
            updateStatusIndicator
        }
    }
    
    private var updateStatusIndicator: some View {
        HStack(spacing: 4) {
            if statisticsManager.isLoading {
                ProgressView()
                    .scaleEffect(0.6)
                    .tint(.white.opacity(0.7))
                Text("更新中...")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
            } else if statisticsManager.hasUpdateFailed {
                Button(action: {
                    Task { @MainActor in
                        await statisticsManager.retryFailedUpdate()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.caption2)
                            .foregroundColor(.orange.opacity(0.9))
                        Text("更新失敗，點擊重試")
                            .font(.caption2)
                            .foregroundColor(.orange.opacity(0.9))
                    }
                }
            } else if syncService.isSyncing {
                HStack(spacing: 4) {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.yellow.opacity(0.8))
                    Text("數據同步中...")
                        .font(.caption2)
                        .foregroundColor(.yellow.opacity(0.8))
                }
            } else if let syncError = syncService.syncError {
                Button(action: {
                    Task { @MainActor in
                        await syncService.manualSync()
                    }
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.9))
                        Text("同步失敗，重試")
                            .font(.caption2)
                            .foregroundColor(.red.opacity(0.9))
                    }
                }
            } else {
                Image(systemName: statisticsManager.isNetworkAvailable ? "wifi" : "wifi.slash")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.7))
                
                if let lastUpdated = statisticsManager.lastUpdated {
                    Text(formatLastUpdateTime(lastUpdated))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    // MARK: - Total Assets Section
    
    private var totalAssetsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(statisticsManager.totalAssetsTitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text(statisticsManager.formattedTotalAssets)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .contentTransition(.numericText(value: portfolioManager.totalPortfolioValue))
        }
    }
    
    // MARK: - Active Users Section
    
    private var activeUsersSection: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack(spacing: 6) {
                Text(statisticsManager.activeUsersTitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Image(systemName: "person.2.fill")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            
            Text(statisticsManager.formattedActiveUsers)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .contentTransition(.numericText(value: Double(statisticsManager.activeUsersCount)))
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatLastUpdateTime(_ date: Date) -> String {
        let now = Date()
        let timeInterval = now.timeIntervalSince(date)
        
        if timeInterval < 60 {
            return "剛剛更新"
        } else if timeInterval < 3600 {
            let minutes = Int(timeInterval / 60)
            return "\(minutes)分鐘前"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            return formatter.string(from: date)
        }
    }
}

// MARK: - Compact Banner Variant

/// 緊湊版統計橫幅（用於較小螢幕）
struct CompactStatisticsBanner: View {
    @ObservedObject var statisticsManager: StatisticsManager
    @ObservedObject var portfolioManager: ChatPortfolioManager
    let currentTournamentName: String
    
    var body: some View {
        HStack(spacing: 16) {
            // 總資產
            StatisticItem(
                icon: "dollarsign.circle.fill",
                title: "總資產",
                value: statisticsManager.formattedTotalAssets
            )
            
            Divider()
                .background(Color.white.opacity(0.3))
            
            // 活躍交易者
            StatisticItem(
                icon: "person.2.fill",
                title: "活躍交易者",
                value: statisticsManager.formattedActiveUsers
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.118, green: 0.478, blue: 0.549),
                    Color(red: 0.106, green: 0.427, blue: 0.490)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
}

/// 統計項目組件
private struct StatisticItem: View {
    let icon: String
    let title: String
    let value: String
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white.opacity(0.8))
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
                
                Text(value)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
    }
}

// MARK: - Refresh Control

/// 下拉刷新控制項
struct StatisticsBannerRefreshControl: View {
    @ObservedObject var statisticsManager: StatisticsManager
    @State private var isRefreshing = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // 刷新控制區域
                RefreshIndicator(isRefreshing: $isRefreshing) {
                    await refreshData()
                }
                .padding(.top, -50)
                .opacity(isRefreshing ? 1 : 0)
            }
        }
        .refreshable {
            await refreshData()
        }
    }
    
    @MainActor
    private func refreshData() async {
        isRefreshing = true
        await statisticsManager.refreshData()
        isRefreshing = false
    }
}

/// 刷新指示器
private struct RefreshIndicator: View {
    @Binding var isRefreshing: Bool
    let onRefresh: () async -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            if isRefreshing {
                ProgressView()
                    .scaleEffect(0.8)
                    .tint(.blue)
                
                Text("更新中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 50)
        .task {
            if isRefreshing {
                await onRefresh()
            }
        }
    }
}

// MARK: - Preview

#Preview("統計橫幅") {
    VStack(spacing: 20) {
        StatisticsBanner(
            statisticsManager: StatisticsManager.shared,
            portfolioManager: ChatPortfolioManager.shared,
            currentTournamentName: "2025年度投資錦標賽"
        )
        
        CompactStatisticsBanner(
            statisticsManager: StatisticsManager.shared,
            portfolioManager: ChatPortfolioManager.shared,
            currentTournamentName: "2025年度投資錦標賽"
        )
        
        Spacer()
    }
    .background(Color.gray.opacity(0.1))
}
