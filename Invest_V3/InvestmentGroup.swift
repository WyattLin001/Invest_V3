import Foundation

struct InvestmentGroup: Codable, Identifiable {
    let id: UUID
    let name: String
    let host: String
    let hostId: UUID?
    let returnRate: Double
    let entryFee: String?
    let tokenCost: Int
    let memberCount: Int
    let maxMembers: Int
    let category: String?
    let description: String?
    let rules: [String]
    let isPrivate: Bool
    let inviteCode: String?
    let portfolioValue: Double
    let rankingPosition: Int
    let createdAt: Date
    let updatedAt: Date
    
    // Custom initializer for decoding with default values
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle both String and UUID for id field
        if let idString = try? container.decode(String.self, forKey: .id) {
            id = UUID(uuidString: idString) ?? UUID()
        } else {
            id = try container.decode(UUID.self, forKey: .id)
        }
        
        name = try container.decode(String.self, forKey: .name)
        host = try container.decode(String.self, forKey: .host)
        
        // Handle hostId
        if let hostIdString = try? container.decodeIfPresent(String.self, forKey: .hostId) {
            hostId = UUID(uuidString: hostIdString)
        } else {
            hostId = try container.decodeIfPresent(UUID.self, forKey: .hostId)
        }
        
        returnRate = try container.decode(Double.self, forKey: .returnRate)
        entryFee = try container.decodeIfPresent(String.self, forKey: .entryFee)
        tokenCost = try container.decodeIfPresent(Int.self, forKey: .tokenCost) ?? 0
        memberCount = try container.decode(Int.self, forKey: .memberCount)
        maxMembers = try container.decodeIfPresent(Int.self, forKey: .maxMembers) ?? 100
        category = try container.decodeIfPresent(String.self, forKey: .category)
        description = try container.decodeIfPresent(String.self, forKey: .description)
        rules = try container.decodeIfPresent([String].self, forKey: .rules) ?? []
        isPrivate = try container.decodeIfPresent(Bool.self, forKey: .isPrivate) ?? false
        inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)
        portfolioValue = try container.decodeIfPresent(Double.self, forKey: .portfolioValue) ?? 0.0
        rankingPosition = try container.decodeIfPresent(Int.self, forKey: .rankingPosition) ?? 0
        
        // Handle date strings from database
        if let createdAtString = try? container.decode(String.self, forKey: .createdAt) {
            createdAt = ISO8601DateFormatter().date(from: createdAtString) ?? Date()
        } else {
            createdAt = try container.decode(Date.self, forKey: .createdAt)
        }
        
        if let updatedAtString = try? container.decode(String.self, forKey: .updatedAt) {
            updatedAt = ISO8601DateFormatter().date(from: updatedAtString) ?? Date()
        } else {
            updatedAt = try container.decode(Date.self, forKey: .updatedAt)
        }
    }
    
    // Helper method to parse token cost from entryFee string
    private static func parseTokenCost(from entryFee: String?) -> Int {
        guard let fee = entryFee else { return 0 }
        
        // Extract numbers from strings like "10 代幣", "100 代幣", etc.
        let numbers = fee.components(separatedBy: CharacterSet.decimalDigits.inverted).compactMap { Int($0) }
        return numbers.first ?? 0
    }
    
    // Regular initializer for creating new instances
    init(id: UUID, name: String, host: String, hostId: UUID? = nil, returnRate: Double, entryFee: String?, tokenCost: Int, memberCount: Int, maxMembers: Int = 100, category: String?, description: String?, rules: [String] = [], isPrivate: Bool = false, inviteCode: String? = nil, portfolioValue: Double = 0.0, rankingPosition: Int = 0, createdAt: Date, updatedAt: Date) {
        self.id = id
        self.name = name
        self.host = host
        self.hostId = hostId
        self.returnRate = returnRate
        self.entryFee = entryFee
        self.tokenCost = tokenCost
        self.memberCount = memberCount
        self.maxMembers = maxMembers
        self.category = category
        self.description = description
        self.rules = rules
        self.isPrivate = isPrivate
        self.inviteCode = inviteCode
        self.portfolioValue = portfolioValue
        self.rankingPosition = rankingPosition
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // 為了向後兼容，提供預設值
    var hostName: String { host }
    
    // 安全的格式化回報率顯示
    var formattedReturnRate: String {
        guard returnRate.isFinite && !returnRate.isNaN else {
            print("⚠️ [InvestmentGroup] 檢測到無效 returnRate: \(returnRate)")
            return "0.0%"
        }
        return String(format: "%.1f%%", returnRate)
    }
    
    // 安全的回報率數值
    var safeReturnRate: Double {
        guard returnRate.isFinite && !returnRate.isNaN else {
            print("⚠️ [InvestmentGroup] 檢測到無效 returnRate: \(returnRate)，返回 0")
            return 0.0
        }
        return returnRate
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case host
        case hostId = "host_id"
        case returnRate = "return_rate"
        case entryFee = "entry_fee"
        case tokenCost = "token_cost"
        case memberCount = "member_count"
        case maxMembers = "max_members"
        case category
        case description
        case rules
        case isPrivate = "is_private"
        case inviteCode = "invite_code"
        case portfolioValue = "portfolio_value"
        case rankingPosition = "ranking_position"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

// 群組成員模型
struct GroupMember: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let userId: UUID
    let userName: String
    let role: MemberRole
    let portfolioValue: Double
    let returnRate: Double
    let joinedAt: Date
    
    // 安全的格式化回報率顯示
    var formattedReturnRate: String {
        guard returnRate.isFinite && !returnRate.isNaN else {
            print("⚠️ [GroupMember] 檢測到無效 returnRate: \(returnRate)")
            return "0.0%"
        }
        return String(format: "%.1f%%", returnRate)
    }
    
    // 安全的投資組合價值格式化
    var formattedPortfolioValue: String {
        guard portfolioValue.isFinite && !portfolioValue.isNaN else {
            print("⚠️ [GroupMember] 檢測到無效 portfolioValue: \(portfolioValue)")
            return "NT$0"
        }
        return String(format: "NT$%.0f", portfolioValue)
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case userId = "user_id"
        case userName = "user_name"
        case role
        case portfolioValue = "portfolio_value"
        case returnRate = "return_rate"
        case joinedAt = "joined_at"
    }
}

// 成員角色枚舉
enum MemberRole: String, Codable {
    case host = "host"
    case admin = "admin"
    case member = "member"
}

// 群組邀請模型
struct GroupInvitation: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let inviterId: UUID
    let inviterName: String
    let inviteeEmail: String
    let status: InvitationStatus
    let expiresAt: Date
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case inviterId = "inviter_id"
        case inviterName = "inviter_name"
        case inviteeEmail = "invitee_email"
        case status
        case expiresAt = "expires_at"
        case createdAt = "created_at"
    }
}

