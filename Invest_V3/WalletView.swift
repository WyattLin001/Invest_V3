//
//  WalletView.swift
//  Invest_App
//
//  Created by 林家麒 on 2025/7/8.
//

import SwiftUI
import StoreKit

struct WalletView: View {
    @EnvironmentObject private var authService: AuthenticationService
    @StateObject private var viewModel = WalletViewModel()
    
    @State private var showPaymentOptions = false
    @State private var showSubscriptionSheet = false
    @State private var selectedGift: GiftItem?
    @State private var giftQuantity = 1
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
                HStack {
                    Text("錢包")
                        .font(.titleLarge) // 使用自定義字體
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                    Spacer()
                    Text(TokenSystem.formatTokens(viewModel.balance.ntdToTokens()))
                        .font(.titleLarge) // 使用自定義字體
                        .fontWeight(.bold)
                        .foregroundColor(.brandGreen)
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .frame(height: 44)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray300),
                    alignment: .bottom
                )

                ScrollView {
                    LazyVStack(spacing: DesignTokens.spacingLG) {
                        // 餘額卡片
                        balanceCard
                        
                        // 訂閱狀態卡片
                        subscriptionCard
                        
                        // 禮物商店
                        giftShopCard
                        
                        // 交易紀錄
                        transactionHistoryCard
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.vertical, DesignTokens.spacingLG)
                }
                .background(Color.gray100)
            }
            .navigationBarHidden(true)
        }
        .sheet(isPresented: $showPaymentOptions) {
            PaymentOptionsView()
        }
        .sheet(isPresented: $showSubscriptionSheet) {
            SubscriptionView()
        }
        .sheet(item: $selectedGift) { gift in
            GiftPurchaseView(gift: gift, quantity: $giftQuantity)
        }
        .sheet(isPresented: $showAuthorEarnings) {
            AuthorEarningsView()
        }
        .alert("提領確認", isPresented: $showWithdrawalAlert) {
            Button("確認", role: .destructive) {
                Task {
                    await viewModel.processWithdrawal()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("確定要提領 \(TokenSystem.formatTokens(viewModel.withdrawableAmount.ntdToTokens())) 到您的玉山銀行帳戶嗎？")
        }
        .alert("取消訂閱", isPresented: $showCancelSubscriptionAlert) {
            Button("確認取消", role: .destructive) {
                Task {
                    await viewModel.cancelSubscription()
                }
            }
            Button("保留訂閱", role: .cancel) {}
        } message: {
            Text("確定要取消訂閱嗎？取消後將無法享受會員專屬內容。")
        }
        .onAppear {
            Task {
                await viewModel.loadData()
            }
        }
    }
    
    private var walletContentView: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部導航欄
                HStack {
                    Text("錢包")
                        .font(.titleLarge) // 使用自定義字體
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                    Spacer()
                    Text(TokenSystem.formatTokens(viewModel.balance.ntdToTokens()))
                        .font(.titleLarge) // 使用自定義字體
                        .fontWeight(.bold)
                        .foregroundColor(.brandGreen)
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .frame(height: 44)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray300),
                    alignment: .bottom
                )

                ScrollView {
                    LazyVStack(spacing: DesignTokens.spacingLG) {
                        // 餘額卡片
                        balanceCard
                        
                        // 訂閱狀態卡片
                        subscriptionCard
                        
                        // 禮物商店
                        giftShopCard
                        
                        // 交易記錄
                        transactionHistoryCard
                        
                        // 作者收益區（主持人/創作者專用）
                        if viewModel.isCreator {
                            authorEarningsCard
                        }
                        
                        // 提領區（主持人/創作者專用）
                        if viewModel.isCreator {
                            withdrawalCard
                        }
                        
                        // 底部間距
                        Color.clear.frame(height: 100)
                    }
                    .padding(.horizontal, DesignTokens.spacingMD)
                    .padding(.top, DesignTokens.spacingMD)
                }
                .background(Color.gray100)
            }
        }
    }
    
    // MARK: - 餘額卡片
    private var balanceCard: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            HStack {
                Text("餘額")
                    .font(.sectionHeader) // 使用自定義字體
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TokenSystem.formatTokens(viewModel.balance.ntdToTokens()))
                        .font(.system(size: 28, weight: .bold)) // 使用自定義字體
                        .fontWeight(.bold)
                        .foregroundColor(.brandGreen)
                    
                    Text("可用餘額")
                        .font(.footnote) // 使用自定義字體
                        .foregroundColor(.gray600)
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: { showPaymentOptions = true }) {
                        Text("儲值")
                            .font(.bodyText) // 使用自定義字體
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignTokens.spacingMD)
                            .padding(.vertical, DesignTokens.spacingSM)
                            .background(Color.brandOrange)
                            .cornerRadius(DesignTokens.cornerRadius)
                    }
                    
                    // 測試充值按鈕
                    HStack(spacing: 8) {
                        TestTopUpButton(amount: 1000, label: "+10🪙") {
                            await performTestTopUp(amount: 1000)
                        }
                        
                        TestTopUpButton(amount: 5000, label: "+50🪙") {
                            await performTestTopUp(amount: 5000)
                        }
                        
                        TestTopUpButton(amount: 10000, label: "+100🪙") {
                            await performTestTopUp(amount: 10000)
                        }
                    }
                    .opacity(0.8)
                }
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 訂閱狀態卡片
    private var subscriptionCard: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            HStack {
                Text("訂閱狀態")
                    .font(.sectionHeader) // 使用自定義字體
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isSubscribed ? Color.brandGreen : Color.gray400)
                            .frame(width: 8, height: 8)
                        
                        Text(viewModel.isSubscribed ? "已訂閱" : "未訂閱")
                            .font(.bodyText) // 使用自定義字體
                            .fontWeight(.medium)
                            .foregroundColor(viewModel.isSubscribed ? .brandGreen : .gray600)
                    }
                    
                    if viewModel.isSubscribed {
                        if let expiryDate = viewModel.subscriptionExpiryDate {
                            Text("到期日：\(expiryDate.formatted(.dateTime.month().day()))")
                                .font(.footnote)
                                .foregroundColor(.gray600)
                        }
                        Text("方案：\(viewModel.subscriptionPlan == "monthly" ? "月費" : "年費")")
                            .font(.footnote)
                            .foregroundColor(.gray600)
                    } else {
                        Text("每月 3 代幣")
                            .font(.footnote) // 使用自定義字體
                            .foregroundColor(.gray600)
                    }
                }
                
                Spacer()
                
                VStack(spacing: 8) {
                    Button(action: { 
                        if viewModel.isSubscribed {
                            showCancelSubscriptionAlert = true
                        } else {
                            showSubscriptionSheet = true
                        }
                    }) {
                        Text(viewModel.isSubscribed ? "管理訂閱" : "訂閱")
                            .font(.bodyText) // 使用自定義字體
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignTokens.spacingMD)
                            .padding(.vertical, DesignTokens.spacingSM)
                            .background(viewModel.isSubscribed ? Color.brandOrange : Color.brandGreen)
                            .cornerRadius(DesignTokens.cornerRadius)
                    }
                    
                    if viewModel.isSubscribed {
                        Button("取消訂閱") {
                            showCancelSubscriptionAlert = true
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 禮物商店卡片
    private var giftShopCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("禮物商店")
                .font(.sectionHeader) // 使用自定義字體
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingMD) {
                    ForEach(viewModel.gifts) { gift in
                        VStack(spacing: DesignTokens.spacingSM) {
                            Text(gift.icon)
                                .font(.system(size: 32))
                            
                            Text(gift.name)
                                .font(.footnote) // 使用自定義字體
                                .fontWeight(.medium)
                                .foregroundColor(.gray900)
                            
                            Text(TokenSystem.formatTokens(gift.price.ntdToTokens()))
                                .font(.tag) // 使用自定義字體
                                .foregroundColor(.gray600)
                            
                            Button(action: { selectedGift = gift; giftQuantity = 1 }) {
                                Text("購買")
                                    .font(.footnote) // 使用自定義字體
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, DesignTokens.spacingSM)
                                    .padding(.vertical, 4)
                                    .background(Color.brandGreen)
                                    .cornerRadius(DesignTokens.cornerRadiusSM)
                            }
                        }
                        .frame(width: 80)
                        .padding(.vertical, DesignTokens.spacingSM)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingSM)
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 交易記錄卡片
    private var transactionHistoryCard: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("交易記錄")
                .font(.sectionHeader) // 使用自定義字體
                .fontWeight(.semibold)
                .foregroundColor(.gray900)
            
            if viewModel.transactions.isEmpty {
                Text("暫無交易記錄")
                    .font(.bodyText) // 使用自定義字體
                    .foregroundColor(.gray600)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, DesignTokens.spacingLG)
            } else {
                ForEach(viewModel.transactions, id: \.id) { transaction in
                    transactionRow(transaction)
                    
                    if transaction.id != viewModel.transactions.last?.id {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.gray300)
                    }
                }
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 提領卡片
    private var withdrawalCard: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            HStack {
                Text("可提領金額")
                    .font(.sectionHeader) // 使用自定義字體
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                Spacer()
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(TokenSystem.formatTokens(viewModel.withdrawableAmount.ntdToTokens()))
                        .font(.titleLarge) // 使用自定義字體
                        .fontWeight(.bold)
                        .foregroundColor(.brandGreen)
                    
                    Text("玉山銀行帳戶")
                        .font(.footnote) // 使用自定義字體
                        .foregroundColor(.gray600)
                }
                
                Spacer()
                
                Button(action: { showWithdrawalAlert = true }) {
                    Text("提領")
                        .font(.bodyText) // 使用自定義字體
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(Color.brandOrange)
                        .cornerRadius(DesignTokens.cornerRadius)
                }
                .disabled(viewModel.withdrawableAmount <= 0)
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 交易記錄行
    private func transactionRow(_ transaction: WalletTransaction) -> some View {
        HStack(spacing: 12) {
            // 交易類型圖標
            ZStack {
                Circle()
                    .fill(transaction.type.backgroundColor)
                    .frame(width: 40, height: 40)
                
                Image(systemName: transaction.type.iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(transaction.type.iconColor)
            }
            
            // 交易信息
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(transaction.type.displayName)
                        .font(.bodyText)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray900)
                    
                    Spacer()
                    
                    Text("\(transaction.amount > 0 ? "+" : "")\(TokenSystem.formatTokens(abs(Double(transaction.amount)).ntdToTokens()))")
                        .font(.bodyText)
                        .fontWeight(.bold)
                        .foregroundColor(transaction.amount > 0 ? .brandGreen : .brandOrange)
                }
                
                HStack {
                    Text(transaction.createdAt.formatted(.dateTime.month().day().hour().minute()))
                        .font(.footnote)
                        .foregroundColor(.gray600)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Circle()
                            .fill(transaction.transactionStatus.statusColor)
                            .frame(width: 6, height: 6)
                        
                        Text(transaction.transactionStatus.displayName)
                            .font(.footnote)
                            .foregroundColor(.gray600)
                    }
                }
                
                // 交易描述（如果有的話）
                if !transaction.description.isEmpty && transaction.description != transaction.type.displayName {
                    Text(transaction.description)
                        .font(.caption)
                        .foregroundColor(.gray500)
                        .lineLimit(1)
                }
            }
        }
        .padding(.vertical, 8)
        .background(Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            // 可以添加查看交易詳情的功能
        }
    }
    
    // MARK: - 作者收益卡片
    private var authorEarningsCard: some View {
        VStack(spacing: DesignTokens.spacingMD) {
            HStack {
                Text("創作者收益")
                    .font(.sectionHeader)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                Spacer()
                
                Button("查看詳情") {
                    showAuthorEarnings = true
                }
                .font(.caption)
                .foregroundColor(.brandGreen)
            }
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("本月收益")
                        .font(.footnote)
                        .foregroundColor(.gray600)
                    
                    Text(TokenSystem.formatTokens(2650.0))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.brandGreen)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("總收益")
                        .font(.footnote)
                        .foregroundColor(.gray600)
                    
                    Text(TokenSystem.formatTokens(8750.0))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.gray900)
                }
            }
            
            HStack(spacing: 12) {
                EarningsSourceMini(icon: "📰", title: "文章", amount: 950.0)
                EarningsSourceMini(icon: "👥", title: "訂閱", amount: 1200.0)
                EarningsSourceMini(icon: "🎁", title: "禮物", amount: 500.0)
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 測試充值功能
    private func performTestTopUp(amount: Double) async {
        topUpAmount = amount
        showTopUpAnimation = true
        
        // 執行充值
        await viewModel.topUp10K()
        
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
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(.brandGreen)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.brandGreen.opacity(0.1))
                .cornerRadius(8)
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
                .foregroundColor(.gray600)
            
            Text(TokenSystem.formatTokens(amount))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.brandGreen)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.gray100)
        .cornerRadius(8)
    }
}

// MARK: - 預覽
struct WalletView_Previews: PreviewProvider {
    static var previews: some View {
        WalletView()
            .environmentObject(AuthenticationService())
            .preferredColorScheme(.light)
        
        WalletView()
            .environmentObject(AuthenticationService())
            .preferredColorScheme(.dark)
    }
}
