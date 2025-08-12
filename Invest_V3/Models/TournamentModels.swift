//
//  TournamentModels.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  錦標賽相關數據模型

import Foundation
import SwiftUI

// MARK: - 錦標賽過濾類型

/// 錦標賽過濾選項，包含所有類型和精選
enum TournamentFilter: String, CaseIterable, Identifiable {
    case featured = "featured"      // 精選錦標賽
    case all = "all"               // 所有錦標賽
    case daily = "daily"           // 日賽
    case weekly = "weekly"         // 週賽
    case monthly = "monthly"       // 月賽
    case quarterly = "quarterly"   // 季賽
    case yearly = "yearly"         // 年賽
    case special = "special"       // 特別賽事
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .featured:
            return "精選"
        case .all:
            return "所有錦標賽"
        case .daily:
            return "日賽"
        case .weekly:
            return "週賽"
        case .monthly:
            return "月賽"
        case .quarterly:
            return "季賽"
        case .yearly:
            return "年賽"
        case .special:
            return "特別賽事"
        }
    }
    
    var iconName: String {
        switch self {
        case .featured:
            return "star.fill"
        case .all:
            return "grid.circle.fill"
        case .daily:
            return "sun.max.fill"
        case .weekly:
            return "calendar.circle.fill"
        case .monthly:
            return "calendar.badge.clock"
        case .quarterly:
            return "chart.line.uptrend.xyaxis"
        case .yearly:
            return "crown.fill"
        case .special:
            return "bolt.fill"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .featured:
            return .orange
        case .all:
            return .blue
        case .daily:
            return .yellow
        case .weekly:
            return .green
        case .monthly:
            return .blue
        case .quarterly:
            return .purple
        case .yearly:
            return .red
        case .special:
            return .pink
        }
    }
}

// MARK: - 錦標賽類型
enum TournamentType: String, CaseIterable, Identifiable, Codable {
    case daily = "daily"
    case weekly = "weekly"
    case monthly = "monthly"
    case quarterly = "quarterly"
    case yearly = "yearly"
    case annual = "annual"      // 添加缺失的 annual 類型
    case special = "special"
    case custom = "custom"      // 添加缺失的 custom 類型
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .daily:
            return "日賽"
        case .weekly:
            return "週賽"
        case .monthly:
            return "月賽"
        case .quarterly:
            return "季賽"
        case .yearly:
            return "年賽"
        case .annual:
            return "年度賽"
        case .special:
            return "限時賽"
        case .custom:
            return "自訂賽"
        }
    }
    
    var description: String {
        switch self {
        case .daily:
            return "每日競賽，當日開盤至收盤結算"
        case .weekly:
            return "每週競賽，週一開始週末結算"
        case .monthly:
            return "月度競賽，鼓勵積極交易"
        case .quarterly:
            return "季度競賽，中期波段操作"
        case .yearly:
            return "年度競賽，長期策略考驗"
        case .annual:
            return "年度競賽，完整一年期挑戰"
        case .special:
            return "特殊活動，限時快閃競賽"
        case .custom:
            return "自定義競賽，彈性規則設定"
        }
    }
    
    var iconName: String {
        switch self {
        case .daily:
            return "sun.max"
        case .weekly:
            return "calendar"
        case .monthly:
            return "calendar.badge.clock"
        case .quarterly:
            return "chart.line.uptrend.xyaxis"
        case .yearly:
            return "crown"
        case .annual:
            return "crown.fill"
        case .special:
            return "bolt.fill"
        case .custom:
            return "gear"
        }
    }
    
    var duration: String {
        switch self {
        case .daily:
            return "1天"
        case .weekly:
            return "7天"
        case .monthly:
            return "30天"
        case .quarterly:
            return "90天"
        case .yearly:
            return "365天"
        case .annual:
            return "365天"
        case .special:
            return "變動"
        case .custom:
            return "自訂"
        }
    }
}

// MARK: - 錦標賽狀態 (適配數據庫 schema)
enum TournamentStatus: String, CaseIterable, Codable {
    case upcoming = "upcoming"      // 即將開始
    case enrolling = "enrolling"    // 報名中 (內部狀態，數據庫中映射為 upcoming)
    case ongoing = "ongoing"        // 進行中 (對應數據庫的 ongoing)
    case active = "active"          // 活躍中 (別名，映射為 ongoing)
    case finished = "finished"      // 已結束
    case ended = "ended"            // 已結束 (別名，映射為 finished)
    case settling = "settling"      // 結算中 (結算階段，映射為 finished)
    case cancelled = "cancelled"    // 已取消 (內部狀態，數據庫中映射為 finished)
    
    var displayName: String {
        switch self {
        case .upcoming:
            return "即將開始"
        case .enrolling:
            return "報名中"
        case .ongoing:
            return "進行中"
        case .active:
            return "活躍中"
        case .finished:
            return "已結束"
        case .ended:
            return "已結束"
        case .settling:
            return "結算中"
        case .cancelled:
            return "已取消"
        }
    }
    
    var color: Color {
        switch self {
        case .upcoming:
            return .blue
        case .enrolling:
            return .green
        case .ongoing:
            return .orange
        case .active:
            return .orange
        case .finished:
            return .gray
        case .ended:
            return .gray
        case .settling:
            return .purple
        case .cancelled:
            return .red
        }
    }
    
