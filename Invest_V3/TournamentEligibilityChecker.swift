//
//  TournamentEligibilityChecker.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/30.
//  錦標賽參加條件檢查器 - 檢查用戶是否符合參加錦標賽的條件
//

import Foundation
import SwiftUI

/// 錦標賽參加條件檢查器
/// 負責檢查用戶是否符合參加特定錦標賽的各項條件
@MainActor
class TournamentEligibilityChecker: ObservableObject {
    static let shared = TournamentEligibilityChecker()
    
    @Published var eligibilityResults: [String: EligibilityResult] = [:]
    @Published var userStats: UserEligibilityStats?
    
    private let supabaseService = SupabaseService.shared
    private let portfolioManager = ChatPortfolioManager.shared
    
    private init() {
        loadUserStats()
    }
    
    /// 檢查用戶是否符合參加錦標賽的條件
    func checkEligibility(for tournament: Tournament, user: UserProfile?) async -> EligibilityResult {
        print("🏆 [TournamentEligibility] 檢查錦標賽參加條件: \(tournament.name)")
        
        guard let user = user else {
            return EligibilityResult(
                tournamentId: tournament.id,
                isEligible: false,
                failedRequirements: [.notLoggedIn],
                message: "請先登入以參加錦標賽"
            )
        }
        
        var failedRequirements: [EligibilityRequirement] = []
        var warnings: [String] = []
        
        // 1. 檢查登入天數
        let loginDaysCheck = await checkLoginDays(user: user, tournament: tournament)
        if !loginDaysCheck.passed {
            failedRequirements.append(.insufficientLoginDays(required: loginDaysCheck.required, current: loginDaysCheck.current))
        }
        
        // 2. 檢查代幣餘額
        let tokenCheck = await checkTokenBalance(user: user, tournament: tournament)
        if !tokenCheck.passed {
            failedRequirements.append(.insufficientTokens(required: tokenCheck.required, current: tokenCheck.current))
        }
        
        // 3. 檢查投資經驗
        let experienceCheck = checkInvestmentExperience(user: user, tournament: tournament)
        if !experienceCheck.passed {
            failedRequirements.append(.insufficientExperience(required: experienceCheck.required, current: experienceCheck.current))
        }
        
        // 4. 檢查年齡限制
        let ageCheck = checkAgeRequirement(user: user, tournament: tournament)
        if !ageCheck.passed {
            failedRequirements.append(.ageRestriction(required: ageCheck.required, current: ageCheck.current))
        }
        
        // 5. 檢查參加次數限制
        let participationCheck = await checkParticipationLimit(user: user, tournament: tournament)
        if !participationCheck.passed {
            failedRequirements.append(.participationLimitReached(limit: participationCheck.required))
        }
        
        // 6. 檢查錦標賽特殊要求
        let specialCheck = checkSpecialRequirements(user: user, tournament: tournament)
        if !specialCheck.passed {
            failedRequirements.append(.specialRequirementNotMet(requirement: specialCheck.requirement))
        }
        
        // 7. 檢查報名截止時間
        let deadlineCheck = checkRegistrationDeadline(tournament: tournament)
        if !deadlineCheck.passed {
            failedRequirements.append(.registrationClosed)
        }
        
        // 8. 檢查參與者數量限制
        let capacityCheck = checkTournamentCapacity(tournament: tournament)
        if !capacityCheck.passed {
            failedRequirements.append(.tournamentFull)
        } else if capacityCheck.isNearFull {
            warnings.append("錦標賽名額即將額滿，請盡快報名")
        }
        
        let isEligible = failedRequirements.isEmpty
        let message = generateEligibilityMessage(isEligible: isEligible, requirements: failedRequirements, warnings: warnings)
        
        let result = EligibilityResult(
            tournamentId: tournament.id,
            isEligible: isEligible,
            failedRequirements: failedRequirements,
            warnings: warnings,
            message: message
        )
        
        // 快取結果
        eligibilityResults[tournament.id.uuidString] = result
        
        return result
    }
    
