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

// MARK: - 文章閱讀記錄插入模型（匹配數據庫 schema）
struct ArticleReadLogInsert: Codable {
    let userId: String
    let articleId: String
    let authorId: String
    let readingDuration: Int
    let scrollPercentage: Double
    let isCompleted: Bool
    let readingDate: String
    let sessionStart: String?
    let sessionEnd: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case articleId = "article_id"
        case authorId = "author_id"
        case readingDuration = "reading_duration"
        case scrollPercentage = "scroll_percentage"
        case isCompleted = "is_completed"
        case readingDate = "reading_date"
        case sessionStart = "session_start"
        case sessionEnd = "session_end"
    }
    
    init(userId: UUID, articleId: UUID, authorId: UUID, readingDuration: Int, scrollPercentage: Double, isCompleted: Bool, sessionStart: Date? = nil, sessionEnd: Date? = nil) {
        self.userId = userId.uuidString
        self.articleId = articleId.uuidString
        self.authorId = authorId.uuidString
        self.readingDuration = readingDuration
        self.scrollPercentage = scrollPercentage
        self.isCompleted = isCompleted
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        self.readingDate = formatter.string(from: Date())
        
        let isoFormatter = ISO8601DateFormatter()
        self.sessionStart = sessionStart != nil ? isoFormatter.string(from: sessionStart!) : nil
        self.sessionEnd = sessionEnd != nil ? isoFormatter.string(from: sessionEnd!) : nil
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