    /// 映射到數據庫兼容的狀態值 (符合 schema 約束: upcoming, ongoing, finished)
    var databaseValue: String {
        switch self {
        case .upcoming, .enrolling:
            return "upcoming"     // enrolling 在數據庫中存儲為 upcoming
        case .ongoing, .active:
            return "ongoing"      // active 在數據庫中存儲為 ongoing
        case .finished, .ended, .settling, .cancelled:
            return "finished"     // 其他結束狀態在數據庫中存儲為 finished
        }
    }
    
    /// 從數據庫值創建狀態 (配合業務邏輯判斷實際狀態)
    static func fromDatabaseValue(_ dbValue: String, startDate: Date, endDate: Date) -> TournamentStatus {
        let now = Date()
        
        switch dbValue {
        case "upcoming":
            // 根據時間判斷是即將開始還是報名中
            return now < startDate ? .upcoming : .enrolling
        case "ongoing":
            return .ongoing
        case "finished":
            // 這裡無法區分是正常結束還是取消，默認為正常結束
            // 如果需要區分，可以添加額外的字段或者在業務邏輯中處理
            return .finished
        default:
            return .upcoming
        }
    }
    
    var canEnroll: Bool {
        return self == .enrolling
    }
    
    var canParticipate: Bool {
        return self == .ongoing
    }
}

// MARK: - 交易類型 (統一定義，解決類型歧義)
enum TradeSide: String, CaseIterable, Codable {
    case buy = "buy"
    case sell = "sell"
    
    var displayName: String {
        switch self {
        case .buy: return "買入"
        case .sell: return "賣出"
        }
    }
    
    var color: Color {
        switch self {
        case .buy: return .red
        case .sell: return .green
        }
    }
}

// MARK: - 交易狀態 (統一定義)
enum TradeStatus: String, CaseIterable, Codable {
    case executed = "executed"
    case cancelled = "cancelled"
    case pending = "pending"
    
    var displayName: String {
        switch self {
        case .executed: return "已執行"
        case .cancelled: return "已取消"
        case .pending: return "待執行"
        }
    }
}

// MARK: - 活動類型 (統一定義，解決類型歧義)
enum ActivityType: String, CaseIterable, Codable {
    case trade = "trade"
    case rankChange = "rank_change"
    case elimination = "elimination"
    case milestone = "milestone"
    case violation = "violation"
    case achievement = "achievement"
    case groupJoin = "group_join"
    
    var icon: String {
        switch self {
        case .trade:
            return "arrow.left.arrow.right"
        case .rankChange:
            return "arrow.up.arrow.down"
        case .elimination:
            return "xmark.circle"
        case .milestone:
            return "flag.checkered"
        case .violation:
            return "exclamationmark.triangle"
        case .achievement:
            return "trophy.fill"
        case .groupJoin:
            return "person.2.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .trade:
            return .brandBlue
        case .rankChange:
            return .brandGreen
        case .elimination:
            return .danger
        case .milestone:
            return .warning
        case .violation:
            return .brandOrange
        case .achievement:
            return .yellow
        case .groupJoin:
            return .green
        }
    }
}

// MARK: - 成就稀有度 (統一定義，解決類型歧義)
enum AchievementRarity: String, CaseIterable, Codable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    case mythic = "mythic"
    
    var displayName: String {
        switch self {
        case .common:
            return "普通"
        case .rare:
            return "稀有"
        case .epic:
            return "史詩"
        case .legendary:
            return "傳奇"
        case .mythic:
            return "神話"
        }
    }
    
    var color: Color {
        switch self {
        case .common:
            return Color(hex: "#9E9E9E")
        case .rare:
            return Color(hex: "#2196F3")
        case .epic:
            return Color(hex: "#9C27B0")
        case .legendary:
            return Color(hex: "#FF9800")
        case .mythic:
            return Color(hex: "#F44336")
        }
    }
}

// MARK: - 報酬率計算方式
enum ReturnMetric: String, CaseIterable, Codable {
    case twr = "twr"           // Time-Weighted Return 時間加權報酬率
    case simple = "simple"     // Simple Return 簡單報酬率
    case mwr = "mwr"           // Money-Weighted Return 資金加權報酬率
    
    var displayName: String {
        switch self {
        case .twr:
            return "時間加權報酬率"
        case .simple:
            return "簡單報酬率"
        case .mwr:
            return "資金加權報酬率"
        }
    }
    
    var description: String {
        switch self {
        case .twr:
            return "消除資金流入流出對績效的影響，適合比較投資能力"
        case .simple:
            return "簡單的期末與期初價值比較，計算簡單"
        case .mwr:
            return "考慮資金流入流出時間，反映實際投資效果"
        }
    }
}

// MARK: - 重置模式
enum ResetMode: String, CaseIterable, Codable {
    case monthly = "monthly"
    case quarterly = "quarterly" 
    case yearly = "yearly"
    case never = "never"
    
    var displayName: String {
        switch self {
        case .monthly:
            return "月度重置"
        case .quarterly:
            return "季度重置"
        case .yearly:
            return "年度重置"
        case .never:
            return "不重置"
        }
    }
}