    /// 獲取用戶整體參賽資格統計
    func getUserEligibilityStats() async -> UserEligibilityStats {
        if let cachedStats = userStats {
            return cachedStats
        }
        
        let stats = await calculateUserStats()
        userStats = stats
        return stats
    }
    
    /// 提升用戶參賽資格的建議
    func getEligibilityImprovementSuggestions(for user: UserProfile) -> [ImprovementSuggestion] {
        var suggestions: [ImprovementSuggestion] = []
        
        // 基於用戶當前狀況給出建議
        if let stats = userStats {
            // 登入天數建議
            if stats.loginDays < 7 {
                suggestions.append(ImprovementSuggestion(
                    type: .loginDays,
                    title: "增加登入天數",
                    description: "連續登入 \(7 - stats.loginDays) 天即可參加更多錦標賽",
                    priority: .high,
                    estimatedTime: "\(7 - stats.loginDays) 天"
                ))
            }
            
            // 代幣建議
            if stats.tokenBalance < 1000 {
                suggestions.append(ImprovementSuggestion(
                    type: .tokens,
                    title: "累積更多代幣",
                    description: "完成每日任務或進行交易可獲得代幣",
                    priority: .medium,
                    estimatedTime: "1-2 週"
                ))
            }
            
            // 投資經驗建議
            if stats.totalTrades < 10 {
                suggestions.append(ImprovementSuggestion(
                    type: .experience,
                    title: "增加投資經驗",
                    description: "進行更多模擬交易來累積投資經驗",
                    priority: .medium,
                    estimatedTime: "隨時可開始"
                ))
            }
            
            // 績效建議
            if stats.averageReturn < 0 {
                suggestions.append(ImprovementSuggestion(
                    type: .performance,
                    title: "改善投資績效",
                    description: "學習投資策略，提升投資報酬率",
                    priority: .low,
                    estimatedTime: "持續改進"
                ))
            }
        }
        
        return suggestions.sorted { $0.priority.rawValue > $1.priority.rawValue }
    }
    
    // MARK: - 私有檢查方法
    
    private func checkLoginDays(user: UserProfile, tournament: Tournament) async -> RequirementCheck {
        // 計算用戶連續登入天數
        let loginDays = await calculateLoginDays(user: user)
        let requiredDays = getRequiredLoginDays(for: tournament)
        
        return RequirementCheck(
            passed: loginDays >= requiredDays,
            required: requiredDays,
            current: loginDays
        )
    }
    
    private func checkTokenBalance(user: UserProfile, tournament: Tournament) async -> RequirementCheck {
        do {
            let balance = try await supabaseService.fetchWalletBalance()
            let requiredTokens = tournament.entryFee
            
            return RequirementCheck(
                passed: balance >= requiredTokens,
                required: Int(requiredTokens),
                current: Int(balance)
            )
        } catch {
            // 如果無法獲取餘額，假設不足
            return RequirementCheck(
                passed: false,
                required: Int(tournament.entryFee),
                current: 0
            )
        }
    }
    
    private func checkInvestmentExperience(user: UserProfile, tournament: Tournament) -> RequirementCheck {
        let totalTrades = portfolioManager.tradingRecords.count
        let requiredTrades = getRequiredTrades(for: tournament)
        
        return RequirementCheck(
            passed: totalTrades >= requiredTrades,
            required: requiredTrades,
            current: totalTrades
        )
    }
    
    private func checkAgeRequirement(user: UserProfile, tournament: Tournament) -> RequirementCheck {
        // 模擬年齡檢查（實際應該從用戶資料取得）
        let userAge = 25 // 預設年齡
        let requiredAge = 18 // 大部分錦標賽要求
        
        return RequirementCheck(
            passed: userAge >= requiredAge,
            required: requiredAge,
            current: userAge
        )
    }
    
    private func checkParticipationLimit(user: UserProfile, tournament: Tournament) async -> RequirementCheck {
        // 檢查用戶參加同類型錦標賽的次數
        let participationCount = await getParticipationCount(user: user, tournamentType: tournament.type)
        let limit = getParticipationLimit(for: tournament.type)
        
        return RequirementCheck(
            passed: participationCount < limit,
            required: limit,
            current: participationCount
        )
    }
    
