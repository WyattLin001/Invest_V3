//
//  EnhancedWalletView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct EnhancedWalletView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @StateObject private var paymentService = PaymentService.shared
    
    @State private var userBalance: UserBalance?
    @State private var walletTransactions: [WalletTransaction] = []
    @State private var showingDepositSheet = false
    @State private var showingWithdrawSheet = false
    @State private var selectedGift: GiftType?
    @State private var showingGiftSheet = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Balance Header
                    VStack(spacing: 16) {
                        HStack {
                            Text("錢包")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Text("NTD 餘額")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        HStack {
                            Text("\(userBalance?.balance ?? 0)")
                                .font(.system(size: 36, weight: .bold))
                                .foregroundColor(Color(hex: "#00B900"))
                            
                            Spacer()
                        }
                        
                        // Payment Methods
                        HStack(spacing: 12) {
                            PaymentMethodButton(
                                title: "LINE Pay 儲值",
                                color: Color(hex: "#00B900"),
                                action: { showingDepositSheet = true }
                            )
                            
                            PaymentMethodButton(
                                title: "街口支付",
                                color: Color(.systemGray),
                                action: { showingDepositSheet = true }
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Gift Store
                    VStack(alignment: .leading, spacing: 16) {
                        Text("禮物商店")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        VStack(spacing: 12) {
                            ForEach(GiftType.allCases, id: \.self) { gift in
                                GiftCard(gift: gift) {
                                    selectedGift = gift
                                    showingGiftSheet = true
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Transaction History
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("交易紀錄")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("查看全部") {
                                // View all transactions
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        if walletTransactions.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary)
                                
                                Text("暫無交易紀錄")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                        } else {
                            LazyVStack(spacing: 12) {
                                ForEach(walletTransactions.prefix(5), id: \.id) { transaction in
                                    TransactionRow(transaction: transaction)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showingDepositSheet) {
                DepositSheetView { amount in
                    await handleDeposit(amount: amount)
                }
            }
            .sheet(isPresented: $showingWithdrawSheet) {
                WithdrawSheetView { amount in
                    await handleWithdraw(amount: amount)
                }
            }
            .sheet(isPresented: $showingGiftSheet) {
                if let gift = selectedGift {
                    GiftPurchaseSheetView(gift: gift) { gift, quantity in
                        await handleGiftPurchase(gift: gift, quantity: quantity)
                    }
                }
            }
        }
        .task {
            await loadWalletData()
        }
    }
    
    private func loadWalletData() async {
        guard let userId = supabaseService.getCurrentUser()?.id else { return }
        
        do {
            userBalance = try await supabaseService.fetchUserBalance(userId: userId)
            // Load transaction history would go here
        } catch {
            print("Failed to load wallet data: \(error)")
        }
    }
    
    private func handleDeposit(amount: Int) async {
        guard let userId = supabaseService.getCurrentUser()?.id else { return }
        
        let transaction = WalletTransaction(
            id: UUID(),
            userId: userId,
            transactionType: "deposit",
            amount: amount,
            description: "錢包儲值",
            status: "confirmed",
            paymentMethod: "line_pay",
            blockchainId: UUID().uuidString,
            createdAt: Date()
        )
        
        do {
            try await supabaseService.createWalletTransaction(transaction)
            await loadWalletData()
        } catch {
            print("Failed to process deposit: \(error)")
        }
    }
    
    private func handleWithdraw(amount: Int) async {
        guard let userId = supabaseService.getCurrentUser()?.id else { return }
        
        let transaction = WalletTransaction(
            id: UUID(),
            userId: userId,
            transactionType: "withdrawal",
            amount: amount,
            description: "錢包提領",
            status: "pending",
            paymentMethod: "bank_transfer",
            blockchainId: UUID().uuidString,
            createdAt: Date()
        )
        
        do {
            try await supabaseService.createWalletTransaction(transaction)
            await loadWalletData()
        } catch {
            print("Failed to process withdrawal: \(error)")
        }
    }
    
    private func handleGiftPurchase(gift: GiftType, quantity: Int) async {
        guard let userId = supabaseService.getCurrentUser()?.id else { return }
        
        let totalCost = gift.price * quantity
        
        do {
            try await paymentService.purchaseGift(type: gift, for: UUID()) // Group ID would be selected
            try await supabaseService.purchaseGift(
                userId: userId,
                giftId: UUID(), // Gift ID from database
                recipientGroupId: UUID(), // Selected group
                quantity: quantity,
                totalCost: totalCost
            )
            await loadWalletData()
        } catch {
            print("Failed to purchase gift: \(error)")
        }
    }
}

struct PaymentMethodButton: View {
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(color)
                .cornerRadius(10)
        }
    }
}

struct GiftCard: View {
    let gift: GiftType
    let onPurchase: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            Text(gift.emoji)
                .font(.system(size: 32))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(gift.rawValue.capitalized)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text(gift.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("NT$ \(gift.price)")
                    .font(.subheadline)
                    .fontWeight(.bold)
                
                Button(action: onPurchase) {
                    Text("購買")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .background(Color(hex: "#00B900"))
                        .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct TransactionRow: View {
    let transaction: WalletTransaction
    
    var body: some View {
        HStack {
            // Transaction Icon
            Circle()
                .fill(transactionColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: transactionIcon)
                        .foregroundColor(transactionColor)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(transaction.description)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if let createdAt = transaction.createdAt {
                    Text(createdAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text("\(transaction.transactionType == "deposit" ? "+" : "-")NT$ \(transaction.amount)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(transactionColor)
                
                Text(transaction.status)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 8)
    }
    
    private var transactionColor: Color {
        switch transaction.transactionType {
        case "deposit": return .green
        case "withdrawal": return .red
        default: return .blue
        }
    }
    
    private var transactionIcon: String {
        switch transaction.transactionType {
        case "deposit": return "arrow.down.circle"
        case "withdrawal": return "arrow.up.circle"
        case "gift_purchase": return "gift"
        default: return "dollarsign.circle"
        }
    }
    
    private var statusColor: Color {
        switch transaction.status {
        case "confirmed": return .green
        case "pending": return .orange
        case "failed": return .red
        default: return .gray
        }
    }
}

struct DepositSheetView: View {
    let onDeposit: (Int) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var selectedAmount = 1000
    
    private let predefinedAmounts = [500, 1000, 2000, 5000, 10000]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("選擇儲值金額")
                    .font(.headline)
                    .fontWeight(.bold)
                
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                    ForEach(predefinedAmounts, id: \.self) { amount in
                        Button {
                            selectedAmount = amount
                        } label: {
                            Text("NT$ \(amount)")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(selectedAmount == amount ? .white : .primary)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(selectedAmount == amount ? Color(hex: "#00B900") : Color(.systemGray6))
                                .cornerRadius(12)
                        }
                    }
                }
                
                Button {
                    Task {
                        await onDeposit(selectedAmount)
                        dismiss()
                    }
                } label: {
                    Text("確認儲值 NT$ \(selectedAmount)")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#00B900"))
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("錢包儲值")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct WithdrawSheetView: View {
    let onWithdraw: (Int) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var withdrawAmount = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("提領金額")
                    .font(.headline)
                    .fontWeight(.bold)
                
                TextField("輸入提領金額", text: $withdrawAmount)
                    .keyboardType(.numberPad)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("最低提領金額：NT$ 100")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Button {
                    if let amount = Int(withdrawAmount), amount >= 100 {
                        Task {
                            await onWithdraw(amount)
                            dismiss()
                        }
                    }
                } label: {
                    Text("確認提領")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#FD7E14"))
                        .cornerRadius(12)
                }
                .disabled(Int(withdrawAmount) ?? 0 < 100)
                
                Spacer()
            }
            .padding()
            .navigationTitle("錢包提領")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct GiftPurchaseSheetView: View {
    let gift: GiftType
    let onPurchase: (GiftType, Int) async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var quantity = 1
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Gift Display
                VStack(spacing: 16) {
                    Text(gift.emoji)
                        .font(.system(size: 80))
                    
                    Text(gift.rawValue.capitalized)
                        .font(.title2)
                        .fontWeight(.bold)
    
                    Text(gift.description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                // Quantity Selector
                VStack(spacing: 12) {
                    Text("數量")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    HStack(spacing: 20) {
                        Button {
                            if quantity > 1 { quantity -= 1 }
                        } label: {
                            Image(systemName: "minus.circle")
                                .font(.title2)
                                .foregroundColor(quantity > 1 ? .blue : .gray)
                        }
                        .disabled(quantity <= 1)
                        
                        Text("\(quantity)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .frame(minWidth: 40)
                        
                        Button {
                            quantity += 1
                        } label: {
                            Image(systemName: "plus.circle")
                                .font(.title2)
                                .foregroundColor(.blue)
                        }
                    }
                }
                
                // Total Cost
                VStack(spacing: 8) {
                    Text("總計")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("NT$ \(gift.price * quantity)")
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#00B900"))
                }
                
                Button {
                    Task {
                        await onPurchase(gift, quantity)
                        dismiss()
                    }
                } label: {
                    Text("確認購買")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color(hex: "#00B900"))
                        .cornerRadius(12)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("購買禮物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    EnhancedWalletView()
}