// MARK: - 錦標賽模型（適配數據庫 schema）
struct Tournament: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let type: TournamentType
    let status: TournamentStatus
    let startDate: Date             // 對應 start_date  
    let endDate: Date               // 對應 end_date
    let description: String
    let shortDescription: String    // 對應 short_description
    
    // 資金設定（對應數據庫欄位）
    let initialBalance: Double      // 對應 initial_balance
    let entryFee: Double           // 對應 entry_fee (數字型態)
    let prizePool: Double          // 對應 prize_pool
    
    // 錦標賽設定
    let maxParticipants: Int       // 對應 max_participants
    let currentParticipants: Int   // 對應 current_participants
    let isFeatured: Bool           // 對應 is_featured
    let createdBy: UUID?           // 對應 created_by
    
    // 交易規則（對應數據庫欄位）
    let riskLimitPercentage: Double  // 對應 risk_limit_percentage
    let minHoldingRate: Double       // 對應 min_holding_rate
    let maxSingleStockRate: Double   // 對應 max_single_stock_rate
    let rules: [String]              // 對應 rules array
    
    // 時間戳
    let createdAt: Date            // 對應 created_at
    let updatedAt: Date            // 對應 updated_at
    
    // 便利計算屬性（保持與舊版本的兼容性）
    var entryCapital: Double {
        return initialBalance  // 對應新的 initialBalance
    }
    
    var startingCapital: Double {
        return initialBalance
    }
    
    var feeTokens: Int {
        return Int(entryFee)  // 將 entry_fee 轉換為代幣數量
    }
    
    var startsAt: Date {
        return startDate  // 向後兼容
    }
    
    var endsAt: Date {
        return endDate    // 向後兼容
    }
    
    // 向後兼容的計算屬性 - 這些字段不在 schema 中，但保持 API 兼容性
    var returnMetric: String {
        return "twr"  // 預設使用時間加權報酬率 (Time-Weighted Return)
    }
    
    var resetMode: String {
        // 基於錦標賽類型提供重置模式
        switch type {
        case .daily:
            return "daily"
        case .weekly:
            return "weekly"
        case .monthly:
            return "monthly"
        case .quarterly:
            return "quarterly"
        case .annual:
            return "annual"
        case .custom:
            return "custom"
        }
    }
    
    var participationPercentage: Double {
        guard maxParticipants > 0 else { return 0 }
        return min(100.0, Double(currentParticipants) / Double(maxParticipants) * 100.0)
    }
    
    var isEnrollmentFull: Bool {
        return currentParticipants >= maxParticipants
    }
    
    var daysRemaining: Int {
        let calendar = Calendar.current
        let now = Date()
        
        switch status {
        case .enrolling, .upcoming:
            return calendar.dateComponents([.day], from: now, to: startDate).day ?? 0
        case .ongoing:
            return calendar.dateComponents([.day], from: now, to: endDate).day ?? 0
        case .finished, .cancelled:
            return 0
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, type, status, description, rules
        case shortDescription = "short_description"
        case startDate = "start_date"
        case endDate = "end_date"
        case initialBalance = "initial_balance"
        case entryFee = "entry_fee"
        case maxParticipants = "max_participants"
        case currentParticipants = "current_participants"
        case prizePool = "prize_pool"
        case riskLimitPercentage = "risk_limit_percentage"
        case minHoldingRate = "min_holding_rate"
        case maxSingleStockRate = "max_single_stock_rate"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isFeatured = "is_featured"
        case createdBy = "created_by"
    }
    
    // MARK: - 計算屬性
    var isJoinable: Bool {
        return status == .upcoming && currentParticipants < maxParticipants
    }
    
    var isActive: Bool {
        return status == .ongoing
    }
    
    var timeRemaining: String {
        let now = Date()
        let targetDate = status == .upcoming ? startDate : endDate
        let timeInterval = targetDate.timeIntervalSince(now)
        
        if timeInterval <= 0 {
            return "已結束"
        }
        
        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval.truncatingRemainder(dividingBy: 86400)) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        
        if days > 0 {
            return "\(days)天\(hours)小時"
        } else if hours > 0 {
            return "\(hours)小時\(minutes)分鐘"
        } else {
            return "\(minutes)分鐘"
        }
    }
    
    var participantsFull: Bool {
        return currentParticipants >= maxParticipants
    }
    
    var participantsPercentage: Double {
        return maxParticipants > 0 ? Double(currentParticipants) / Double(maxParticipants) : 0
    }
    
    // MARK: - 狀態自動更新機制
    
    /// 根據當前時間自動計算應該的狀態
    var computedStatus: TournamentStatus {
        let now = Date()
        
        // 如果已經手動設置為取消，保持取消狀態
        if status == .cancelled {
            return .cancelled
        }
        
        // 基於時間的狀態判斷
        if now < startDate {
            // 當前時間在開始時間之前
            if status == .enrolling {
                return .enrolling  // 如果設置為報名中，保持報名中
            } else {
                return .upcoming   // 否則為即將開始
            }
        } else if now >= startDate && now <= endDate {
            // 當前時間在錦標賽進行期間
            return .ongoing
        } else {
            // 當前時間在結束時間之後
            return .finished
        }
    }
    
    /// 檢查當前狀態是否需要更新
    var needsStatusUpdate: Bool {
        return status != computedStatus
    }
    
    /// 獲取狀態更新後的錦標賽實例
    func withUpdatedStatus() -> Tournament {
        let newStatus = computedStatus
        
        return Tournament(
            id: id,
            name: name,
            type: type,
            status: newStatus,
            startDate: startDate,
            endDate: endDate,
            description: description,
            shortDescription: shortDescription,
            initialBalance: initialBalance,
            entryFee: entryFee,
            prizePool: prizePool,
            maxParticipants: maxParticipants,
            currentParticipants: currentParticipants,
            isFeatured: isFeatured,
            createdBy: createdBy,
            riskLimitPercentage: riskLimitPercentage,
            minHoldingRate: minHoldingRate,
            maxSingleStockRate: maxSingleStockRate,
            rules: rules,
            createdAt: createdAt,
            updatedAt: Date() // 更新時間
        )
    }
    
    // MARK: - 時區標準化處理
    
    /// 使用UTC時區的開始日期
    var startDateUTC: Date {
        return startDate
    }
    
    /// 使用UTC時區的結束日期
    var endDateUTC: Date {
        return endDate
    }
    
    /// 基旼UTC時間的狀態計算
    var computedStatusUTC: TournamentStatus {
        let nowUTC = Date()
        
        if status == .cancelled {
            return .cancelled
        }
        
        if nowUTC < startDateUTC {
            return status == .enrolling ? .enrolling : .upcoming
        } else if nowUTC >= startDateUTC && nowUTC <= endDateUTC {
            return .ongoing
        } else {
            return .finished
        }
    }
    
    // MARK: - 增強的時間計算
    
    /// 精確的剩餘時間（秒）
    var exactTimeRemaining: TimeInterval {
        let now = Date()
        let targetDate = (computedStatusUTC == .upcoming || computedStatusUTC == .enrolling) ? startDateUTC : endDateUTC
        return max(0, targetDate.timeIntervalSince(now))
    }
    
    /// 格式化的時間顯示（包含秒）
    var preciseTimeRemaining: String {
        let timeInterval = exactTimeRemaining
        
        if timeInterval <= 0 {
            return "已結束"
        }
        
        let days = Int(timeInterval) / 86400
        let hours = Int(timeInterval.truncatingRemainder(dividingBy: 86400)) / 3600
        let minutes = Int(timeInterval.truncatingRemainder(dividingBy: 3600)) / 60
        let seconds = Int(timeInterval.truncatingRemainder(dividingBy: 60))
        
        if days > 0 {
            return "\(days)天\(hours)小時\(minutes)分鐘"
        } else if hours > 0 {
            return "\(hours)小時\(minutes)分鐘\(seconds)秒"
        } else if minutes > 0 {
            return "\(minutes)分鐘\(seconds)秒"
        } else {
            return "\(seconds)秒"
        }
    }
    
    // MARK: - 邊界條件處理
    
    /// 是否在狀態轉換的關鍵時刻（前後30秒）
    var isAtTransitionPoint: Bool {
        let now = Date()
        let buffer: TimeInterval = 30 // 30秒緩衝
        
        // 檢查是否接近開始時間
        let timesToStart = startDate.timeIntervalSince(now)
        if timesToStart > -buffer && timesToStart < buffer {
            return true
        }
        
        // 檢查是否接近結束時間
        let timeToEnd = endDate.timeIntervalSince(now)
        if timeToEnd > -buffer && timeToEnd < buffer {
            return true
        }
        
        return false
    }
    
    /// 獲取狀態轉換的提醒信息
    var transitionReminder: String? {
        let now = Date()
        let timesToStart = startDate.timeIntervalSince(now)
        let timeToEnd = endDate.timeIntervalSince(now)
        
        // 即將開始的提醒
        if timesToStart > 0 && timesToStart <= 300 { // 5分鐘內
            let minutes = Int(timesToStart / 60)
            return "錦標賽將在\(minutes)分鐘後開始"
        }
        
        // 即將結束的提醒
        if timeToEnd > 0 && timeToEnd <= 300 { // 5分鐘內
            let minutes = Int(timeToEnd / 60)
            return "錦標賽將在\(minutes)分鐘後結束"
        }
        
        return nil
    }
}

