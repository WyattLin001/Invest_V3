import Foundation

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
    let createdAt: Date
    let updatedAt: Date
    
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
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // 常規初始化器
    init(id: UUID, title: String, author: String, authorId: UUID?, summary: String, fullContent: String, bodyMD: String? = nil, category: String, readTime: String, likesCount: Int, commentsCount: Int, sharesCount: Int, isFree: Bool, createdAt: Date, updatedAt: Date, keywords: [String] = []) {
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
        self.createdAt = createdAt
        self.updatedAt = updatedAt
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
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
} 