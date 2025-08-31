import Foundation

struct ChatMessage: Codable, Identifiable {
    let id: UUID
    let groupId: UUID
    let senderId: UUID
    let senderName: String
    let content: String
    let isInvestmentCommand: Bool
    let createdAt: Date
    
    // 新增用戶角色屬性
    var userRole: String = "member" // 默認為成員
    
    var sender: String { senderName }  // 為了兼容性添加
    var isCommand: Bool { isInvestmentCommand }  // 為了兼容性添加
    var isHost: Bool { userRole == "host" }  // 檢查是否為主持人
    
    // Computed property for message type based on content
    var messageType: String {
        if isInvestmentCommand {
            return "system"
        }
        // For now, assume all other messages are text
        // In the future, this could be expanded to detect image/file types
        return "text"
    }
    
    // Computed property for timestamp compatibility
    var timestamp: Date { createdAt }
    
    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case senderId = "sender_id"
        case senderName = "sender_name"
        case content
        case isInvestmentCommand = "is_investment_command"
        case createdAt = "created_at"
    }
    
    // 自定義初始化方法，允許設置用戶角色
    init(id: UUID, groupId: UUID, senderId: UUID, senderName: String, content: String, isInvestmentCommand: Bool, createdAt: Date, userRole: String = "member") {
        self.id = id
        self.groupId = groupId
        self.senderId = senderId
        self.senderName = senderName
        self.content = content
        self.isInvestmentCommand = isInvestmentCommand
        self.createdAt = createdAt
        self.userRole = userRole
    }
} 