// MARK: - 錦標賽參與者模型（對應 tournament_participants 表）
struct TournamentParticipantRecord: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let userName: String
    let userAvatar: String?
    let currentRank: Int
    let previousRank: Int
    let virtualBalance: Double
    let initialBalance: Double
    let returnRate: Double
    let totalTrades: Int
    let winRate: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    let isEliminated: Bool
    let eliminationReason: String?
    let joinedAt: Date
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id, userName, userAvatar, isEliminated, eliminationReason
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case currentRank = "current_rank"
        case previousRank = "previous_rank"
        case virtualBalance = "virtual_balance"
        case initialBalance = "initial_balance"
        case returnRate = "return_rate"
        case totalTrades = "total_trades"
        case winRate = "win_rate"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
        case joinedAt = "joined_at"
        case lastUpdated = "last_updated"
    }
    
    // 計算屬性
    var profit: Double {
        return virtualBalance - initialBalance
    }
    
    var rankChange: Int {
        return previousRank - currentRank
    }
}

// MARK: - 錦標賽成員模型（舊版兼容）
struct TournamentMember: Identifiable, Codable {
    let tournamentId: UUID
    let userId: UUID
    let joinedAt: Date
    let status: MemberStatus
    let eliminationReason: String?
    
    var id: String {
        return "\(tournamentId)-\(userId)"
    }
    
