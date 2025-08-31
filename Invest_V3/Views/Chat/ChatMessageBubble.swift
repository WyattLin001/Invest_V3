import SwiftUI

/// 聊天氣泡視圖組件
/// 負責顯示單個聊天消息，包括文字、圖片、系統消息等不同類型
struct ChatMessageBubble: View {
    let message: ChatMessage
    let isFromCurrentUser: Bool
    
    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 50)
                messageContent
                    .background(messageBubbleColor)
                    .cornerRadius(18)
            } else {
                // 其他用戶頭像
                senderAvatar
                
                VStack(alignment: .leading, spacing: 4) {
                    if !message.senderName.isEmpty {
                        Text(message.senderName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    messageContent
                        .background(messageBubbleColor)
                        .cornerRadius(18)
                }
                
                Spacer(minLength: 50)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 2)
    }
    
    // MARK: - 組件
    
    @ViewBuilder
    private var messageContent: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            switch message.messageType {
            case "text":
                textMessageContent
            case "image":
                imageMessageContent
            case "file":
                fileMessageContent
            case "system":
                systemMessageContent
            default:
                textMessageContent
            }
            
            messageTimestamp
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
    
    private var textMessageContent: some View {
        Text(message.content)
            .font(.body)
            .foregroundColor(textColor)
            .multilineTextAlignment(isFromCurrentUser ? .trailing : .leading)
    }
    
    private var imageMessageContent: some View {
        // 圖片消息處理
        VStack(alignment: .leading) {
            if let imageUrl = URL(string: message.content) {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: 200, maxHeight: 200)
                        .cornerRadius(8)
                } placeholder: {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 200, height: 150)
                        .overlay(
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                        )
                }
            } else {
                Text("🖼️ 圖片")
                    .font(.body)
                    .foregroundColor(textColor)
            }
        }
    }
    
    private var fileMessageContent: some View {
        // 文件消息處理
        HStack {
            Image(systemName: "doc.fill")
                .foregroundColor(.blue)
            
            VStack(alignment: .leading) {
                Text("檔案")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(message.content)
                    .font(.body)
                    .foregroundColor(textColor)
                    .lineLimit(2)
            }
            
            Spacer()
            
            Image(systemName: "arrow.down.circle")
                .foregroundColor(.blue)
        }
        .padding(8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
    
    private var systemMessageContent: some View {
        Text(message.content)
            .font(.caption)
            .foregroundColor(.secondary)
            .italic()
    }
    
    private var messageTimestamp: some View {
        Text(formatTimestamp(message.createdAt))
            .font(.caption2)
            .foregroundColor(.secondary)
    }
    
    @ViewBuilder
    private var senderAvatar: some View {
        Circle()
            .fill(Color.blue.opacity(0.6))
            .frame(width: 32, height: 32)
            .overlay(
                Text(String(message.senderName.prefix(1)).uppercased())
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            )
    }
    
    // MARK: - 樣式計算
    
    private var messageBubbleColor: Color {
        switch message.messageType {
        case "system":
            return Color.clear
        default:
            return isFromCurrentUser ? Color.blue : Color.gray.opacity(0.2)
        }
    }
    
    private var textColor: Color {
        switch message.messageType {
        case "system":
            return .secondary
        default:
            return isFromCurrentUser ? .white : .primary
        }
    }
    
    // MARK: - 輔助方法
    
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        let now = Date()
        
        if Calendar.current.isDate(date, inSameDayAs: now) {
            formatter.dateFormat = "HH:mm"
        } else if Calendar.current.dateComponents([.day], from: date, to: now).day! < 7 {
            formatter.dateFormat = "E HH:mm"
        } else {
            formatter.dateFormat = "MM/dd HH:mm"
        }
        
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    ScrollView {
        VStack(spacing: 8) {
            ChatMessageBubble(
                message: ChatMessage(
                    id: UUID(),
                    groupId: UUID(),
                    senderId: UUID(),
                    senderName: "Alice",
                    content: "Hello everyone! How's your portfolio performing today?",
                    isInvestmentCommand: false,
                    createdAt: Date()
                ),
                isFromCurrentUser: false
            )
            
            ChatMessageBubble(
                message: ChatMessage(
                    id: UUID(),
                    groupId: UUID(),
                    senderId: UUID(),
                    senderName: "Me",
                    content: "Looking good! Up 2.5% today 📈",
                    isInvestmentCommand: false,
                    createdAt: Date()
                ),
                isFromCurrentUser: true
            )
            
            ChatMessageBubble(
                message: ChatMessage(
                    id: UUID(),
                    groupId: UUID(),
                    senderId: UUID(),
                    senderName: "System",
                    content: "Bob joined the group",
                    isInvestmentCommand: true,
                    createdAt: Date()
                ),
                isFromCurrentUser: false
            )
        }
        .padding()
    }
}