import Foundation

// MARK: - 閱讀行為分析模型
struct ReadingAnalytics: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let articleId: UUID
    let authorId: UUID
    let sessionId: UUID
    let startTime: Date
    let endTime: Date?
    let readingDuration: Double  // 閱讀時長（秒）
    let scrollPercentage: Double  // 滾動百分比
    let interactionCount: Int     // 互動次數
    let deviceType: String        // 設備類型
    let platform: String          // 平台
    let ipAddress: String?        // IP 地址（用於反作弊）
    let userAgent: String?        // 用戶代理
    let isValidRead: Bool         // 是否為有效閱讀
    let fraudScore: Double        // 作弊分數
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case articleId = "article_id"
        case authorId = "author_id"
        case sessionId = "session_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case readingDuration = "reading_duration"
        case scrollPercentage = "scroll_percentage"
        case interactionCount = "interaction_count"
        case deviceType = "device_type"
        case platform
        case ipAddress = "ip_address"
        case userAgent = "user_agent"
        case isValidRead = "is_valid_read"
        case fraudScore = "fraud_score"
        case createdAt = "created_at"
    }
    
    init(
        id: UUID = UUID(),
        userId: UUID,
        articleId: UUID,
        authorId: UUID,
        sessionId: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        readingDuration: Double = 0.0,
        scrollPercentage: Double = 0.0,
        interactionCount: Int = 0,
        deviceType: String = "iOS",
        platform: String = "mobile",
        ipAddress: String? = nil,
        userAgent: String? = nil,
        isValidRead: Bool = true,
        fraudScore: Double = 0.0,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.articleId = articleId
        self.authorId = authorId
        self.sessionId = sessionId
        self.startTime = startTime
        self.endTime = endTime
        self.readingDuration = readingDuration
        self.scrollPercentage = scrollPercentage
        self.interactionCount = interactionCount
        self.deviceType = deviceType
        self.platform = platform
        self.ipAddress = ipAddress
        self.userAgent = userAgent
        self.isValidRead = isValidRead
        self.fraudScore = fraudScore
        self.createdAt = createdAt
    }
}

// MARK: - 閱讀行為分析擴展
extension ReadingAnalytics {
    var formattedReadingDuration: String {
        let minutes = Int(readingDuration / 60)
        let seconds = Int(readingDuration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)分\(seconds)秒"
    }
    
    var formattedScrollPercentage: String {
        return String(format: "%.1f%%", scrollPercentage * 100)
    }
    
    var isCompletedRead: Bool {
        return scrollPercentage >= 0.8 && readingDuration >= 30  // 80% 滾動且至少 30 秒
    }
    
    var engagementLevel: EngagementLevel {
        if scrollPercentage >= 0.8 && readingDuration >= 120 {
            return .high
        } else if scrollPercentage >= 0.5 && readingDuration >= 60 {
            return .medium
        } else {
            return .low
        }
    }
    
    var riskLevel: RiskLevel {
        if fraudScore >= 0.8 {
            return .high
        } else if fraudScore >= 0.5 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - 參與度等級
enum EngagementLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "低"
        case .medium: return "中"
        case .high: return "高"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#DC3545"     // 紅色
        case .medium: return "#FFC107"  // 黃色
        case .high: return "#28A745"    // 綠色
        }
    }
}

// MARK: - 風險等級
enum RiskLevel: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "低風險"
        case .medium: return "中風險"
        case .high: return "高風險"
        }
    }
    
    var color: String {
        switch self {
        case .low: return "#28A745"     // 綠色
        case .medium: return "#FFC107"  // 黃色
        case .high: return "#DC3545"    // 紅色
        }
    }
}

// MARK: - 閱讀統計匯總
struct ReadingStatsSummary: Identifiable, Codable {
    let id: UUID
    let articleId: UUID
    let totalReads: Int
    let validReads: Int
    let averageReadingTime: Double
    let averageScrollPercentage: Double
    let completionRate: Double
    let highEngagementReads: Int
    let suspiciousReads: Int
    let uniqueReaders: Int
    let returningReaders: Int
    let topDeviceType: String
    let peakReadingHour: Int
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case articleId = "article_id"
        case totalReads = "total_reads"
        case validReads = "valid_reads"
        case averageReadingTime = "average_reading_time"
        case averageScrollPercentage = "average_scroll_percentage"
        case completionRate = "completion_rate"
        case highEngagementReads = "high_engagement_reads"
        case suspiciousReads = "suspicious_reads"
        case uniqueReaders = "unique_readers"
        case returningReaders = "returning_readers"
        case topDeviceType = "top_device_type"
        case peakReadingHour = "peak_reading_hour"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    var formattedAverageReadingTime: String {
        let minutes = Int(averageReadingTime / 60)
        let seconds = Int(averageReadingTime.truncatingRemainder(dividingBy: 60))
        return "\(minutes)分\(seconds)秒"
    }
    
    var formattedCompletionRate: String {
        return String(format: "%.1f%%", completionRate * 100)
    }
    
    var formattedAverageScrollPercentage: String {
        return String(format: "%.1f%%", averageScrollPercentage * 100)
    }
    
    var validReadRate: Double {
        guard totalReads > 0 else { return 0.0 }
        return Double(validReads) / Double(totalReads)
    }
    
    var formattedValidReadRate: String {
        return String(format: "%.1f%%", validReadRate * 100)
    }
    
    var suspiciousReadRate: Double {
        guard totalReads > 0 else { return 0.0 }
        return Double(suspiciousReads) / Double(totalReads)
    }
    
    var formattedSuspiciousReadRate: String {
        return String(format: "%.1f%%", suspiciousReadRate * 100)
    }
    
    var returningReaderRate: Double {
        guard uniqueReaders > 0 else { return 0.0 }
        return Double(returningReaders) / Double(uniqueReaders)
    }
    
    var formattedReturningReaderRate: String {
        return String(format: "%.1f%%", returningReaderRate * 100)
    }
}

// MARK: - 反作弊檢測結果
struct FraudDetectionResult: Codable {
    let isValid: Bool
    let fraudScore: Double
    let reasons: [String]
    let confidence: Double
    let recommendedAction: String
    
    var formattedFraudScore: String {
        return String(format: "%.2f", fraudScore)
    }
    
    var formattedConfidence: String {
        return String(format: "%.1f%%", confidence * 100)
    }
    
    var riskLevel: RiskLevel {
        if fraudScore >= 0.8 {
            return .high
        } else if fraudScore >= 0.5 {
            return .medium
        } else {
            return .low
        }
    }
}

// MARK: - 閱讀會話
struct ReadingSession: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let articleId: UUID
    let startTime: Date
    var endTime: Date?
    var isActive: Bool
    var currentScrollPosition: Double
    var interactionCount: Int
    var lastInteractionTime: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case articleId = "article_id"
        case startTime = "start_time"
        case endTime = "end_time"
        case isActive = "is_active"
        case currentScrollPosition = "current_scroll_position"
        case interactionCount = "interaction_count"
        case lastInteractionTime = "last_interaction_time"
    }
    
    var duration: Double {
        let endTime = self.endTime ?? Date()
        return endTime.timeIntervalSince(startTime)
    }
    
    var formattedDuration: String {
        let minutes = Int(duration / 60)
        let seconds = Int(duration.truncatingRemainder(dividingBy: 60))
        return "\(minutes)分\(seconds)秒"
    }
    
    mutating func updateInteraction() {
        interactionCount += 1
        lastInteractionTime = Date()
    }
    
    mutating func endSession() {
        isActive = false
        endTime = Date()
    }
}