    enum MemberStatus: String, CaseIterable, Codable {
        case active = "active"
        case eliminated = "eliminated"
        case withdrawn = "withdrawn"
        
        var displayName: String {
            switch self {
            case .active:
                return "參賽中"
            case .eliminated:
                return "已淘汰"
            case .withdrawn:
                return "已退出"
            }
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case joinedAt = "joined_at"
        case status
        case eliminationReason = "elimination_reason"
    }
}

// MARK: - 錦標賽投資組合模型
struct TournamentPortfolioV2: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    
    // 資產狀況
    let cashBalance: Double
    let equityValue: Double
    let totalAssets: Double     // 由數據庫計算
    
    // 績效指標
    let initialBalance: Double
    let totalReturn: Double     // 由數據庫計算
    let returnPercentage: Double // 由數據庫計算
    
    // 統計資訊
    let totalTrades: Int
    let winningTrades: Int
    let maxDrawdown: Double
    
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case cashBalance = "cash_balance"
        case equityValue = "equity_value"
        case totalAssets = "total_assets"
        case initialBalance = "initial_balance"
        case totalReturn = "total_return"
        case returnPercentage = "return_percentage"
        case totalTrades = "total_trades"
        case winningTrades = "winning_trades"
        case maxDrawdown = "max_drawdown"
        case lastUpdated = "last_updated"
    }
    
    // 計算屬性
    var winRate: Double {
        guard totalTrades > 0 else { return 0 }
        return Double(winningTrades) / Double(totalTrades)
    }
    
    var cashPercentage: Double {
        guard totalAssets > 0 else { return 0 }
        return (cashBalance / totalAssets) * 100
    }
    
    var equityPercentage: Double {
        guard totalAssets > 0 else { return 0 }
        return (equityValue / totalAssets) * 100
    }
}

// MARK: - 錦標賽交易模型（對應 tournament_trading_records 表）
struct TournamentTradeRecord: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let tournamentId: UUID?
    let symbol: String
    let stockName: String
    let type: TradeSide         // buy/sell
    let shares: Double
    let price: Double
    let timestamp: Date
    let totalAmount: Double
    let fee: Double
    let netAmount: Double
    let averageCost: Double?
    let realizedGainLoss: Double?
    let realizedGainLossPercent: Double?
    let notes: String?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, type, shares, price, timestamp, fee, notes
        case userId = "user_id"
        case tournamentId = "tournament_id"
        case stockName = "stock_name"
        case totalAmount = "total_amount"
        case netAmount = "net_amount"
        case averageCost = "average_cost"
        case realizedGainLoss = "realized_gain_loss"
        case realizedGainLossPercent = "realized_gain_loss_percent"
    }
}

// MARK: - 錦標賽交易模型（舊版兼容）
struct TournamentTrade: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let symbol: String
    let side: TradeSide         // 使用統一定義的 TradeSide
    let qty: Double
    let price: Double
    let amount: Double          // 由數據庫計算
    let fees: Double
    let netAmount: Double       // 由數據庫計算
    let realizedPnl: Double?
    let realizedPnlPercentage: Double?
    let status: TradeStatus     // 使用統一定義的 TradeStatus
    let executedAt: Date
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case symbol, side, qty, price, amount, fees
        case netAmount = "net_amount"
        case realizedPnl = "realized_pnl"
        case realizedPnlPercentage = "realized_pnl_percentage"
        case status
        case executedAt = "executed_at"
        case createdAt = "created_at"
    }
}

// MARK: - 錦標賽持倉模型（對應 tournament_positions 表）  
struct TournamentPositionRecord: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let symbol: String
    let stockName: String
    let quantity: Int
    let averageCost: Double
    let currentPrice: Double
    let marketValue: Double
    let unrealizedGainLoss: Double
    let unrealizedGainLossPercent: Double
    let firstBuyDate: Date?
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, quantity
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case stockName = "stock_name"
        case averageCost = "average_cost"
        case currentPrice = "current_price"
        case marketValue = "market_value"
        case unrealizedGainLoss = "unrealized_gain_loss"
        case unrealizedGainLossPercent = "unrealized_gain_loss_percent"
        case firstBuyDate = "first_buy_date"
        case lastUpdated = "last_updated"
    }
}

// MARK: - 錦標賽持倉模型（舊版兼容）
struct TournamentPosition: Identifiable, Codable {
    let tournamentId: UUID
    let userId: UUID
    let symbol: String
    let qty: Double
    let avgCost: Double
    let totalCost: Double           // 由數據庫計算
    let currentPrice: Double
    let marketValue: Double         // 由數據庫計算
    let unrealizedPnl: Double       // 由數據庫計算
    let unrealizedPnlPercentage: Double // 由數據庫計算
    let firstBuyAt: Date?
    let lastUpdated: Date
    
    var id: String {
        return "\(tournamentId)-\(userId)-\(symbol)"
    }
    
    enum CodingKeys: String, CodingKey {
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case symbol, qty
        case avgCost = "avg_cost"
        case totalCost = "total_cost"
        case currentPrice = "current_price"
        case marketValue = "market_value"
        case unrealizedPnl = "unrealized_pnl"
        case unrealizedPnlPercentage = "unrealized_pnl_percentage"
        case firstBuyAt = "first_buy_at"
        case lastUpdated = "last_updated"
    }
}

