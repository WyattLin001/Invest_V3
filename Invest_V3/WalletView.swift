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
    @State private var showWithdrawalAlert = false
    @State private var showAuthorEarnings = false
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
                        
                        // 測試充值區塊（保留的重要功能）
                        testTopUpSection
                        
                        // 訂閱狀態卡片
                        subscriptionCard
                        
                        // 交易紀錄
                        transactionHistoryCard
                        
                        // 創作者收益
                        authorEarningsCard
                        
                        // 提領卡片
                        withdrawalCard
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
        .sheet(isPresented: $showAuthorEarnings) {
            AuthorEarningsView()
        }
        .alert("提領確認", isPresented: $showWithdrawalAlert) {
            Button("確認", role: .destructive) {
                Task {
                    // await viewModel.processWithdrawal()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("確定要提領 \(TokenSystem.formatTokens(viewModel.withdrawableAmount.ntdToTokens())) 到您的玉山銀行帳戶嗎？")
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
            Text(TokenSystem.formatTokens(viewModel.balance.ntdToTokens()))
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
                    Text(TokenSystem.formatTokens(viewModel.balance.ntdToTokens()))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.green)
                    
                    Text(TokenSystem.formatNTD(viewModel.balance))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // 操作按鈕區域
            HStack(spacing: 12) {
                Button(action: { showPaymentOptions = true }) {
                    Text("充值")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                
                Button(action: { showWithdrawalAlert = true }) {
                    Text("提領")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .cornerRadius(8)
                }
                .disabled(viewModel.withdrawableAmount <= 0)
                
                Spacer()
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 測試充值區塊 (重要功能 - 必須保留)
    private var testTopUpSection: some View {
        VStack(spacing: 16) {
            HStack {
                Text("測試充值功能 (重要：必須保留)")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            Text("點擊下方按鈕進行測試充值")
                .font(.caption)
                .foregroundColor(.secondary)
            
            HStack(spacing: 12) {
                TestTopUpButton(amount: 1000, label: "充值 10 代幣") {
                    await performTestTopUp(amount: 1000)
                }
                
                TestTopUpButton(amount: 5000, label: "充值 50 代幣") {
                    await performTestTopUp(amount: 5000)
                }
                
                TestTopUpButton(amount: 10000, label: "充值 100 代幣") {
                    await performTestTopUp(amount: 10000)
                }
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
                // 暫時顯示佔位符，因為 WalletTransaction 類型不可見
                Text("交易記錄載入中...")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .padding(.vertical, 24)
            }
        }
        .brandCardStyle()
    }

    // MARK: - 創作者收益卡片  
    private var authorEarningsCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("創作者收益")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Button("詳細") {
                    showAuthorEarnings = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            HStack(spacing: 16) {
                EarningsSourceMini(
                    icon: "📝",
                    title: "文章收益",
                    amount: 2650.0
                )
                
                EarningsSourceMini(
                    icon: "💰",
                    title: "投資建議",
                    amount: 8750.0
                )
                
                Spacer()
            }
        }
        .brandCardStyle()
    }

    // MARK: - 提領卡片
    private var withdrawalCard: some View {
        VStack(spacing: 16) {
            HStack {
                Text("可提領金額")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack {
                Text("提領到玉山銀行")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(TokenSystem.formatTokens(viewModel.withdrawableAmount.ntdToTokens()))
                    .font(.title3)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            
            Button(action: { showWithdrawalAlert = true }) {
                Text("提領")
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
            .disabled(viewModel.withdrawableAmount <= 0)
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

struct TestTopUpButton: View {
    let amount: Double
    let label: String
    let action: () async -> Void
    
    var body: some View {
        Button(action: {
            Task {
                await action()
            }
        }) {
            Text(label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue)
                .cornerRadius(6)
        }
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
