//
//  Int+Formatted.swift
//  Invest_App
//
//  Created by 林家麒 on 2025/7/8.
//

import Foundation

extension Int {
    /// 格式化數字，添加千位分隔符
    func formattedWithSeparator() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Double {
    /// 格式化數字，添加千位分隔符
    func formattedWithSeparator() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
    
    /// 將 NTD 轉換為代幣 (100 NTD = 1 代幣)
    func ntdToTokens() -> Double {
        // 添加安全檢查，防止 NaN 或無窮大值
        guard self.isFinite && !self.isNaN else {
            print("⚠️ [TokenSystem] 檢測到無效數值: \(self)，返回 0")
            return 0.0
        }
        return self / 100.0
    }
    
    /// 將代幣轉換為 NTD (1 代幣 = 100 NTD)
    func tokensToNTD() -> Double {
        // 添加安全檢查，防止 NaN 或無窮大值
        guard self.isFinite && !self.isNaN else {
            print("⚠️ [TokenSystem] 檢測到無效數值: \(self)，返回 0")
            return 0.0
        }
        return self * 100.0
    }
    
    /// 格式化代幣顯示
    func formattedTokens() -> String {
        // 添加安全檢查
        guard self.isFinite && !self.isNaN else {
            return "0"
        }
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}

extension Int {
    /// 將 NTD 轉換為代幣 (100 NTD = 1 代幣)
    func ntdToTokens() -> Double {
        return Double(self) / 100.0
    }
    
    /// 將代幣轉換為 NTD (1 代幣 = 100 NTD)
    func tokensToNTD() -> Int {
        return self * 100
    }
}

// MARK: - 代幣相關常數和工具
struct TokenSystem {
    static let ntdPerToken: Double = 100.0
    static let tokenSymbol = "🪙"
    
    /// 格式化代幣顯示
    static func formatTokens(_ amount: Double) -> String {
        // 添加安全檢查，防止 NaN 或無窮大值
        guard amount.isFinite && !amount.isNaN else {
            print("⚠️ [TokenSystem] formatTokens 檢測到無效數值: \(amount)，返回預設值")
            return "\(tokenSymbol) 0.0"
        }
        
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 1
        let formattedAmount = formatter.string(from: NSNumber(value: amount)) ?? "0.0"
        return "\(tokenSymbol) \(formattedAmount)"
    }
    
    /// 從 NTD 金額轉換為代幣
    static func convertFromNTD(_ ntdAmount: Double) -> Double {
        guard ntdAmount.isFinite && !ntdAmount.isNaN else {
            print("⚠️ [TokenSystem] convertFromNTD 檢測到無效數值: \(ntdAmount)，返回 0")
            return 0.0
        }
        return ntdAmount / ntdPerToken
    }
    
    /// 從代幣轉換為 NTD 金額
    static func convertToNTD(_ tokenAmount: Double) -> Double {
        guard tokenAmount.isFinite && !tokenAmount.isNaN else {
            print("⚠️ [TokenSystem] convertToNTD 檢測到無效數值: \(tokenAmount)，返回 0")
            return 0.0
        }
        return tokenAmount * ntdPerToken
    }
    
    /// 格式化貨幣顯示
    static func formatCurrency(_ amount: Double) -> String {
        // 添加安全檢查
        guard amount.isFinite && !amount.isNaN else {
            print("⚠️ [TokenSystem] formatCurrency 檢測到無效數值: \(amount)，返回預設值")
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