// MARK: - 錦標賽快照模型
struct TournamentSnapshot: Identifiable, Codable {
    let tournamentId: UUID
    let userId: UUID
    let asOfDate: Date
    
    // 資產快照
    let cash: Double
    let positionValue: Double
    let totalAssets: Double
    
    // 績效快照
    let returnRate: Double
    let dailyReturn: Double?
    let cumulativeReturn: Double?
    
    // 風險指標
    let maxDD: Double?
    let volatility: Double?
    let sharpe: Double?
    
    // 交易統計
    let totalTrades: Int
    let winningTrades: Int
    let winRate: Double
    
    // 排名資訊
    let rank: Int?
    let totalParticipants: Int?
    let percentile: Double?
    
    let createdAt: Date
    
    var id: String {
        return "\(tournamentId)-\(userId)-\(asOfDate.timeIntervalSince1970)"
    }
    
    enum CodingKeys: String, CodingKey {
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case asOfDate = "as_of_date"
        case cash
        case positionValue = "position_value"
        case totalAssets = "total_assets"
        case returnRate = "return_rate"
        case dailyReturn = "daily_return"
        case cumulativeReturn = "cumulative_return"
        case maxDD = "max_dd"
        case volatility, sharpe
        case totalTrades = "total_trades"
        case winningTrades = "winning_trades"
        case winRate = "win_rate"
        case rank
        case totalParticipants = "total_participants"
        case percentile
        case createdAt = "created_at"
    }
}

// MARK: - 錦標賽排行榜條目
struct TournamentLeaderboardEntry: Identifiable, Codable {
    let tournamentId: UUID
    let userId: UUID
    let userName: String?
    let userAvatar: String?
    let totalAssets: Double
    let returnPercentage: Double
    let totalTrades: Int
    let lastUpdated: Date
    let currentRank: Int
    let totalParticipants: Int
    
    var id: String {
        return "\(tournamentId)-\(userId)"
    }
    
    enum CodingKeys: String, CodingKey {
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case userName = "user_name"
        case userAvatar = "user_avatar"
        case totalAssets = "total_assets"
        case returnPercentage = "return_percentage"
        case totalTrades = "total_trades"
        case lastUpdated = "last_updated"
        case currentRank = "current_rank"
        case totalParticipants = "total_participants"
    }
    
    // 計算屬性
    var profit: Double {
        return totalAssets - 1000000 // 假設初始資金為100萬
    }
    
    var rankingTier: RankingTier {
        let percentile = Double(currentRank) / Double(totalParticipants) * 100
        
        if percentile <= 10 {
            return .gold
        } else if percentile <= 25 {
            return .silver
        } else if percentile <= 50 {
            return .bronze
        } else {
            return .normal
        }
    }
    
    enum RankingTier {
        case gold, silver, bronze, normal
        
        var color: Color {
            switch self {
            case .gold: return Color.yellow
            case .silver: return Color.gray
            case .bronze: return Color.brown
            case .normal: return Color.primary
            }
        }
        
        var icon: String {
            switch self {
            case .gold: return "crown.fill"
            case .silver: return "medal.fill"
            case .bronze: return "medal"
            case .normal: return "person.fill"
            }
        }
    }
}

// MARK: - 錦標賽參賽者（舊版本兼容）
struct TournamentParticipant: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let userName: String
    let userAvatar: String?
    let currentRank: Int
    let previousRank: Int
    let virtualBalance: Double
    let initialBalance: Double
    let returnRate: Double
    let totalTrades: Int
    let winRate: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    let isEliminated: Bool
    let eliminationReason: String?
    let joinedAt: Date
    let lastUpdated: Date
    
    enum CodingKeys: String, CodingKey {
        case id, userName, userAvatar, isEliminated, eliminationReason
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case currentRank = "current_rank"
        case previousRank = "previous_rank"
        case virtualBalance = "virtual_balance"
        case initialBalance = "initial_balance"
        case returnRate = "return_rate"
        case totalTrades = "total_trades"
        case winRate = "win_rate"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
        case joinedAt = "joined_at"
        case lastUpdated = "last_updated"
    }
    
    // MARK: - 計算屬性
    var profit: Double {
        return virtualBalance - initialBalance
    }
    
    var rankChange: Int {
        return previousRank - currentRank
    }
    
    var rankChangeIcon: String {
        if rankChange > 0 {
            return "arrow.up"
        } else if rankChange < 0 {
            return "arrow.down"
        } else {
            return "minus"
        }
    }
    
    var rankChangeColor: Color {
        if rankChange > 0 {
            return .success
        } else if rankChange < 0 {
            return .danger
        } else {
            return .gray600
        }
    }
    
    var performanceLevel: PerformanceLevel {
        if returnRate >= 0.20 {
            return .excellent
        } else if returnRate >= 0.10 {
            return .good
        } else if returnRate >= 0.05 {
            return .average
        } else if returnRate >= 0 {
            return .below
        } else {
            return .poor
        }
    }
}

