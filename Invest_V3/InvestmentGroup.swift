import Foundation

struct InvestmentGroup: Codable, Identifiable {
    let id: UUID
    let name: String
    let host: String
    let returnRate: Double
    let entryFee: String?
    let memberCount: Int
    let category: String?
    let rules: String?  // 新增群組規定欄位
    let createdAt: Date
    let updatedAt: Date
    
    // 為了向後兼容，提供預設值
    var description: String { "投資群組" }
    var hostId: UUID { UUID() }
    var hostName: String { host }
    var maxMembers: Int { 100 }
    var isPrivate: Bool { false }
    var inviteCode: String? { nil }
    var portfolioValue: Double { 1000000.0 }
    var rankingPosition: Int { 0 }
    
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
        case returnRate = "return_rate"
        case entryFee = "entry_fee"
        case memberCount = "member_count"
        case category
        case rules
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