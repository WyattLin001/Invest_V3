//
//  View+Extensions.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/19.
//

import SwiftUI

// Note: brandCardStyle() is defined in Color+Hex.swift to avoid duplication

// MARK: - Progress Value Utilities
extension Double {
    /// 限制進度值在有效範圍內 (0...1)
    func clampedProgress() -> Double {
        // 處理 NaN 和 Infinity 情況
        guard self.isFinite else { return 0.0 }
        return max(0.0, min(1.0, self))
    }
    
    /// 限制進度值在指定範圍內 (0...total)
    func clampedProgress(total: Double) -> Double {
        // 處理 NaN 和 Infinity 情況
        guard self.isFinite && total.isFinite else { return 0.0 }
        guard total > 0 else { return 0.0 }
        return max(0.0, min(total, self))
    }
    
    /// 安全的進度值計算，自動處理除法和邊界情況
    func safeProgressValue(total: Double) -> Double {
        // 處理 NaN 和 Infinity
        guard self.isFinite && total.isFinite else { return 0.0 }
        // 避免除以零
        guard total > 0 else { return 0.0 }
        // 計算比例並限制範圍
        let ratio = self / total
        return ratio.clampedProgress()
    }
}

// MARK: - Safe Progress View Helpers
extension View {
    /// 創建一個安全的 ProgressView，自動限制數值範圍
    func safeProgressView(value: Double) -> some View {
        ProgressView(value: value.clampedProgress())
    }
    
    /// 創建一個安全的 ProgressView，自動限制數值範圍（帶總數）
    func safeProgressView(value: Double, total: Double) -> some View {
        ProgressView(value: value.clampedProgress(total: total), total: total)
    }
}
