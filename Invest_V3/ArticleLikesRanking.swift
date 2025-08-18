//
//  ArticleLikesRanking.swift
//  Invest_V3
//
//  Created by Claude Code on 2025/8/18.
//  文章點讚排行榜資料模型
//

import Foundation
import SwiftUI

// MARK: - 文章點讚排行榜模型
struct ArticleLikesRanking: Identifiable, Codable {
    let id: UUID
    let rank: Int
    let title: String
    let author: String
    let authorId: UUID?
    let likesCount: Int
    let category: String
    let keywords: [String]
    let createdAt: Date
    let period: RankingPeriod
    
    enum CodingKeys: String, CodingKey {
        case id
        case rank
        case title
        case author
        case authorId = "author_id"
        case likesCount = "likes_count"
        case category
        case keywords
        case createdAt = "created_at"
        case period
    }
    
    // MARK: - Computed Properties
    
    /// 排名徽章顏色
    var badgeColor: Color {
        switch rank {
        case 1: return Color(hex: "#FFD700") // 金色
        case 2: return Color(hex: "#C0C0C0") // 銀色
        case 3: return Color(hex: "#CD7F32") // 銅色
        default: return .gray400
        }
    }
    
    /// 邊框顏色
    var borderColor: Color {
        return badgeColor.opacity(0.3)
    }
    
    /// 格式化點讚數
    var formattedLikesCount: String {
        if likesCount >= 1000 {
            return String(format: "%.1fk", Double(likesCount) / 1000.0)
        } else {
            return "\(likesCount)"
        }
    }
    
    /// 主要關鍵字（顯示第一個）
    var primaryKeyword: String {
        return keywords.first ?? category
    }
    
    /// 截斷的標題（最多25個字符）
    var truncatedTitle: String {
        if title.count > 25 {
            return String(title.prefix(22)) + "..."
        }
        return title
    }
    
    /// 期間文字描述
    var periodText: String {
        switch period {
        case .weekly: return "本週"
        case .monthly: return "本月"  
        case .quarterly: return "本季"
        case .yearly: return "本年"
        case .all: return "總榜"
        }
    }
}

// MARK: - 點讚排行榜期間（重用現有的 RankingPeriod）
// 已在其他地方定義，這裡不需要重複定義

// MARK: - 測試資料產生器
#if DEBUG
extension ArticleLikesRanking {
    static func createTestData(for period: RankingPeriod) -> [ArticleLikesRanking] {
        let testArticles = [
            ("台積電財報分析：AI 晶片需求強勁", "投資分析師", 245, "投資分析", ["台積電", "財報", "AI晶片"]),
            ("2025年台股展望：科技股仍是主軸", "市場觀察家", 189, "市場分析", ["台股", "2025", "科技股"]),
            ("升息環境下的投資策略調整", "理財專家", 156, "投資策略", ["升息", "投資策略", "風險管理"])
        ]
        
        return testArticles.enumerated().map { index, data in
            ArticleLikesRanking(
                id: UUID(),
                rank: index + 1,
                title: data.0,
                author: data.1,
                authorId: UUID(),
                likesCount: data.2,
                category: data.3,
                keywords: data.4,
                createdAt: Date().addingTimeInterval(-Double(index) * 86400), // 往前推幾天
                period: period
            )
        }
    }
}
#endif