//
//  EnhancedChatView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI
import Charts

struct EnhancedChatView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var alphaVantageService = AlphaVantageService.shared
    
    @State private var selectedGroup: InvestmentGroup?
    @State private var investmentGroups: [InvestmentGroup] = []
    @State private var chatMessages: [ChatMessage] = []
    @State private var messageText = ""
    @State private var showingInvestmentPanel = false
    @State private var userPortfolio: [Portfolio] = []
    @State private var stockPrices: [StockPrice] = []
    
    var body: some View {
        NavigationView {
            HStack(spacing: 0) {
                // Chat Groups List (30%)
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        Text("聊天")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Button {
                            // Add new chat
                        } label: {
                            Image(systemName: "plus")
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    
                    // Groups List
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(investmentGroups) { group in
                                ChatGroupRow(
                                    group: group,
                                    isSelected: selectedGroup?.id == group.id
                                ) {
                                    selectedGroup = group
                                    Task {
                                        await loadChatMessages(for: group.id)
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
                
                Divider()
                
                // Chat Window (70%)
                if let group = selectedGroup {
                    ChatWindowView(
                        group: group,
                        messages: chatMessages,
                        messageText: $messageText,
                        showingInvestmentPanel: $showingInvestmentPanel,
                        userPortfolio: userPortfolio,
                        stockPrices: stockPrices,
                        onSendMessage: sendMessage,
                        onInvestmentCommand: handleInvestmentCommand
                    )
                } else {
                    VStack {
                        Image(systemName: "bubble.left.and.bubble.right")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("選擇一個群組開始聊天")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(.systemGroupedBackground))
                }
            }
            .navigationBarHidden(true)
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        do {
            investmentGroups = try await supabaseService.fetchInvestmentGroups()
            if let firstGroup = investmentGroups.first {
                selectedGroup = firstGroup
                await loadChatMessages(for: firstGroup.id)
            }
        } catch {
            print("Failed to load data: \(error)")
        }
    }
    
    private func loadChatMessages(for groupId: UUID) async {
        do {
            chatMessages = try await supabaseService.fetchChatMessages(groupId: groupId)
        } catch {
            print("Failed to load chat messages: \(error)")
        }
    }
    
    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let groupId = selectedGroup?.id else { return }
        
        let message = ChatMessage(
            id: UUID(),
            groupId: groupId,
            senderId: UUID(), // Current user ID
            senderName: "用戶", // Current user name
            content: messageText,
            isInvestmentCommand: isInvestmentCommand(messageText),
            createdAt: Date()
        )
        
        Task {
            do {
                try await supabaseService.sendChatMessage(message)
                await loadChatMessages(for: groupId)
                messageText = ""
            } catch {
                print("Failed to send message: \(error)")
            }
        }
    }
    
    private func handleInvestmentCommand(_ command: String) {
        // Parse investment commands like "買入 AAPL 10萬"
        let components = command.components(separatedBy: " ")
        guard components.count >= 3 else { return }
        
        let action = components[0] // 買入 or 賣出
        let symbol = components[1]
        let amountString = components[2]
        
        // Extract amount (remove 萬 and convert to number)
        let amount = parseAmount(amountString)
        
        let transaction = PortfolioTransaction(
            id: UUID(),
            userId: UUID(), // Current user ID
            symbol: symbol,
            action: action == "買入" ? "buy" : "sell",
            amount: amount,
            price: nil, // Will be filled by current market price
            executedAt: Date()
        )
        
        Task {
            do {
                try await supabaseService.executeTransaction(transaction)
                // Refresh portfolio
            } catch {
                print("Failed to execute transaction: \(error)")
            }
        }
    }
    
    private func isInvestmentCommand(_ text: String) -> Bool {
        let investmentKeywords = ["買入", "賣出", "購買", "出售"]
        return investmentKeywords.contains { text.contains($0) }
    }
    
    private func parseAmount(_ amountString: String) -> Double {
        let cleanString = amountString.replacingOccurrences(of: "萬", with: "")
        return (Double(cleanString) ?? 0) * 10000
    }
}

struct ChatGroupRow: View {
    let group: InvestmentGroup
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Group Avatar
                Circle()
                    .fill(Color.blue.opacity(0.2))
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(String(group.name.prefix(1)))
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.blue)
                    )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text("主持人：\(group.host)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("\(group.memberCount)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Circle()
                        .fill(Color(hex: "#00B900"))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
            .background(isSelected ? Color(hex: "#00B900").opacity(0.1) : Color.clear)
            .overlay(
                Rectangle()
                    .fill(isSelected ? Color(hex: "#00B900") : Color.clear)
                    .frame(width: 3)
                    .frame(maxHeight: .infinity),
                alignment: .leading
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ChatWindowView: View {
    let group: InvestmentGroup
    let messages: [ChatMessage]
    @Binding var messageText: String
    @Binding var showingInvestmentPanel: Bool
    let userPortfolio: [Portfolio]
    let stockPrices: [StockPrice]
    let onSendMessage: () -> Void
    let onInvestmentCommand: (String) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Chat Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("主持人：\(group.host) • \(group.memberCount) 人")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                HStack(spacing: 16) {
                    Button {
                        // Gift action
                    } label: {
                        Image(systemName: "gift")
                            .font(.title3)
                    }
                    
                    Button {
                        showingInvestmentPanel.toggle()
                    } label: {
                        Image(systemName: "chart.pie")
                            .font(.title3)
                    }
                    
                    Button {
                        // Info action
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.title3)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .overlay(
                Rectangle()
                    .fill(Color(.separator))
                    .frame(height: 0.5),
                alignment: .bottom
            )
            
            // Chat Messages
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(messages) { message in
                        ChatMessageBubble(message: message)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            
            // Investment Panel (if shown)
            if showingInvestmentPanel {
                InvestmentPanelView(
                    portfolio: userPortfolio,
                    stockPrices: stockPrices
                )
                .frame(height: 200)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .fill(Color(.separator))
                        .frame(height: 0.5),
                    alignment: .top
                )
            }
            
            // Message Input
            HStack(spacing: 12) {
                TextField("輸入訊息...", text: $messageText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Button(action: onSendMessage) {
                    Text("發送")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "#00B900"))
                        .cornerRadius(20)
                }
                .disabled(messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
            .background(Color(.systemBackground))
        }
    }
}

struct ChatMessageBubble: View {
    let message: ChatMessage
    
    var body: some View {
        HStack {
            if message.senderName != "用戶" {
                // Other user's message (left aligned)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text(message.senderName)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        if message.senderName.contains("主持人") {
                            Text("主持人")
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(hex: "#00B900"))
                                .foregroundColor(.white)
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    
                    if message.isInvestmentCommand {
                        InvestmentCommandBubble(content: message.content)
                    } else {
                        Text(message.content)
                            .padding()
                            .background(Color(.systemGray6))
                            .cornerRadius(16)
                    }
                    
                    if let createdAt = message.createdAt {
                        Text(createdAt, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            } else {
                // Current user's message (right aligned)
                Spacer()
                
                VStack(alignment: .trailing, spacing: 8) {
                    Text(message.content)
                        .padding()
                        .background(Color(hex: "#00B900"))
                        .foregroundColor(.white)
                        .cornerRadius(16)
                    
                    if let createdAt = message.createdAt {
                        Text(createdAt, style: .time)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct InvestmentCommandBubble: View {
    let content: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(content)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding()
                .background(Color.blue)
                .cornerRadius(16)
        }
    }
}

struct InvestmentPanelView: View {
    let portfolio: [Portfolio]
    let stockPrices: [StockPrice]
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Text("投資組合")
                    .font(.headline)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("收起") {
                    // Close panel
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            HStack(spacing: 20) {
                // Portfolio Pie Chart
                VStack {
                    Text("持倉分布")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Simplified pie chart representation
                    Circle()
                        .fill(
                            AngularGradient(
                                colors: [.blue, .green, .orange, .purple],
                                center: .center
                            )
                        )
                        .frame(width: 80, height: 80)
                        .overlay(
                            Text("📊")
                                .font(.title2)
                        )
                }
                
                // Performance Chart
                VStack {
                    Text("回報率趨勢")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Simplified line chart
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.green.opacity(0.2))
                        .frame(width: 120, height: 60)
                        .overlay(
                            Text("📈 +15.8%")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.green)
                        )
                }
                
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

#Preview {
    EnhancedChatView()
}