// MARK: - 績效等級
enum PerformanceLevel: String, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case average = "average"
    case below = "below"
    case poor = "poor"
    
    var displayName: String {
        switch self {
        case .excellent:
            return "卓越"
        case .good:
            return "優秀"
        case .average:
            return "一般"
        case .below:
            return "待改進"
        case .poor:
            return "不佳"
        }
    }
    
    var color: Color {
        switch self {
        case .excellent:
            return .success
        case .good:
            return .brandGreen
        case .average:
            return .warning
        case .below:
            return .brandOrange
        case .poor:
            return .danger
        }
    }
    
    var icon: String {
        switch self {
        case .excellent:
            return "star.fill"
        case .good:
            return "star.circle.fill"
        case .average:
            return "star.circle"
        case .below:
            return "star"
        case .poor:
            return "star.slash"
        }
    }
}

// MARK: - 錦標賽活動記錄（對應 tournament_activities 表）
struct TournamentActivityRecord: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let userName: String
    let activityType: ActivityType
    let description: String
    let amount: Double?
    let symbol: String?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, description, amount, symbol, timestamp
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case userName = "user_name"
        case activityType = "activity_type"
    }
}

// MARK: - 錦標賽排名快照（對應 tournament_ranking_snapshots 表）
struct TournamentRankingSnapshot: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let snapshotDate: Date
    let rank: Int
    let virtualBalance: Double
    let returnRate: Double
    let dailyChange: Double
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, rank
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case snapshotDate = "snapshot_date"
        case virtualBalance = "virtual_balance"
        case returnRate = "return_rate"
        case dailyChange = "daily_change"
        case createdAt = "created_at"
    }
}

// MARK: - 成就需求類型
struct AchievementRequirement: Codable {
    let type: String
    let value: Double
    let description: String?
    
    enum CodingKeys: String, CodingKey {
        case type, value, description
    }
}

// MARK: - 錦標賽成就（對應 tournament_achievements 表）
struct TournamentAchievementRecord: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let rarity: AchievementRarity
    let requirements: [AchievementRequirement]  // 修正為可序列化的類型
    let rewardAmount: Int
    let isActive: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity, requirements, isActive
        case rewardAmount = "reward_amount"
        case createdAt = "created_at"
    }
}

// MARK: - 用戶錦標賽成就（對應 user_tournament_achievements 表）
struct UserTournamentAchievement: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let tournamentId: UUID?
    let achievementId: UUID
    let progress: Double
    let isUnlocked: Bool
    let earnedAt: Date?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, progress, isUnlocked
        case userId = "user_id"
        case tournamentId = "tournament_id"
        case achievementId = "achievement_id"
        case earnedAt = "earned_at"
        case createdAt = "created_at"
    }
}

// MARK: - 活動記錄（舊版兼容）
struct TournamentActivity: Identifiable, Codable {
    let id: UUID
    let tournamentId: UUID
    let userId: UUID
    let userName: String
    let activityType: ActivityType  // 使用統一定義的 ActivityType
    let description: String
    let amount: Double?
    let symbol: String?
    let timestamp: Date
    
    enum CodingKeys: String, CodingKey {
        case id, description, amount, symbol, timestamp
        case tournamentId = "tournament_id"
        case userId = "user_id"
        case userName = "user_name"
        case activityType = "activity_type"
    }
}

// MARK: - 公開投資組合
// 注意：此結構依賴於 PortfolioHolding（定義在 Stock.swift 中）
/*
struct PublicPortfolio: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let userName: String
    let tournamentId: UUID
    let holdings: [PortfolioHolding]
    let performance: PerformanceMetrics
    let lastUpdated: Date
    let isPublic: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, holdings, performance, isPublic
        case userId = "user_id"
        case userName = "user_name"
        case tournamentId = "tournament_id"
        case lastUpdated = "last_updated"
    }
}
*/

// MARK: - 績效指標
struct PerformanceMetrics: Codable {
    let totalReturn: Double
    let annualizedReturn: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    let winRate: Double
    let avgHoldingDays: Double
    let diversificationScore: Double
    let riskScore: Double
    let totalTrades: Int
    let profitableTrades: Int
    
    enum CodingKeys: String, CodingKey {
        case totalReturn = "total_return"
        case annualizedReturn = "annualized_return"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
        case winRate = "win_rate"
        case avgHoldingDays = "avg_holding_days"
        case diversificationScore = "diversification_score"
        case riskScore = "risk_score"
        case totalTrades = "total_trades"
        case profitableTrades = "profitable_trades"
    }
}

// MARK: - 個人績效
struct PersonalPerformance: Codable {
    let totalReturn: Double
    let annualizedReturn: Double
    let maxDrawdown: Double
    let sharpeRatio: Double?
    let winRate: Double
    let totalTrades: Int
    let profitableTrades: Int
    let avgHoldingDays: Double
    let riskScore: Double
    let performanceHistory: [PerformancePoint]
    let rankingHistory: [RankingPoint]
    let achievements: [Achievement]
    
    enum CodingKeys: String, CodingKey {
        case totalReturn = "total_return"
        case annualizedReturn = "annualized_return"
        case maxDrawdown = "max_drawdown"
        case sharpeRatio = "sharpe_ratio"
        case winRate = "win_rate"
        case totalTrades = "total_trades"
        case profitableTrades = "profitable_trades"
        case avgHoldingDays = "avg_holding_days"
        case riskScore = "risk_score"
        case performanceHistory = "performance_history"
        case rankingHistory = "ranking_history"
        case achievements
    }
}

