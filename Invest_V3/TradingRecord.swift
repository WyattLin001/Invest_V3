//
//  TradingRecord.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//  交易記錄數據模型 - 支持交易歷史追蹤和統計分析
//

import Foundation

// MARK: - 交易類型

/// 交易類型枚舉
enum TradingType: String, CaseIterable, Codable {
    case buy = "buy"
    case sell = "sell"
    
    var displayName: String {
        switch self {
        case .buy:
            return "買進"
        case .sell:
            return "賣出"
        }
    }
    
    var color: String {
        switch self {
        case .buy:
            return "#28A745" // 綠色
        case .sell:
            return "#DC3545" // 紅色
        }
    }
    
    var iconName: String {
        switch self {
        case .buy:
            return "arrow.up.circle.fill"
        case .sell:
            return "arrow.down.circle.fill"
        }
    }
}

// MARK: - 交易記錄模型

/// 交易記錄數據模型
/// 記錄每筆買賣交易的詳細信息，支持損益計算和統計分析
struct TradingRecord: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let symbol: String          // 股票代號
    let stockName: String       // 股票名稱
    let type: TradingType       // 交易類型（買進/賣出）
    let shares: Double          // 交易股數
    let price: Double           // 交易價格
    let timestamp: Date         // 交易時間
    let totalAmount: Double     // 交易總金額（不含手續費）
    let fee: Double            // 手續費
    let netAmount: Double      // 淨金額（含手續費）
    
    // 賣出時的損益相關字段
    let averageCost: Double?    // 平均成本（賣出時）
    let realizedGainLoss: Double? // 已實現損益（賣出時）
    let realizedGainLossPercent: Double? // 已實現損益百分比
    
    // 備註信息
    let notes: String?          // 交易備註
    
    // MARK: - 初始化方法
    
    /// 創建買進交易記錄
    static func createBuyRecord(
        userId: UUID,
        symbol: String,
        stockName: String,
        shares: Double,
        price: Double,
        fee: Double = 0,
        notes: String? = nil
    ) -> TradingRecord {
        let totalAmount = shares * price
        let netAmount = totalAmount + fee
        
        return TradingRecord(
            id: UUID(),
            userId: userId,
            symbol: symbol,
            stockName: stockName,
            type: .buy,
            shares: shares,
            price: price,
            timestamp: Date(),
            totalAmount: totalAmount,
            fee: fee,
            netAmount: netAmount,
            averageCost: nil,
            realizedGainLoss: nil,
            realizedGainLossPercent: nil,
            notes: notes
        )
    }
    
    /// 創建賣出交易記錄
    static func createSellRecord(
        userId: UUID,
        symbol: String,
        stockName: String,
        shares: Double,
        price: Double,
        averageCost: Double,
        fee: Double = 0,
        notes: String? = nil
    ) -> TradingRecord {
        let totalAmount = shares * price
        let netAmount = totalAmount - fee
        let costBasis = shares * averageCost
        let realizedGainLoss = netAmount - costBasis
        let realizedGainLossPercent = costBasis > 0 ? (realizedGainLoss / costBasis) * 100 : 0
        
        return TradingRecord(
            id: UUID(),
            userId: userId,
            symbol: symbol,
            stockName: stockName,
            type: .sell,
            shares: shares,
            price: price,
            timestamp: Date(),
            totalAmount: totalAmount,
            fee: fee,
            netAmount: netAmount,
            averageCost: averageCost,
            realizedGainLoss: realizedGainLoss,
            realizedGainLossPercent: realizedGainLossPercent,
            notes: notes
        )
    }
    
    // MARK: - 計算屬性
    
    /// 手續費率（用於顯示）
    var feeRate: Double {
        guard totalAmount > 0 else { return 0 }
        return (fee / totalAmount) * 100
    }
    
    /// 交易日期（僅日期，不含時間）
    var tradingDate: Date {
        Calendar.current.startOfDay(for: timestamp)
    }
    
    /// 格式化的交易時間
    var formattedTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    /// 格式化的交易日期
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: timestamp)
    }
    
    /// 格式化的完整日期時間
    var formattedDateTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter.string(from: timestamp)
    }
    
    /// 是否有損益（賣出交易才有）
    var hasGainLoss: Bool {
        return type == .sell && realizedGainLoss != nil
    }
    
    /// 損益顏色
    var gainLossColor: String {
        guard let gainLoss = realizedGainLoss else { return "#6C757D" }
        return gainLoss >= 0 ? "#28A745" : "#DC3545"
    }
    
    // MARK: - Codable Keys
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case symbol
        case stockName = "stock_name"
        case type
        case shares
        case price
        case timestamp
        case totalAmount = "total_amount"
        case fee
        case netAmount = "net_amount"
        case averageCost = "average_cost"
        case realizedGainLoss = "realized_gain_loss"
        case realizedGainLossPercent = "realized_gain_loss_percent"
        case notes
    }
}

