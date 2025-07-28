//
//  FeeCalculator.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/27.
//  手續費計算管理器
//

import Foundation

/// 手續費計算管理器
/// 提供統一的手續費計算邏輯，支援從系統設定或預設值獲取費率
class FeeCalculator {
    static let shared = FeeCalculator()
    
    private init() {}
    
    // MARK: - 預設費率設定
    private struct DefaultRates {
        static let brokerFee: Double = 0.001425      // 券商手續費 0.1425%
        static let transactionTax: Double = 0.003    // 證交稅 0.3%
        static let minimumBrokerFee: Double = 20     // 最低手續費 20 元
        static let minimumTransactionTax: Double = 1 // 最低證交稅 1 元
    }
    
    // MARK: - 費率獲取
    
    /// 獲取券商手續費率
    var brokerFeeRate: Double {
        // TODO: 從 system_settings 表格讀取設定
        return DefaultRates.brokerFee
    }
    
    /// 獲取證交稅率
    var transactionTaxRate: Double {
        // TODO: 從 system_settings 表格讀取設定
        return DefaultRates.transactionTax
    }
    
    /// 獲取最低券商手續費
    var minimumBrokerFee: Double {
        // TODO: 從 system_settings 表格讀取設定
        return DefaultRates.minimumBrokerFee
    }
    
    /// 獲取最低證交稅
    var minimumTransactionTax: Double {
        // TODO: 從 system_settings 表格讀取設定
        return DefaultRates.minimumTransactionTax
    }
    
    // MARK: - 費用計算
    
    /// 計算交易手續費
    /// - Parameters:
    ///   - amount: 交易金額
    ///   - action: 交易類型 (買入/賣出)
    /// - Returns: 交易費用詳情
    func calculateTradingFees(amount: Double, action: TradeAction) -> TradingFees {
        // 計算券商手續費
        let calculatedBrokerFee = amount * brokerFeeRate
        let brokerFee = max(calculatedBrokerFee, minimumBrokerFee)
        
        // 計算證交稅 (僅賣出時收取)
        let calculatedTransactionTax = action == .sell ? amount * transactionTaxRate : 0
        let transactionTax = action == .sell ? max(calculatedTransactionTax, minimumTransactionTax) : 0
        
        let totalFees = brokerFee + transactionTax
        
        return TradingFees(
            brokerFee: brokerFee,
            transactionTax: transactionTax,
            totalFees: totalFees,
            netAmount: action == .buy ? amount + totalFees : amount - totalFees
        )
    }
    
    /// 計算買入所需的總成本
    /// - Parameters:
    ///   - quantity: 股數
    ///   - price: 股價
    /// - Returns: 包含手續費的總成本
    func calculateBuyingCost(quantity: Int, price: Double) -> TradingCost {
        let amount = Double(quantity) * price
        let fees = calculateTradingFees(amount: amount, action: .buy)
        
        return TradingCost(
            shareAmount: amount,
            fees: fees,
            totalCost: fees.netAmount
        )
    }
    
    /// 計算賣出的淨收入
    /// - Parameters:
    ///   - quantity: 股數
    ///   - price: 股價
    /// - Returns: 扣除手續費和稅金後的淨收入
    func calculateSellingProceeds(quantity: Int, price: Double) -> TradingCost {
        let amount = Double(quantity) * price
        let fees = calculateTradingFees(amount: amount, action: .sell)
        
        return TradingCost(
            shareAmount: amount,
            fees: fees,
            totalCost: fees.netAmount
        )
    }
}

// MARK: - 資料結構

/// 交易費用詳情
struct TradingFees {
    let brokerFee: Double          // 券商手續費
    let transactionTax: Double     // 證交稅
    let totalFees: Double          // 總費用
    let netAmount: Double          // 淨金額
    
    /// 格式化顯示
    var formattedDetails: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TWD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        var details = "手續費: \(formatter.string(from: NSNumber(value: brokerFee)) ?? "0")"
        if transactionTax > 0 {
            details += ", 證交稅: \(formatter.string(from: NSNumber(value: transactionTax)) ?? "0")"
        }
        details += ", 總計: \(formatter.string(from: NSNumber(value: totalFees)) ?? "0")"
        
        return details
    }
}

/// 交易成本詳情
struct TradingCost {
    let shareAmount: Double        // 股票金額
    let fees: TradingFees         // 費用詳情
    let totalCost: Double         // 總成本/淨收入
    
    /// 格式化顯示總成本
    var formattedTotalCost: String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TWD"
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: totalCost)) ?? "0"
    }
}

// MARK: - TradeAction 擴展
extension TradeAction {
    /// 交易動作的中文描述
    var actionName: String {
        switch self {
        case .buy: return "買入"
        case .sell: return "賣出"
        }
    }
}