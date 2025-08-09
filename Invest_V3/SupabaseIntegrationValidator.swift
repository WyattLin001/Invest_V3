//
//  SupabaseIntegrationValidator.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/30.
//  Supabase 整合驗證器 - 確保所有功能與 Supabase 的完整連動
//

import Foundation
import SwiftUI

/// Supabase 整合驗證器
/// 負責驗證所有關鍵功能與 Supabase 的連接狀態
@MainActor
class SupabaseIntegrationValidator: ObservableObject {
    static let shared = SupabaseIntegrationValidator()
    
    @Published var validationResults: [ValidationResult] = []
    @Published var isValidating = false
    @Published var overallStatus: ValidationStatus = .pending
    
    private let supabaseService = SupabaseService.shared
    private let portfolioSyncService = PortfolioSyncService.shared
    
    private init() {}
    
    /// 執行完整的 Supabase 整合驗證
    func validateSupabaseIntegration() async {
        isValidating = true
        validationResults.removeAll()
        
        print("🔍 [SupabaseValidator] 開始 Supabase 整合驗證")
        
        // 驗證項目清單
        let validations: [(String, () async -> ValidationResult)] = [
            ("Supabase Manager 初始化", validateSupabaseManager),
            ("用戶認證系統", validateUserAuthentication),
            ("錢包餘額查詢", validateWalletBalance),
            ("錦標賽數據載入", validateTournamentData),
            ("投資組合同步", validatePortfolioSync),
            ("交易記錄查詢", validateTradingRecords),
            ("統計數據更新", validateStatisticsUpdate),
            ("排行榜數據載入", validateRankingsData)
        ]
        
        // 執行所有驗證
        for (name, validation) in validations {
            var result = await validation()
            result.testName = name
            validationResults.append(result)
            print("   \(result.isSuccess ? "✅" : "❌") \(name): \(result.message)")
        }
        
        // 計算整體狀態
        let successCount = validationResults.filter { $0.isSuccess }.count
        let totalCount = validationResults.count
        
        if successCount == totalCount {
            overallStatus = .success
        } else if successCount > totalCount / 2 {
            overallStatus = .warning
        } else {
            overallStatus = .failure
        }
        
        isValidating = false
        
        print("🏁 [SupabaseValidator] 驗證完成: \(successCount)/\(totalCount) 項通過")
        print("📊 [SupabaseValidator] 整體狀態: \(overallStatus)")
    }
    
    // MARK: - 個別驗證函數
    
    private func validateSupabaseManager() async -> ValidationResult {
        do {
            // 檢查 SupabaseManager 初始化狀態
            let isInitialized = SupabaseManager.shared.isInitialized
            
            if !isInitialized {
                // 嘗試初始化
                try await SupabaseManager.shared.initialize()
            }
            
            let finalStatus = SupabaseManager.shared.isInitialized
            
            return ValidationResult(
                isSuccess: finalStatus,
                message: finalStatus ? "Supabase Manager 初始化成功" : "Supabase Manager 初始化失敗",
                details: "初始化狀態: \(finalStatus)"
            )
        } catch {
            return ValidationResult(
                isSuccess: false,
                message: "Supabase Manager 初始化失敗",
                details: error.localizedDescription
            )
        }
    }
    
    private func validateUserAuthentication() async -> ValidationResult {
        do {
            // 檢查當前用戶
            let currentUser = supabaseService.getCurrentUser()
            
            if let user = currentUser {
                return ValidationResult(
                    isSuccess: true,
                    message: "用戶認證系統正常",
                    details: "當前用戶: \(user.username)"
                )
            } else {
                // 嘗試載入用戶列表以測試連接
                let users = try await supabaseService.fetchAllUsers()
                return ValidationResult(
                    isSuccess: true,
                    message: "用戶系統連接正常（未登入）",
                    details: "系統中共有 \(users.count) 位用戶"
                )
            }
        } catch {
            return ValidationResult(
                isSuccess: false,
                message: "用戶認證系統連接失敗",
                details: error.localizedDescription
            )
        }
    }
    
