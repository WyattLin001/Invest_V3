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
// Note: TokenSystem is defined in TokenSystem.swift to avoid duplication
