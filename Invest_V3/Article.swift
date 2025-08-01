import Foundation

// MARK: - Article Status
enum ArticleStatus: String, Codable, CaseIterable {
    case draft = "draft"
    case published = "published"
    case review = "review"
    case archived = "archived"
    
    var displayName: String {
        switch self {
        case .draft: return "草稿"
        case .published: return "已發布"
        case .review: return "待審核"
        case .archived: return "已歸檔"
        }
    }
    
    var canInteract: Bool {
        return self == .published
    }
}

// MARK: - Article Source
enum ArticleSource: String, Codable, CaseIterable {
    case human = "human"
    case ai = "ai"
    case system = "system"
    
    var displayName: String {
        switch self {
        case .human: return "人工"
        case .ai: return "AI 分析師"
        case .system: return "系統"
        }
    }
    
    var iconName: String {
        switch self {
        case .human: return "person.fill"
        case .ai: return "brain.head.profile"
        case .system: return "gear"
        }
    }
}

struct Article: Codable, Identifiable {
    let id: UUID
    let title: String
    let author: String
    let authorId: UUID?
    let summary: String
    let fullContent: String
    let bodyMD: String?
    let category: String
    let readTime: String
    let likesCount: Int
    let commentsCount: Int
    let sharesCount: Int
    let isFree: Bool
    let status: ArticleStatus
    let source: ArticleSource
    let createdAt: Date
    let updatedAt: Date
    let keywords: [String]
    
    enum CodingKeys: String, CodingKey {
        case id
        case title
        case author
        case authorId = "author_id"
        case summary
        case fullContent = "full_content"
        case bodyMD = "body_md"
        case category
        case readTime = "read_time"
        case likesCount = "likes_count"
        case commentsCount = "comments_count"
        case sharesCount = "shares_count"
        case isFree = "is_free"
        case status
        case source
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case keywords
    }
    
    // 常規初始化器
    init(id: UUID, title: String, author: String, authorId: UUID?, summary: String, fullContent: String, bodyMD: String? = nil, category: String, readTime: String, likesCount: Int, commentsCount: Int, sharesCount: Int, isFree: Bool, status: ArticleStatus = .published, source: ArticleSource = .human, createdAt: Date, updatedAt: Date, keywords: [String] = []) {
        self.id = id
        self.title = title
        self.author = author
        self.authorId = authorId
        self.summary = summary
        self.fullContent = fullContent
        self.bodyMD = bodyMD
        self.category = category
        self.readTime = readTime
        self.likesCount = likesCount
        self.commentsCount = commentsCount
        self.sharesCount = sharesCount
        self.isFree = isFree
        self.status = status
        self.source = source
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.keywords = keywords
    }
    
    // 提供默認值的初始化器
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        author = try container.decode(String.self, forKey: .author)
        authorId = try container.decodeIfPresent(UUID.self, forKey: .authorId)
        summary = try container.decode(String.self, forKey: .summary)
        fullContent = try container.decode(String.self, forKey: .fullContent)
        bodyMD = try container.decodeIfPresent(String.self, forKey: .bodyMD)
        category = try container.decode(String.self, forKey: .category)
        readTime = try container.decodeIfPresent(String.self, forKey: .readTime) ?? "5 分鐘"
        likesCount = try container.decodeIfPresent(Int.self, forKey: .likesCount) ?? 0
        commentsCount = try container.decodeIfPresent(Int.self, forKey: .commentsCount) ?? 0
        sharesCount = try container.decodeIfPresent(Int.self, forKey: .sharesCount) ?? 0
        isFree = try container.decodeIfPresent(Bool.self, forKey: .isFree) ?? true
        
        // 支援新的 status 和 source 欄位，提供向後兼容的默認值
        if let statusString = try container.decodeIfPresent(String.self, forKey: .status) {
            status = ArticleStatus(rawValue: statusString) ?? .published
        } else {
            status = .published // 向後兼容：沒有 status 欄位的舊文章預設為已發布
        }
        
        if let sourceString = try container.decodeIfPresent(String.self, forKey: .source) {
            source = ArticleSource(rawValue: sourceString) ?? .human
        } else {
            source = .human // 向後兼容：沒有 source 欄位的舊文章預設為人工
        }
        
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        keywords = try container.decodeIfPresent([String].self, forKey: .keywords) ?? []
    }
    
    // MARK: - Computed Properties
    
    /// 是否為 AI 生成的文章
    var isAIGenerated: Bool {
        return source == .ai
    }
    
    /// 是否可以進行互動（按讚、留言等）
    var canInteract: Bool {
        return status.canInteract
    }
    
    /// 獲取作者顯示名稱（包含來源標識）
    var displayAuthor: String {
        switch source {
        case .ai:
            return "\(author) 🤖"
        case .system:
            return "\(author) ⚙️"
        case .human:
            return author
        }
    }
} 