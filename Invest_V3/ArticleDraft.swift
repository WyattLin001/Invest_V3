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