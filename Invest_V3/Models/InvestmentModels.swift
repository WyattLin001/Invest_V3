//
//  InvestmentModels.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import Foundation

// MARK: - Investment Group Models
struct InvestmentGroup: Identifiable, Codable {
    let id: UUID
    let name: String
    let host: String
    let returnRate: Double
    let entryFee: String
    let memberCount: Int
    let category: String
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, host, category
        case returnRate = "return_rate"
        case entryFee = "entry_fee"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Article Models
struct Article: Identifiable, Codable {
    let id: UUID
    let title: String
    let author: String
    let authorId: UUID?
    let summary: String
    let fullContent: String
    let category: String
    let readTime: String
    let likesCount: Int
    let commentsCount: Int
    let isFree: Bool
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, author, summary, category
        case authorId = "author_id"
        case fullContent = "full_content"
        case readTime = "read_time"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case isFree = "is_free"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// MARK: - Portfolio Models
struct Portfolio: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let symbol: String
    let shares: Double
    let averagePrice: Double
    let currentValue: Double
    let returnRate: Double
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, shares
        case userId = "user_id"
        case averagePrice = "average_price"
        case currentValue = "current_value"
        case returnRate = "return_rate"
        case updatedAt = "updated_at"
    }
}

struct PortfolioTransaction: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let symbol: String
    let action: String // "buy" or "sell"
    let amount: Double
    let price: Double?
    let executedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, action, amount, price
        case userId = "user_id"
        case executedAt = "executed_at"
    }
}

// MARK: - Gift Models
enum GiftType: String, CaseIterable {
    case flower = "flower"
    case rocket = "rocket"
    case gold = "gold"
    
    var price: Int {
        switch self {
        case .flower: return 100
        case .rocket: return 1000
        case .gold: return 5000
        }
    }
    
    var emoji: String {
        switch self {
        case .flower: return "🌸"
        case .rocket: return "🚀"
        case .gold: return "🏆"
        }
    }
    
    var description: String {
        switch self {
        case .flower: return "表達支持的小禮物"
        case .rocket: return "推動投資組合起飛"
        case .gold: return "最高等級的認可"
        }
    }
}

// MARK: - Sample Data Extensions
extension InvestmentGroup {
    static let sampleData = [
        InvestmentGroup(
            id: UUID(),
            name: "科技股挑戰賽",
            host: "投資大師Tom",
            returnRate: 18.5,
            entryFee: "2 花束 (200 NTD)",
            memberCount: 156,
            category: "科技股",
            createdAt: Date(),
            updatedAt: Date()
        ),
        InvestmentGroup(
            id: UUID(),
            name: "綠能未來",
            host: "環保投資者Lisa",
            returnRate: 12.3,
            entryFee: "1 火箭 (1000 NTD)",
            memberCount: 89,
            category: "綠能",
            createdAt: Date(),
            updatedAt: Date()
        ),
        InvestmentGroup(
            id: UUID(),
            name: "短線交易王",
            host: "快手Kevin",
            returnRate: 25.7,
            entryFee: "1 黃金 (5000 NTD)",
            memberCount: 43,
            category: "短期投機",
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}

extension Article {
    static let sampleData = [
        Article(
            id: UUID(),
            title: "AI 股票投資策略：如何在科技革命中獲利",
            author: "投資分析師小明",
            authorId: UUID(),
            summary: "探討人工智慧對股市的影響，以及如何選擇相關投資標的...",
            fullContent: "隨著人工智慧技術的快速發展，2025年科技股市場呈現出前所未有的投資機會...",
            category: "科技股",
            readTime: "5 min",
            likesCount: 245,
            commentsCount: 67,
            isFree: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Article(
            id: UUID(),
            title: "綠能轉型：太陽能股票投資機會分析",
            author: "環保投資專家Lisa",
            authorId: UUID(),
            summary: "全球綠能政策推動下，太陽能產業迎來黃金發展期...",
            fullContent: "在全球氣候變遷的背景下，各國政府積極推動綠能政策...",
            category: "綠能",
            readTime: "7 min",
            likesCount: 189,
            commentsCount: 43,
            isFree: false,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}

extension Portfolio {
    static let sampleData = [
        Portfolio(
            id: UUID(),
            userId: UUID(),
            symbol: "AAPL",
            shares: 10.0,
            averagePrice: 150.0,
            currentValue: 1750.0,
            returnRate: 16.67,
            updatedAt: Date()
        ),
        Portfolio(
            id: UUID(),
            userId: UUID(),
            symbol: "TSLA",
            shares: 5.0,
            averagePrice: 200.0,
            currentValue: 1200.0,
            returnRate: 20.0,
            updatedAt: Date()
        ),
        Portfolio(
            id: UUID(),
            userId: UUID(),
            symbol: "NVDA",
            shares: 3.0,
            averagePrice: 400.0,
            currentValue: 1350.0,
            returnRate: 12.5,
            updatedAt: Date()
        )
    ]
}