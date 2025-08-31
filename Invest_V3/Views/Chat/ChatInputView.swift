import SwiftUI

/// 聊天輸入視圖組件
/// 負責處理消息輸入、附件發送、表情符號等功能
struct ChatInputView: View {
    @Binding var messageText: String
    @Binding var isShowingGiftPicker: Bool
    
    let onSendMessage: () -> Void
    let onSendGift: (GiftOption) -> Void
    let onAttachFile: () -> Void
    let onTakePhoto: () -> Void
    
    @State private var isShowingActionMenu = false
    @State private var isShowingEmojiPicker = false
    
    var body: some View {
        VStack(spacing: 0) {
            // 頂部分隔線
            Divider()
            
            // 輸入區域
            HStack(spacing: 12) {
                // 附件按鈕
                attachmentButton
                
                // 消息輸入框
                messageInputField
                
                // 發送/禮物按鈕
                actionButton
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color.surfacePrimary)
            
            // 禮物選擇器
            if isShowingGiftPicker {
                giftPickerView
            }
        }
    }
    
    // MARK: - 組件
    
    private var attachmentButton: some View {
        Button(action: {
            isShowingActionMenu = true
        }) {
            Image(systemName: "plus.circle")
                .font(.title2)
                .foregroundColor(.brandGreen)
        }
        .actionSheet(isPresented: $isShowingActionMenu) {
            ActionSheet(
                title: Text("附件選項"),
                buttons: [
                    .default(Text("📸 拍照")) {
                        onTakePhoto()
                    },
                    .default(Text("📁 選擇文件")) {
                        onAttachFile()
                    },
                    .cancel()
                ]
            )
        }
    }
    
    private var messageInputField: some View {
        HStack {
            TextField("輸入消息...", text: $messageText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...4)
                .onSubmit {
                    if !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        onSendMessage()
                    }
                }
            
            Button(action: {
                isShowingEmojiPicker.toggle()
            }) {
                Image(systemName: "face.smiling")
                    .foregroundColor(.gray)
            }
        }
    }
    
    private var actionButton: some View {
        Group {
            if messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                // 禮物按鈕
                Button(action: {
                    isShowingGiftPicker.toggle()
                }) {
                    Image(systemName: "gift")
                        .font(.title2)
                        .foregroundColor(.brandOrange)
                }
            } else {
                // 發送按鈕
                Button(action: onSendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(.brandGreen)
                }
            }
        }
    }
    
    private var giftPickerView: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("選擇禮物")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("關閉") {
                    isShowingGiftPicker = false
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                ForEach(GiftOption.allCases, id: \.self) { gift in
                    GiftOptionView(gift: gift) {
                        onSendGift(gift)
                        isShowingGiftPicker = false
                    }
                }
            }
        }
        .padding(16)
        .background(Color.surfaceSecondary)
        .cornerRadius(16, corners: [.topLeft, .topRight])
    }
}

/// 禮物選項視圖
struct GiftOptionView: View {
    let gift: GiftOption
    let onSelect: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            Text(gift.emoji)
                .font(.title)
            
            Text(gift.name)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            Text("\(gift.price)金幣")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(width: 70, height: 70)
        .background(Color.surfacePrimary)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.borderPrimary, lineWidth: 1)
        )
        .onTapGesture {
            onSelect()
        }
    }
}

// MARK: - 禮物選項枚舉

enum GiftOption: String, CaseIterable {
    case heart = "heart"
    case flower = "flower"
    case coffee = "coffee"
    case beer = "beer"
    case cake = "cake"
    case diamond = "diamond"
    case rocket = "rocket"
    case crown = "crown"
    
    var name: String {
        switch self {
        case .heart: return "愛心"
        case .flower: return "花朵"
        case .coffee: return "咖啡"
        case .beer: return "啤酒"
        case .cake: return "蛋糕"
        case .diamond: return "鑽石"
        case .rocket: return "火箭"
        case .crown: return "皇冠"
        }
    }
    
    var emoji: String {
        switch self {
        case .heart: return "❤️"
        case .flower: return "🌸"
        case .coffee: return "☕"
        case .beer: return "🍺"
        case .cake: return "🎂"
        case .diamond: return "💎"
        case .rocket: return "🚀"
        case .crown: return "👑"
        }
    }
    
    var price: Int {
        switch self {
        case .heart: return 10
        case .flower: return 25
        case .coffee: return 50
        case .beer: return 75
        case .cake: return 100
        case .diamond: return 200
        case .rocket: return 500
        case .crown: return 1000
        }
    }
}

// MARK: - 輔助擴展
// cornerRadius extension moved to Color+Hex.swift to avoid duplication


// MARK: - Preview

#Preview {
    VStack {
        Spacer()
        
        ChatInputView(
            messageText: .constant(""),
            isShowingGiftPicker: .constant(false),
            onSendMessage: {
                print("發送消息")
            },
            onSendGift: { gift in
                print("發送禮物: \(gift.name)")
            },
            onAttachFile: {
                print("選擇文件")
            },
            onTakePhoto: {
                print("拍照")
            }
        )
    }
    .background(Color.backgroundPrimary)
}