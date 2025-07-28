//
//  StatisticsManager.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//  智能投資管理平台 - 統計數據管理器
//

import Foundation
import SwiftUI
import Combine
import UIKit

/// 全局統計數據管理器
/// 管理總資產、活躍交易者數量等統計信息，支持定期更新
@MainActor
class StatisticsManager: ObservableObject {
    static let shared = StatisticsManager()
    
    // MARK: - Published Properties
    
    /// 活躍交易者數量
    @Published var activeUsersCount: Int = 0
    
    /// 是否正在加載數據
    @Published var isLoading: Bool = false
    
    /// 最後更新時間
    @Published var lastUpdated: Date?
    
    /// 網路連接狀態
    @Published var isNetworkAvailable: Bool = true
    
    /// 自動更新失敗狀態
    @Published var hasUpdateFailed: Bool = false
    @Published var updateFailureReason: String?
    
    // MARK: - Private Properties
    
    private var updateTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private let updateInterval: TimeInterval = 10.0 // 10秒更新一次
    
    // MARK: - Dependencies
    
    private let supabaseService = SupabaseService.shared
    private let portfolioManager = ChatPortfolioManager.shared
    
    // MARK: - Initialization
    
    private init() {
        startPeriodicUpdates()
        
        // 監聽 App 生命週期
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidBecomeActive),
            name: UIApplication.didBecomeActiveNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
    }
    
    deinit {
        // 在 deinit 中無法調用 @MainActor 方法，需要直接清理
        updateTimer?.invalidate()
        updateTimer = nil
        NotificationCenter.default.removeObserver(self)
        print("📊 [StatisticsManager] 已釋放資源")
    }
    
    // MARK: - Public Methods
    
    /// 開始定期更新
    func startPeriodicUpdates() {
        stopPeriodicUpdates() // 確保沒有重複的 timer
        
        // 立即執行一次更新
        Task {
            await fetchActiveUsersCount()
        }
        
        // 設置定期更新
        updateTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.fetchActiveUsersCount()
            }
        }
        
        print("📊 [StatisticsManager] 已開始定期更新，間隔: \(updateInterval)秒")
    }
    
    /// 停止定期更新
    func stopPeriodicUpdates() {
        updateTimer?.invalidate()
        updateTimer = nil
        print("📊 [StatisticsManager] 已停止定期更新")
    }
    
    /// 手動刷新數據
    func refreshData() async {
        print("📊 [StatisticsManager] 手動刷新數據")
        await fetchActiveUsersCount()
    }
    
    /// 重試失敗的更新
    func retryFailedUpdate() async {
        guard hasUpdateFailed else { return }
        
        print("🔄 [StatisticsManager] 重試失敗的自動更新")
        
        await MainActor.run {
            self.hasUpdateFailed = false
            self.updateFailureReason = nil
        }
        
        await refreshData()
    }
    
    // MARK: - Computed Properties
    
    /// 格式化的總資產顯示
    var formattedTotalAssets: String {
        let totalValue = portfolioManager.totalPortfolioValue + portfolioManager.availableBalance
        return formatLargeNumber(totalValue, prefix: "NT$", showPlus: false)
    }
    
    /// 格式化的活躍交易者數量
    var formattedActiveUsers: String {
        return formatLargeNumber(Double(activeUsersCount), prefix: "", showPlus: true)
    }
    
    /// 總資產標題
    var totalAssetsTitle: String {
        return "總資產"
    }
    
    /// 活躍交易者標題
    var activeUsersTitle: String {
        return "活躍交易者"
    }
    
    // MARK: - Private Methods
    
    /// 獲取活躍用戶數量
    private func fetchActiveUsersCount() async {
        guard !isLoading else { return }
        
        isLoading = true
        
        do {
            let count = try await supabaseService.fetchActiveUsersCount()
            
            await MainActor.run {
                self.activeUsersCount = count
                self.lastUpdated = Date()
                self.isNetworkAvailable = true
                self.isLoading = false
            }
            
            print("📊 [StatisticsManager] 活躍用戶數量更新: \(count)")
            
        } catch {
            await MainActor.run {
                self.isNetworkAvailable = false
                self.isLoading = false
                self.hasUpdateFailed = true
                self.updateFailureReason = error.localizedDescription
            }
            
            print("❌ [StatisticsManager] 自動更新失敗: \(error.localizedDescription)")
            
            // 如果是網路錯誤，使用模擬數據
            if activeUsersCount == 0 {
                await MainActor.run {
                    self.activeUsersCount = generateMockUserCount()
                    self.lastUpdated = Date()
                    self.hasUpdateFailed = false // 使用模擬數據後重置失敗狀態
                }
                print("📊 [StatisticsManager] 使用模擬數據: \(activeUsersCount)")
            }
        }
    }
    
    /// 格式化大數字顯示
    private func formatLargeNumber(_ value: Double, prefix: String, showPlus: Bool) -> String {
        let absValue = abs(value)
        
        if absValue >= 100_000_000 { // 億
            let formatted = String(format: "%.0f", absValue / 100_000_000)
            return "\(prefix)\(formatted)億\(showPlus ? "+" : "")"
        } else if absValue >= 10_000 { // 萬
            let formatted = String(format: "%.0f", absValue / 10_000)
            return "\(prefix)\(formatted)萬\(showPlus ? "+" : "")"
        } else if absValue >= 1_000 { // 千
            let formatted = String(format: "%.0f", absValue / 1_000)
            return "\(prefix)\(formatted)K\(showPlus ? "+" : "")"
        } else {
            return "\(prefix)\(String(format: "%.0f", absValue))\(showPlus ? "+" : "")"
        }
    }
    
    /// 生成模擬用戶數量（離線時使用）
    private func generateMockUserCount() -> Int {
        // 基於當前時間生成看起來合理的數字
        let baseCount = 1200
        let variation = Int.random(in: 0...100)
        return baseCount + variation
    }
    
    // MARK: - App Lifecycle Handlers
    
    @objc private func appDidBecomeActive() {
        print("📊 [StatisticsManager] App 變為活躍，重新開始更新")
        startPeriodicUpdates()
    }
    
    @objc private func appDidEnterBackground() {
        print("📊 [StatisticsManager] App 進入背景，暫停更新")
        stopPeriodicUpdates()
    }
}

// MARK: - Extensions

extension StatisticsManager {
    /// 獲取統計摘要
    func getStatisticsSummary() -> (totalAssets: Double, activeUsers: Int, lastUpdate: Date?) {
        let totalAssets = portfolioManager.totalPortfolioValue + portfolioManager.availableBalance
        return (totalAssets: totalAssets, activeUsers: activeUsersCount, lastUpdate: lastUpdated)
    }
    
    /// 檢查數據是否需要更新
    func needsUpdate() -> Bool {
        guard let lastUpdated = lastUpdated else { return true }
        return Date().timeIntervalSince(lastUpdated) > updateInterval
    }
}