// 邀請狀態枚舉
enum InvitationStatus: String, Codable {
    case pending = "pending"
    case accepted = "accepted"
    case rejected = "rejected"
    case expired = "expired"
}

// 群組捐贈記錄模型
struct GroupDonation: Codable, Identifiable {
    let id: String
    let groupId: String
    let donorId: String
    let donorName: String
    let amount: Int
    let message: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case donorId = "donor_id"
        case donorName = "donor_name"
        case amount
        case message
        case createdAt = "created_at"
    }
}

// 捐贈統計摘要模型 (用於排行榜)
struct DonationSummary: Codable, Identifiable {
    let donorId: String
    let donorName: String
    let totalAmount: Int
    let donationCount: Int
    let lastDonationDate: Date
    
    var id: String { donorId }
    
    // 格式化總金額顯示
    var formattedTotalAmount: String {
        return "\(totalAmount) 金幣"
    }
    
    // 格式化捐贈次數顯示
    var formattedDonationCount: String {
        return "\(donationCount) 次"
    }
    
    // 格式化最後捐贈時間
    var formattedLastDonationDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter.string(from: lastDonationDate)
    }
}

// MARK: - 創作者收益相關模型

// 收益類型枚舉
enum RevenueType: String, CaseIterable, Codable {
    case subscriptionShare = "subscription_share" // 訂閱分潤
    case readerTip = "reader_tip" // 讀者抖內
    case groupEntryFee = "group_entry_fee" // 群組入會費收入
    case groupTip = "group_tip" // 群組抖內收入
    
    var displayName: String {
        switch self {
        case .subscriptionShare: return "訂閱分潤"
        case .readerTip: return "讀者抖內"
        case .groupEntryFee: return "群組入會費收入"
        case .groupTip: return "群組抖內收入"
        }
    }
    
    var icon: String {
        switch self {
        case .subscriptionShare: return "👥"
        case .readerTip: return "💝"
        case .groupEntryFee: return "🎫"
        case .groupTip: return "🎁"
        }
    }
} 