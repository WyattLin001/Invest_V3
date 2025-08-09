import Foundation

// MARK: - ArticleDraft Model

struct ArticleDraft: Identifiable, Codable {
    let id: UUID
    var title: String = ""
    var subtitle: String? = nil      // 修復：允許 nil 值
    var summary: String = ""         // 文章摘要
    var bodyMD: String = ""
    var category: String = "投資分析" // 文章分類
    var keywords: [String] = []      // ≤5 keywords
    var slug: String = ""            // custom URL path component
    var isPaid: Bool = false         // free vs. paid
    var isFree: Bool = true          // 兼容性屬性
    var isUnlisted: Bool = false     // unlisted vs. public
    var publication: Publication?    // optional host publication
    var createdAt: Date = Date()     // 創建時間
    var updatedAt: Date = Date()     // 更新時間
    
    // MARK: - Initializers
    
    /// 預設初始化器（用於創建新草稿）
    init(
        id: UUID = UUID(),
        title: String = "",
        subtitle: String? = nil,
        summary: String = "",
        bodyMD: String = "",
        category: String = "投資分析",
        keywords: [String] = [],
        slug: String = "",
        isPaid: Bool = false,
        isFree: Bool = true,
        isUnlisted: Bool = false,
        publication: Publication? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.summary = summary
        self.bodyMD = bodyMD
        self.category = category
        self.keywords = keywords
        self.slug = slug
        self.isPaid = isPaid
        self.isFree = isFree
        self.isUnlisted = isUnlisted
        self.publication = publication
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    /// Computed canonical URL shown to the user
    var canonicalURL: String {
        let base = "https://investv3.com/"
        return base + (slug.isEmpty ? title.slugified() : slug)
    }
    
    /// Check if draft is ready to publish
    var isReadyToPublish: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty &&
        !bodyMD.trimmingCharacters(in: .whitespaces).isEmpty
    }
    
    /// Calculate word count for content
    var wordCount: Int {
        let text = title + " " + bodyMD
        return text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count
    }
    
    /// Estimate reading time in minutes
    var estimatedReadingTime: Int {
        max(1, Int(ceil(Double(wordCount) / 250.0)))
    }
    
    /// Get completion percentage (0.0 to 1.0)
    var completionPercentage: Double {
        var score: Double = 0.0
        let totalCriteria = 6.0
        
        // Title check
        if !title.isEmpty { score += 1.0 }
        
        // Content check
        if bodyMD.count > 50 { score += 1.0 }
        if bodyMD.count > 500 { score += 1.0 }
        
        // Metadata check
        if !category.isEmpty { score += 1.0 }
        if !keywords.isEmpty { score += 1.0 }
        if subtitle != nil && !subtitle!.isEmpty { score += 1.0 }
        
        return score / totalCriteria
    }
    
    /// Get status based on content
    var status: DraftStatus {
        let completion = completionPercentage
        if completion >= 0.8 { return .readyToPublish }
        if completion >= 0.5 { return .inProgress }
        if completion >= 0.2 { return .draft }
        return .idea
    }
    
    /// Get formatted last modified time
    var lastModifiedFormatted: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: updatedAt, relativeTo: Date())
    }
}

// MARK: - Draft Status Enum

enum DraftStatus: String, CaseIterable {
    case idea = "idea"
    case draft = "draft"
    case inProgress = "in_progress"
    case readyToPublish = "ready_to_publish"
    
    var displayName: String {
        switch self {
        case .idea:
            return "構思中"
        case .draft:
            return "草稿"
        case .inProgress:
            return "進行中"
        case .readyToPublish:
            return "準備發布"
        }
    }
    
    var color: Color {
        switch self {
        case .idea:
            return .gray
        case .draft:
            return .orange
        case .inProgress:
            return .blue
        case .readyToPublish:
            return .green
        }
    }
    
    var icon: String {
        switch self {
        case .idea:
            return "lightbulb"
        case .draft:
            return "doc.text"
        case .inProgress:
            return "pencil"
        case .readyToPublish:
            return "checkmark.circle"
        }
    }
}

// MARK: - Publication Model

struct Publication: Identifiable, Hashable, Codable {
    let id: UUID
    let name: String
    let description: String?
    
    init(id: UUID = UUID(), name: String, description: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
    }
}

// MARK: - String Extension for Slugification

extension String {
    /// Converts string to URL-friendly slug
    func slugified() -> String {
        let lowered = self.lowercased()
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        let trimmed = lowered.replacingOccurrences(of: " ", with: "-")
        return trimmed.unicodeScalars.filter { allowed.contains($0) }.map(String.init).joined()
    }
}

// MARK: - Sample Publications

extension Publication {
    static let samplePublications: [Publication] = [
        Publication(name: "投資觀點", description: "專業投資分析與市場觀察"),
        Publication(name: "科技週報", description: "最新科技趨勢與產業動態"),
        Publication(name: "台股研究", description: "台灣股市深度分析")
    ]
} 