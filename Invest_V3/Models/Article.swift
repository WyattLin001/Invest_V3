//
//  Article.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import Foundation

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

extension Article {
    static let sampleData = [
        Article(
            id: UUID(),
            title: "2025年科技股投資趨勢分析",
            author: "投資達人",
            authorId: UUID(),
            summary: "深度分析2025年科技股市場趨勢，包含AI、半導體、雲端運算等熱門領域的投資機會與風險評估。",
            fullContent: "隨著人工智慧技術的快速發展，2025年科技股市場呈現出前所未有的投資機會...",
            category: "科技股",
            readTime: "8 分鐘",
            likesCount: 156,
            commentsCount: 23,
            isFree: true,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Article(
            id: UUID(),
            title: "價值投資的核心原則",
            author: "巴菲特學徒",
            authorId: UUID(),
            summary: "學習巴菲特的投資哲學，掌握價值投資的核心原則，在市場波動中保持理性投資心態。",
            fullContent: "價值投資是一種長期投資策略，強調尋找被市場低估的優質企業...",
            category: "價值投資",
            readTime: "12 分鐘",
            likesCount: 89,
            commentsCount: 15,
            isFree: false,
            createdAt: Date(),
            updatedAt: Date()
        ),
        Article(
            id: UUID(),
            title: "加密貨幣市場展望",
            author: "區塊鏈專家",
            authorId: UUID(),
            summary: "分析當前加密貨幣市場趨勢，探討比特幣、以太坊等主流幣種的投資價值。",
            fullContent: "加密貨幣市場在經歷了多次波動後，正逐漸走向成熟...",
            category: "加密貨幣",
            readTime: "6 分鐘",
            likesCount: 234,
            commentsCount: 45,
            isFree: true,
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}