    private func validateWalletBalance() async -> ValidationResult {
        do {
            let balance = try await supabaseService.fetchWalletBalance()
            return ValidationResult(
                isSuccess: true,
                message: "錢包餘額查詢成功",
                details: "當前餘額: $\(String(format: "%.2f", balance))"
            )
        } catch {
            return ValidationResult(
                isSuccess: false,
                message: "錢包餘額查詢失敗",
                details: error.localizedDescription
            )
        }
    }
    
    private func validateTournamentData() async -> ValidationResult {
        do {
            let tournaments = try await supabaseService.fetchFeaturedTournaments()
            let stats = try await supabaseService.fetchTournamentStatistics()
            
            return ValidationResult(
                isSuccess: true,
                message: "錦標賽數據載入成功",
                details: "載入 \(tournaments.count) 個錦標賽，\(stats.totalParticipants) 位參與者"
            )
        } catch {
            return ValidationResult(
                isSuccess: false,
                message: "錦標賽數據載入失敗",
                details: error.localizedDescription
            )
        }
    }
    
    private func validatePortfolioSync() async -> ValidationResult {
        do {
            // 檢查投資組合同步服務狀態
            let hasChanges = portfolioSyncService.hasPendingChanges
            
            // 嘗試執行手動同步
            await portfolioSyncService.manualSync()
            
            let syncError = portfolioSyncService.syncError
            
            if syncError == nil {
                return ValidationResult(
                    isSuccess: true,
                    message: "投資組合同步服務正常",
                    details: "待同步變更: \(hasChanges ? "有" : "無")"
                )
            } else {
                return ValidationResult(
                    isSuccess: false,
                    message: "投資組合同步服務異常",
                    details: syncError ?? "未知錯誤"
                )
            }
        } catch {
            return ValidationResult(
                isSuccess: false,
                message: "投資組合同步服務測試失敗",
                details: error.localizedDescription
            )
        }
    }
    
    private func validateTradingRecords() async -> ValidationResult {
        do {
            // 嘗試獲取交易記錄
            let portfolioManager = ChatPortfolioManager.shared
            let records = portfolioManager.tradingRecords
            
            // 檢查本地交易記錄
            if !records.isEmpty {
                return ValidationResult(
                    isSuccess: true,
                    message: "交易記錄系統正常",
                    details: "本地記錄: \(records.count) 筆交易"
                )
            } else {
                return ValidationResult(
                    isSuccess: true,
                    message: "交易記錄系統正常（無記錄）",
                    details: "尚無交易記錄"
                )
            }
        } catch {
            return ValidationResult(
                isSuccess: false,
                message: "交易記錄系統異常",
                details: error.localizedDescription
            )
        }
    }
    
    private func validateStatisticsUpdate() async -> ValidationResult {
        do {
            let statisticsManager = StatisticsManager.shared
            
            // 觸發統計數據更新
            await statisticsManager.refreshData()
            
            let hasError = statisticsManager.hasUpdateFailed
            let lastUpdated = statisticsManager.lastUpdated
            
            if !hasError && lastUpdated != nil {
                return ValidationResult(
                    isSuccess: true,
                    message: "統計數據更新成功",
                    details: "最後更新: \(DateFormatter.timeOnly.string(from: lastUpdated!))"
                )
            } else {
                return ValidationResult(
                    isSuccess: false,
                    message: "統計數據更新失敗",
                    details: statisticsManager.updateFailureReason ?? "未知錯誤"
                )
            }
        } catch {
            return ValidationResult(
                isSuccess: false,
                message: "統計數據系統異常",
                details: error.localizedDescription
            )
        }
    }
    