    private func checkSpecialRequirements(user: UserProfile, tournament: Tournament) -> SpecialRequirementCheck {
        // 檢查特殊要求（如 VIP 會員、特定成就等）
        switch tournament.type {
        case .yearly:
            // 年度錦標賽可能需要特殊資格
            return SpecialRequirementCheck(
                passed: true, // 暫時都通過
                requirement: "年度會員資格"
            )
        case .special:
            // 特別賽事可能有特殊要求
            return SpecialRequirementCheck(
                passed: portfolioManager.tradingRecords.count >= 50,
                requirement: "至少 50 筆交易經驗"
            )
        default:
            return SpecialRequirementCheck(passed: true, requirement: "無特殊要求")
        }
    }
    
    private func checkRegistrationDeadline(tournament: Tournament) -> RequirementCheck {
        let now = Date()
        let registrationDeadline = Calendar.current.date(byAdding: .hour, value: -1, to: tournament.startDate) ?? tournament.startDate
        
        return RequirementCheck(
            passed: now < registrationDeadline,
            required: 0,
            current: now < registrationDeadline ? 1 : 0
        )
    }
    
    private func checkTournamentCapacity(tournament: Tournament) -> CapacityCheck {
        let currentParticipants = tournament.currentParticipants
        let maxParticipants = tournament.maxParticipants
        let occupancyRate = Double(currentParticipants) / Double(maxParticipants)
        
        return CapacityCheck(
            passed: currentParticipants < maxParticipants,
            isNearFull: occupancyRate > 0.9,
            current: currentParticipants,
            maximum: maxParticipants
        )
    }
    
    // MARK: - 輔助方法
    
    private func calculateLoginDays(user: UserProfile) async -> Int {
        // 模擬計算連續登入天數
        let daysSinceRegistration = Calendar.current.dateComponents([.day], from: user.createdAt, to: Date()).day ?? 0
        return min(daysSinceRegistration, 30) // 最多30天
    }
    
    private func getRequiredLoginDays(for tournament: Tournament) -> Int {
        switch tournament.type {
        case .daily: return 1
        case .weekly: return 3
        case .monthly: return 7
        case .quarterly: return 14
        case .yearly: return 30
        case .annual: return 60
        case .special: return 10
        case .custom: return 5
        }
    }
    
    private func getRequiredTrades(for tournament: Tournament) -> Int {
        switch tournament.type {
        case .daily: return 1
        case .weekly: return 5
        case .monthly: return 10
        case .quarterly: return 25
        case .yearly: return 50
        case .annual: return 100
        case .special: return 20
        case .custom: return 15
        }
    }
    
    private func getParticipationCount(user: UserProfile, tournamentType: TournamentType) async -> Int {
        // 模擬查詢參加次數
        return Int.random(in: 0...3)
    }
    
    private func getParticipationLimit(for type: TournamentType) -> Int {
        switch type {
        case .daily: return 1 // 每日只能參加一次
        case .weekly: return 2
        case .monthly: return 3
        case .quarterly: return 5
        case .yearly: return 1
        case .annual: return 1 // 年度賽事只能參加一次
        case .special: return 1
        case .custom: return 3 // 自訂賽事可參加3次
        }
    }
    
    private func calculateUserStats() async -> UserEligibilityStats {
        let records = portfolioManager.tradingRecords
        let totalTrades = records.count
        let totalVolume = records.reduce(0) { $0 + $1.totalAmount }
        let averageReturn = records.isEmpty ? 0 : records.compactMap { $0.realizedGainLossPercent }.reduce(0, +) / Double(records.count)
        
        do {
            let tokenBalance = try await supabaseService.fetchWalletBalance()
            
            return UserEligibilityStats(
                loginDays: 15, // 模擬數據
                tokenBalance: tokenBalance,
                totalTrades: totalTrades,
                totalVolume: totalVolume,
                averageReturn: averageReturn,
                winRate: calculateWinRate(from: records),
                accountAge: 30 // 模擬數據
            )
        } catch {
            return UserEligibilityStats(
                loginDays: 15,
                tokenBalance: 1000,
                totalTrades: totalTrades,
                totalVolume: totalVolume,
                averageReturn: averageReturn,
                winRate: calculateWinRate(from: records),
                accountAge: 30
            )
        }
    }
    
