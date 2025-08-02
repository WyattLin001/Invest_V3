//
//  ArticleReadLog.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/2.
//  文章閱讀記錄模型 - 用於收益資格達成判斷系統
//

import Foundation

// MARK: - 文章閱讀記錄模型
struct ArticleReadLog: Codable, Identifiable {
    let id: UUID
    let articleId: UUID
    let userId: UUID
    let readStartTime: Date
    let readEndTime: Date?
    let readDurationSeconds: Int
    let scrollPercentage: Double // 滾動百分比 (0-100)
    let isCompleteRead: Bool // 是否完整閱讀 (滾動超過80%)
    let deviceType: String // 設備類型 (iOS, Android, Web)
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case userId = "user_id"
        case readStartTime = "read_start_time"
        case readEndTime = "read_end_time"
        case readDurationSeconds = "read_duration_seconds"
        case scrollPercentage = "scroll_percentage"
        case isCompleteRead = "is_complete_read"
        case deviceType = "device_type"
        case createdAt = "created_at"
    }
}

// MARK: - 文章閱讀記錄插入模型
struct ArticleReadLogInsert: Codable {
    let articleId: String
    let userId: String
    let readStartTime: Date
    let readEndTime: Date?
    let readDurationSeconds: Int
    let scrollPercentage: Double
    let isCompleteRead: Bool
    let deviceType: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case articleId = "article_id"
        case userId = "user_id"
        case readStartTime = "read_start_time"
        case readEndTime = "read_end_time"
        case readDurationSeconds = "read_duration_seconds"
        case scrollPercentage = "scroll_percentage"
        case isCompleteRead = "is_complete_read"
        case deviceType = "device_type"
        case createdAt = "created_at"
    }
    
    init(articleId: UUID, userId: UUID, readStartTime: Date, readEndTime: Date?, readDurationSeconds: Int, scrollPercentage: Double, isCompleteRead: Bool) {
        self.articleId = articleId.uuidString
        self.userId = userId.uuidString
        self.readStartTime = readStartTime
        self.readEndTime = readEndTime
        self.readDurationSeconds = readDurationSeconds
        self.scrollPercentage = scrollPercentage
        self.isCompleteRead = isCompleteRead
        self.deviceType = "iOS"
        self.createdAt = Date()
    }
}

// MARK: - 閱讀統計數據模型
struct ReadingStats: Codable {
    let totalReads: Int
    let uniqueReaders: Int
    let averageReadTime: Double
    let completionRate: Double // 完整閱讀率
    let last30DaysReads: Int
    let last7DaysReads: Int
    
    enum CodingKeys: String, CodingKey {
        case totalReads = "total_reads"
        case uniqueReaders = "unique_readers"
        case averageReadTime = "average_read_time"
        case completionRate = "completion_rate"
        case last30DaysReads = "last_30_days_reads"
        case last7DaysReads = "last_7_days_reads"
    }
}

// MARK: - 作者閱讀分析數據
struct AuthorReadingAnalytics: Codable {
    let authorId: UUID
    let totalArticles: Int
    let totalReads: Int
    let uniqueReaders: Int
    let last30DaysUniqueReaders: Int
    let last90DaysArticles: Int
    let averageReadTime: Double
    let completionRate: Double
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case authorId = "author_id"
        case totalArticles = "total_articles"
        case totalReads = "total_reads"
        case uniqueReaders = "unique_readers"
        case last30DaysUniqueReaders = "last_30_days_unique_readers"
        case last90DaysArticles = "last_90_days_articles"
        case averageReadTime = "average_read_time"
        case completionRate = "completion_rate"
        case createdAt = "created_at"
    }
}