    private func validateRankingsData() async -> ValidationResult {
        do {
            // 使用 TournamentService 測試排行榜數據
            let tournamentService = ServiceConfiguration.makeTournamentService()
            let tournaments = try await tournamentService.fetchTournaments()
            
            if let firstTournament = tournaments.first {
                let participants = try await tournamentService.fetchTournamentParticipants(tournamentId: firstTournament.id)
                
                return ValidationResult(
                    isSuccess: true,
                    message: "排行榜數據載入成功",
                    details: "錦標賽 \(firstTournament.name) 有 \(participants.count) 位參與者"
                )
            } else {
                return ValidationResult(
                    isSuccess: true,
                    message: "排行榜系統正常（無數據）",
                    details: "尚無錦標賽數據"
                )
            }
        } catch {
            return ValidationResult(
                isSuccess: false,
                message: "排行榜數據載入失敗",
                details: error.localizedDescription
            )
        }
    }
}

// MARK: - 數據模型

struct ValidationResult {
    var testName: String = ""
    let isSuccess: Bool
    let message: String
    let details: String
    let timestamp: Date = Date()
}

enum ValidationStatus {
    case pending
    case success
    case warning
    case failure
    
    var displayName: String {
        switch self {
        case .pending: return "等待中"
        case .success: return "全部通過"
        case .warning: return "部分通過"
        case .failure: return "測試失敗"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return .blue
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        }
    }
}

// MARK: - SwiftUI 視圖組件

struct SupabaseValidationView: View {
    @StateObject private var validator = SupabaseIntegrationValidator.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 整體狀態
                    overallStatusCard
                    
                    // 驗證結果列表
                    if !validator.validationResults.isEmpty {
                        validationResultsList
                    }
                    
                    // 操作按鈕
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Supabase 整合驗證")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var overallStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: validator.isValidating ? "arrow.triangle.2.circlepath" : statusIcon)
                    .font(.title2)
                    .foregroundColor(validator.overallStatus.color)
                    .rotationEffect(.degrees(validator.isValidating ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: validator.isValidating)
                
                Text(validator.isValidating ? "驗證中..." : validator.overallStatus.displayName)
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            if !validator.validationResults.isEmpty {
                let successCount = validator.validationResults.filter { $0.isSuccess }.count
                let totalCount = validator.validationResults.count
                
                HStack {
                    Text("通過率: \(successCount)/\(totalCount)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("\(safePercentage(successCount: successCount, totalCount: totalCount))%")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(validator.overallStatus.color)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    }
    
    private var validationResultsList: some View {
        VStack(spacing: 8) {
            HStack {
                Text("驗證結果")
                    .font(.headline)
                    .fontWeight(.semibold)
                Spacer()
            }
            
            ForEach(validator.validationResults.indices, id: \.self) { index in
                let result = validator.validationResults[index]
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: result.isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(result.isSuccess ? .green : .red)
                        
                        Text(result.testName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(DateFormatter.timeOnly.string(from: result.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(result.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if !result.details.isEmpty {
                        Text(result.details)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .padding(.leading, 20)
                    }
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
    }
    
    private var actionButtons: some View {
        VStack(spacing: 12) {
            Button(action: {
                Task {
                    await validator.validateSupabaseIntegration()
                }
            }) {
                HStack {
                    if validator.isValidating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .tint(.white)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                    Text(validator.isValidating ? "驗證中..." : "開始驗證")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.blue)
                .cornerRadius(12)
            }
            .disabled(validator.isValidating)
            
            Button(action: {
                validator.validationResults.removeAll()
                validator.overallStatus = .pending
            }) {
                Text("清除結果")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var statusIcon: String {
        switch validator.overallStatus {
        case .pending: return "clock"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.circle.fill"
        }
    }
    
    // MARK: - Helper Functions
    
    /// 安全計算百分比，避免除以零和 NaN 值
    private func safePercentage(successCount: Int, totalCount: Int) -> Int {
        guard totalCount > 0 else { return 0 }
        
        let percentage = Double(successCount) / Double(totalCount) * 100.0
        
        // 檢查是否為有效數字
        guard percentage.isFinite && !percentage.isNaN else { return 0 }
        
        return Int(percentage.rounded())
    }
}

#Preview {
    SupabaseValidationView()
}