    private func calculateWinRate(from records: [TradingRecord]) -> Double {
        let sellRecords = records.filter { $0.type == .sell }
        let profitableRecords = sellRecords.filter { ($0.realizedGainLoss ?? 0) > 0 }
        
        return sellRecords.isEmpty ? 0 : Double(profitableRecords.count) / Double(sellRecords.count) * 100
    }
    
    private func generateEligibilityMessage(isEligible: Bool, requirements: [EligibilityRequirement], warnings: [String]) -> String {
        if isEligible {
            var message = "✅ 您符合參加此錦標賽的所有條件！"
            if !warnings.isEmpty {
                message += "\n\n⚠️ 注意事項：\n" + warnings.joined(separator: "\n")
            }
            return message
        } else {
            var message = "❌ 您尚不符合參加此錦標賽的條件：\n\n"
            for requirement in requirements {
                message += "• \(requirement.description)\n"
            }
            return message
        }
    }
    
    private func loadUserStats() {
        Task {
            userStats = await calculateUserStats()
        }
    }
}

// MARK: - 數據模型

struct EligibilityResult {
    let tournamentId: UUID
    let isEligible: Bool
    let failedRequirements: [EligibilityRequirement]
    let warnings: [String]
    let message: String
    
    init(tournamentId: UUID, isEligible: Bool, failedRequirements: [EligibilityRequirement], warnings: [String] = [], message: String) {
        self.tournamentId = tournamentId
        self.isEligible = isEligible
        self.failedRequirements = failedRequirements
        self.warnings = warnings
        self.message = message
    }
}

enum EligibilityRequirement {
    case notLoggedIn
    case insufficientLoginDays(required: Int, current: Int)
    case insufficientTokens(required: Int, current: Int)
    case insufficientExperience(required: Int, current: Int)
    case ageRestriction(required: Int, current: Int)
    case participationLimitReached(limit: Int)
    case specialRequirementNotMet(requirement: String)
    case registrationClosed
    case tournamentFull
    
    var description: String {
        switch self {
        case .notLoggedIn:
            return "需要登入帳號"
        case .insufficientLoginDays(let required, let current):
            return "需要連續登入 \(required) 天（目前：\(current) 天）"
        case .insufficientTokens(let required, let current):
            return "需要 \(required) 代幣（目前：\(current) 代幣）"
        case .insufficientExperience(let required, let current):
            return "需要至少 \(required) 筆交易經驗（目前：\(current) 筆）"
        case .ageRestriction(let required, let current):
            return "年齡需滿 \(required) 歲（目前：\(current) 歲）"
        case .participationLimitReached(let limit):
            return "已達到參加次數上限（\(limit) 次）"
        case .specialRequirementNotMet(let requirement):
            return "不符合特殊要求：\(requirement)"
        case .registrationClosed:
            return "報名已截止"
        case .tournamentFull:
            return "錦標賽名額已滿"
        }
    }
}

struct RequirementCheck {
    let passed: Bool
    let required: Int
    let current: Int
}

struct SpecialRequirementCheck {
    let passed: Bool
    let requirement: String
}

struct CapacityCheck {
    let passed: Bool
    let isNearFull: Bool
    let current: Int
    let maximum: Int
}

struct UserEligibilityStats {
    let loginDays: Int
    let tokenBalance: Double
    let totalTrades: Int
    let totalVolume: Double
    let averageReturn: Double
    let winRate: Double
    let accountAge: Int
}

struct ImprovementSuggestion {
    let type: SuggestionType
    let title: String
    let description: String
    let priority: Priority
    let estimatedTime: String
    
    enum SuggestionType {
        case loginDays, tokens, experience, performance
    }
    
