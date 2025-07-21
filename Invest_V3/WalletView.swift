//
//  WalletView.swift
//  Invest_V3
//
//  Created by 林家麒 on 2025/7/8.
//  Integrated by AI Assistant on 2025/7/19.
//

import SwiftUI
import StoreKit

struct WalletView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel = WalletViewModel()
    
    @State private var showPaymentOptions = false
    @State private var showSubscriptionSheet = false
    @State private var showGiftAnimation = false
    @State private var showTopUpOptions = false
    @State private var showTopUpAnimation = false
    @State private var topUpAmount: Double = 0
    @State private var showCancelSubscriptionAlert = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部導航欄
                walletHeader
                
                // 主要內容區域
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // 餘額卡片
                        balanceCard
                        
                        // 訂閱狀態卡片
                        subscriptionCard
                        
                        // 交易紀錄
                        transactionHistoryCard
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
                }
                .background(Color(red: 0.95, green: 0.95, blue: 0.95))
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPaymentOptions) {
            PaymentOptionsView()
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            Text("訂閱功能")  // 簡化實現
        }
        .sheet(isPresented: $showTopUpOptions) {
            TopUpOptionsView { amount in
                Task {
                    await performTestTopUp(amount: amount)
                }
                showTopUpOptions = false
            }
        }
        .task {
            await viewModel.loadData()
        }
    }
    
    // MARK: - 錢包標題
    private var walletHeader: some View {
        HStack {
            Text("錢包")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.primary)
            Spacer()
            Text(TokenSystem.formatTokens(viewModel.balance))
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.green)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(Color(red: 0.98, green: 0.98, blue: 0.98))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.gray),
            alignment: .bottom
        )
    }
    
    // MARK: - 餘額卡片
    private var balanceCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("錢包餘額")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(TokenSystem.formatTokens(viewModel.balance))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text(TokenSystem.formatNTD(viewModel.balance))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 充值按鈕（整合測試充值功能）
            HStack(spacing: 12) {
                Button(action: { 
                    showTopUpOptions = true 
                }) {
                    Text("充值")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Spacer()
            }
        }
        .brandCardStyle()
    }
    
    
    // MARK: - 訂閱狀態卡片
    private var subscriptionCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("訂閱狀態")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Text("專業會員")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue)
                    .cornerRadius(4)
            }
            
            HStack {
                Text("下次扣款日期")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("2024/08/15")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 交易記錄卡片
    private var transactionHistoryCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("最近交易")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Button("查看全部") {
                    // 導航到完整交易記錄
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            if viewModel.transactions.isEmpty {
                Text("暫無交易記錄")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 24)
            } else {
                // 顯示最近的交易記錄
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.transactions) { transaction in
                        TransactionRowView(transaction: transaction)
                    }
                }
            }
        }
        .brandCardStyle()
    }

    
    // MARK: - 測試充值功能
    private func performTestTopUp(amount: Double) async {
        topUpAmount = amount
        showTopUpAnimation = true
        
        // 計算代幣數量 (1代幣 = 100 NTD)
        let tokens = Int(amount / 100)
        
        // 執行充值
        await viewModel.performTestTopUp(tokens: tokens)
        
        // 動畫效果
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            // 可以添加視覺效果
        }
        
        // 延遲隱藏動畫
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showTopUpAnimation = false
        }
    }
}

// MARK: - 支援元件

struct TopUpOptionsView: View {
    let onTopUp: (Double) -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("選擇充值金額")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("測試版本：選擇金額將直接加值到您的代幣錢包")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                VStack(spacing: 16) {
                    TopUpOptionButton(amount: 1000, tokens: 10, onTap: onTopUp)
                    TopUpOptionButton(amount: 5000, tokens: 50, onTap: onTopUp)
                    TopUpOptionButton(amount: 10000, tokens: 100, onTap: onTopUp)
                }
                
                Spacer()
            }
            .padding(24)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TopUpOptionButton: View {
    let amount: Double
    let tokens: Int
    let onTap: (Double) -> Void
    
    var body: some View {
        Button(action: {
            onTap(amount)
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("充值 \(tokens) 代幣")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("NT$\(Int(amount))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .padding(16)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct TransactionRowView: View {
    let transaction: WalletTransaction
    
    var body: some View {
        HStack(spacing: 12) {
            // 交易類型圖示
            Image(systemName: transaction.icon)
                .font(.title3)
                .foregroundColor(transaction.iconColor)
                .frame(width: 24, height: 24)
            
            // 交易詳情
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.displayName)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(transaction.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 金額和時間
            VStack(alignment: .trailing, spacing: 2) {
                Text(transaction.formattedAmount)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(transaction.amount >= 0 ? .green : .red)
                
                Text(transaction.formattedDate)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}


struct EarningsSourceMini: View {
    let icon: String
    let title: String
    let amount: Double
    
    var body: some View {
        VStack(spacing: 4) {
            Text(icon)
                .font(.title3)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            
            Text(TokenSystem.formatTokens(amount))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview
#Preview {
    WalletView()
        .environmentObject(AuthenticationService())
}