// MARK: - 交易記錄擴展

extension TradingRecord {
    /// 檢查是否為當日交易
    var isToday: Bool {
        Calendar.current.isDateInToday(timestamp)
    }
    
    /// 檢查是否為本週交易
    var isThisWeek: Bool {
        let calendar = Calendar.current
        let now = Date()
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        return timestamp >= weekAgo
    }
    
    /// 檢查是否為本月交易
    var isThisMonth: Bool {
        let calendar = Calendar.current
        let now = Date()
        let monthAgo = calendar.date(byAdding: .month, value: -1, to: now) ?? now
        return timestamp >= monthAgo
    }
    
    /// 獲取股票顯示名稱（包含代號）
    var displayStockName: String {
        return "\(symbol) \(stockName)"
    }
}

// MARK: - 交易統計模型

/// 交易統計數據
struct TradingStatistics {
    let totalTrades: Int            // 總交易筆數
    let totalVolume: Double         // 總成交金額
    let buyTrades: Int             // 買進筆數
    let sellTrades: Int            // 賣出筆數
    let totalRealizedGainLoss: Double // 總已實現損益
    let totalFees: Double          // 總手續費
    let averageTradeSize: Double   // 平均交易金額
    let winRate: Double           // 勝率（賺錢交易比例）
    
    // 時間統計
    let todayTrades: Int          // 今日交易
    let weekTrades: Int           // 本週交易
    let monthTrades: Int          // 本月交易
    
    // MARK: - 計算屬性
    
    /// 買賣比例
    var buyToSellRatio: String {
        return "\(buyTrades)/\(sellTrades)"
    }
    
    /// 格式化總損益
    var formattedTotalGainLoss: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalRealizedGainLoss)) ?? "$0"
    }
    
    /// 格式化總成交金額
    var formattedTotalVolume: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencySymbol = "$"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: totalVolume)) ?? "$0"
    }
    
    /// 損益顏色
    var gainLossColor: String {
        return totalRealizedGainLoss >= 0 ? "#28A745" : "#DC3545"
    }
    
    /// 是否盈利
    var isProfitable: Bool {
        return totalRealizedGainLoss > 0
    }
}

// MARK: - 交易篩選條件

/// 交易記錄篩選條件
struct TradingRecordFilter {
    var searchText: String = ""           // 搜尋文字
    var tradingType: TradingType?         // 交易類型篩選
    var dateRange: DateRange = .month     // 日期範圍
    var symbols: Set<String> = []         // 特定股票篩選
    
    /// 日期範圍枚舉
    enum DateRange: String, CaseIterable {
        case today = "today"
        case week = "week"
        case month = "month"
        case quarter = "quarter"
        case year = "year"
        case all = "all"
        
        var displayName: String {
            switch self {
            case .today: return "今日"
            case .week: return "最近7天"
            case .month: return "最近30天"
            case .quarter: return "最近3個月"
            case .year: return "最近1年"
            case .all: return "全部"
            }
        }
        
        /// 獲取日期範圍的開始時間
        func startDate() -> Date? {
            let calendar = Calendar.current
            let now = Date()
            
            switch self {
            case .today:
                return calendar.startOfDay(for: now)
            case .week:
                return calendar.date(byAdding: .day, value: -7, to: now)
            case .month:
                return calendar.date(byAdding: .day, value: -30, to: now)
            case .quarter:
                return calendar.date(byAdding: .month, value: -3, to: now)
            case .year:
                return calendar.date(byAdding: .year, value: -1, to: now)
            case .all:
                return nil
            }
        }
    }
    
    /// 檢查記錄是否符合篩選條件
    func matches(_ record: TradingRecord) -> Bool {
        // 搜尋文字篩選
        if !searchText.isEmpty {
            let searchLower = searchText.lowercased()
            let symbolMatch = record.symbol.lowercased().contains(searchLower)
            let nameMatch = record.stockName.lowercased().contains(searchLower)
            if !symbolMatch && !nameMatch {
                return false
            }
        }
        
        // 交易類型篩選
        if let type = tradingType, record.type != type {
            return false
        }
        
        // 日期範圍篩選
        if let startDate = dateRange.startDate(), record.timestamp < startDate {
            return false
        }
        
        // 特定股票篩選
        if !symbols.isEmpty && !symbols.contains(record.symbol) {
            return false
        }
        
        return true
    }
}