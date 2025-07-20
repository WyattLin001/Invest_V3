//
//  TokenSystem.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/19.
//

import Foundation

/// 代幣系統 - 處理代幣與金錢的轉換和格式化
enum TokenSystem {
    
    /// 代幣轉換率：100 NTD = 1 代幣
    static let conversionRate: Double = 100.0
    
    /// 格式化代幣顯示 (例如: "1,234 代幣")
    static func formatTokens(_ tokens: Double) -> String {
        // 安全檢查，防止 NaN 或無窮大值
        guard tokens.isFinite && !tokens.isNaN else {
            print("⚠️ [TokenSystem] 檢測到無效代幣數值: \(tokens)，顯示為 0")
            return "0 代幣"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        
        let formattedNumber = formatter.string(from: NSNumber(value: tokens)) ?? "0"
        return "\(formattedNumber) 代幣"
    }
    
    /// 格式化 NTD 顯示 (例如: "NT$1,234")
    static func formatNTD(_ ntd: Double) -> String {
        // 安全檢查
        guard ntd.isFinite && !ntd.isNaN else {
            print("⚠️ [TokenSystem] 檢測到無效 NTD 數值: \(ntd)，顯示為 0")
            return "NT$0"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 0
        
        let formattedNumber = formatter.string(from: NSNumber(value: ntd)) ?? "0"
        return "NT$\(formattedNumber)"
    }
    
    /// 將 NTD 轉換為代幣
    static func ntdToTokens(_ ntd: Double) -> Double {
        guard ntd.isFinite && !ntd.isNaN else {
            return 0.0
        }
        return ntd / conversionRate
    }
    
    /// 將代幣轉換為 NTD
    static func tokensToNTD(_ tokens: Double) -> Double {
        guard tokens.isFinite && !tokens.isNaN else {
            return 0.0
        }
        return tokens * conversionRate
    }
    
    /// 格式化貨幣顯示 (例如: "NT$1,234")
    static func formatCurrency(_ amount: Double) -> String {
        // 安全檢查
        guard amount.isFinite && !amount.isNaN else {
            print("⚠️ [TokenSystem] 檢測到無效貨幣數值: \(amount)，顯示為 0")
            return "NT$0"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TWD"
        formatter.currencySymbol = "NT$"
        formatter.maximumFractionDigits = 0
        
        return formatter.string(from: NSNumber(value: amount)) ?? "NT$0"
    }
}