    enum Priority: Int {
        case low = 1, medium = 2, high = 3
        
        var color: Color {
            switch self {
            case .low: return .gray
            case .medium: return .orange
            case .high: return .red
            }
        }
        
        var displayName: String {
            switch self {
            case .low: return "低"
            case .medium: return "中"
            case .high: return "高"
            }
        }
    }
}

// MARK: - SwiftUI 組件

struct TournamentEligibilityView: View {
    let tournament: Tournament
    let user: UserProfile?
    
    @StateObject private var checker = TournamentEligibilityChecker.shared
    @State private var eligibilityResult: EligibilityResult?
    @State private var isLoading = true
    
    var body: some View {
        VStack(spacing: 20) {
            if isLoading {
                ProgressView("檢查參賽資格...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let result = eligibilityResult {
                ScrollView {
                    VStack(spacing: 20) {
                        // 結果概覽
                        resultOverview(result)
                        
                        // 詳細要求
                        if !result.failedRequirements.isEmpty {
                            failedRequirementsView(result.failedRequirements)
                        }
                        
                        // 改進建議
                        if !result.isEligible, let user = user {
                            improvementSuggestionsView(user)
                        }
                        
                        // 操作按鈕
                        actionButtons(result)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("參賽資格檢查")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            checkEligibility()
        }
    }
    
    private func resultOverview(_ result: EligibilityResult) -> some View {
        VStack(spacing: 12) {
            Image(systemName: result.isEligible ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.largeTitle)
                .foregroundColor(result.isEligible ? .green : .red)
            
            Text(result.isEligible ? "符合參賽資格" : "不符合參賽資格")
                .font(.title2)
                .fontWeight(.bold)
            
            Text(result.message)
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private func failedRequirementsView(_ requirements: [EligibilityRequirement]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("需要改善的項目")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(requirements.indices, id: \.self) { index in
                HStack {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.red)
                    
                    Text(requirements[index].description)
                        .font(.subheadline)
                    
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.red.opacity(0.3), lineWidth: 1)
        )
    }
    
    private func improvementSuggestionsView(_ user: UserProfile) -> some View {
        let suggestions = checker.getEligibilityImprovementSuggestions(for: user)
        
        return VStack(alignment: .leading, spacing: 12) {
            Text("改善建議")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(suggestions.indices, id: \.self) { index in
                let suggestion = suggestions[index]
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(suggestion.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Text(suggestion.priority.displayName)
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(suggestion.priority.color.opacity(0.2))
                            .foregroundColor(suggestion.priority.color)
                            .cornerRadius(8)
                    }
                    
                    Text(suggestion.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("預估時間：\(suggestion.estimatedTime)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func actionButtons(_ result: EligibilityResult) -> some View {
        VStack(spacing: 12) {
            if result.isEligible {
                Button(action: {
                    // 報名錦標賽
                }) {
                    Text("立即報名參加")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .cornerRadius(12)
                }
            } else {
                Button(action: {
                    checkEligibility()
                }) {
                    Text("重新檢查資格")
                        .font(.headline)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                }
            }
        }
    }
    
    private func checkEligibility() {
        isLoading = true
        Task {
            let result = await checker.checkEligibility(for: tournament, user: user)
            await MainActor.run {
                eligibilityResult = result
                isLoading = false
            }
        }
    }
}

#Preview {
    TournamentEligibilityView(
        tournament: Tournament(
            id: UUID(),
            name: "樣本競賽",
            type: .monthly,
            status: .ongoing,
            startDate: Date(),
            endDate: Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date(),
            description: "範例競賽描述",
            shortDescription: "範例競賽",
            initialBalance: 1000000,
            maxParticipants: 1000,
            currentParticipants: 500,
            entryFee: 0,
            prizePool: 100000,
            riskLimitPercentage: 0.20,
            minHoldingRate: 0.50,
            maxSingleStockRate: 0.30,
            rules: ["範例規則"],
            createdAt: Date(),
            updatedAt: Date(),
            isFeatured: false
        ),
        user: nil
    )
}