// MARK: - 績效歷史點
struct PerformancePoint: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let value: Double
    let returnRate: Double
    
    enum CodingKeys: String, CodingKey {
        case date
        case value
        case returnRate = "return_rate"
    }
}

// MARK: - 排名歷史點
struct RankingPoint: Identifiable, Codable {
    let id = UUID()
    let date: Date
    let rank: Int
    let totalParticipants: Int
    let percentile: Double
    
    enum CodingKeys: String, CodingKey {
        case date
        case rank
        case totalParticipants = "total_participants"
        case percentile
    }
}

// MARK: - 成就
struct Achievement: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let rarity: AchievementRarity   // 使用統一定義的 AchievementRarity
    let earnedAt: Date?
    let progress: Double
    let isUnlocked: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, rarity, progress, isUnlocked
        case earnedAt = "earned_at"
    }
}

// MARK: - 數據庫結構適配幫助類型

/// 錦標賽參與者狀態（對應數據庫約束）
enum TournamentParticipantStatus: String, CaseIterable, Codable {
    case active = "active"
    case eliminated = "eliminated"
    case withdrawn = "withdrawn"
}

/// 交易類型（對應數據庫 type 欄位）
enum TournamentTradeType: String, CaseIterable, Codable {
    case buy = "buy"
    case sell = "sell"
    
    var displayName: String {
        switch self {
        case .buy: return "買入"
        case .sell: return "賣出"
        }
    }
}

/// 錦標賽生命週期狀態
enum TournamentLifecycleState: String, CaseIterable, Codable {
    case upcoming = "upcoming"      // 即將開始
    case active = "ongoing"         // 進行中（映射為 ongoing）
    case ended = "finished"         // 已結束（映射為 finished）
    case settling = "settling"      // 結算中（新增狀態）
    case cancelled = "cancelled"    // 已取消
    
    var displayName: String {
        switch self {
        case .upcoming: return "即將開始"
        case .active: return "進行中"
        case .ended: return "已結束"
        case .settling: return "結算中"
        case .cancelled: return "已取消"
        }
    }
}

/// 錦標賽交易請求模型
struct TournamentTradeRequest: Codable {
    let tournamentId: UUID
    let symbol: String
    let side: TournamentTradeType
    let quantity: Int
    let price: Double
    
    enum CodingKeys: String, CodingKey {
        case symbol, side, quantity, price
        case tournamentId = "tournament_id"
    }
}

/// 錦標賽排名模型
struct TournamentRanking: Identifiable, Codable {
    let userId: UUID
    let rank: Int
    let totalAssets: Double
    let totalReturnPercent: Double
    let totalTrades: Int
    let winRate: Double
    
    var id: UUID { userId }
    
    enum CodingKeys: String, CodingKey {
        case rank
        case userId = "user_id"
        case totalAssets = "total_assets"
        case totalReturnPercent = "total_return_percent"
        case totalTrades = "total_trades"
        case winRate = "win_rate"
    }
}

/// 錦標賽結果模型
struct TournamentResult: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let tournamentId: UUID
    let rank: Int
    let totalAssets: Double
    let returnPercentage: Double
    let reward: TournamentReward?
    let finalizedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, rank, reward
        case userId = "user_id"
        case tournamentId = "tournament_id"
        case totalAssets = "total_assets"
        case returnPercentage = "return_percentage"
        case finalizedAt = "finalized_at"
    }
}

/// 錦標賽獎勵模型
struct TournamentReward: Codable {
    let amount: Double
    let type: RewardType
    let description: String
    
    enum RewardType: String, Codable {
        case cash = "cash"
        case tokens = "tokens"
        case title = "title"
        case achievement = "achievement"
    }
}

/// 錦標賽初始化參數
struct TournamentCreationParameters {
    let name: String
    let description: String
    let startDate: Date
    let endDate: Date
    let entryCapital: Double
    let maxParticipants: Int
    let feeTokens: Int
    let returnMetric: String  // "twr", "absolute" etc
    let resetMode: String     // "monthly", "quarterly" etc
    
    var isValid: Bool {
        return !name.isEmpty &&
               !description.isEmpty &&
               startDate < endDate &&
               entryCapital > 0 &&
               maxParticipants > 0
    }
}

// MARK: - 用戶稱號（舊版兼容）
struct UserTitle: Identifiable, Codable {
    let id: UUID
    let name: String
    let description: String
    let icon: String
    let color: String
    let rarity: TitleRarity
    let requirements: String
    let earnedAt: Date?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description, icon, color, rarity, requirements, isActive
        case earnedAt = "earned_at"
    }
    
    enum TitleRarity: String, CaseIterable, Codable {
        case bronze = "bronze"
        case silver = "silver"
        case gold = "gold"
        case platinum = "platinum"
        case diamond = "diamond"
        
        var displayName: String {
            switch self {
            case .bronze:
                return "銅牌"
            case .silver:
                return "銀牌"
            case .gold:
                return "金牌"
            case .platinum:
                return "白金"
            case .diamond:
                return "鑽石"
            }
        }
        
        var color: Color {
            switch self {
            case .bronze:
                return Color(hex: "#CD7F32")
            case .silver:
                return Color(hex: "#C0C0C0")
            case .gold:
                return Color(hex: "#FFD700")
            case .platinum:
                return Color(hex: "#E5E4E2")
            case .diamond:
                return Color(hex: "#B9F2FF")
            }
        }
    }
}

