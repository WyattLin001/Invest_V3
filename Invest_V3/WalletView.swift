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
                    
                    Text("每月 3 代幣")
                        .font(.footnote) // 使用自定義字體
                        .foregroundColor(.gray600)
                }
                
                Spacer()
                
                Button(action: { showSubscriptionSheet = true }) {
                    Text(viewModel.isSubscribed ? "已訂閱" : "訂閱")
                        .font(.bodyText) // 使用自定義字體
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, DesignTokens.spacingMD)
                        .padding(.vertical, DesignTokens.spacingSM)
                        .background(viewModel.isSubscribed ? Color.gray400 : Color.brandGreen)
                        .cornerRadius(DesignTokens.cornerRadius)
                }
                .disabled(viewModel.isSubscribed)
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
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.type.displayName)
                    .font(.bodyText) // 使用自定義字體
                    .fontWeight(.medium)
                    .foregroundColor(.gray900)
                
                Text(transaction.id.uuidString.prefix(8) + "...")
                    .font(.footnote) // 使用自定義字體
                    .foregroundColor(.gray600)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(transaction.amount > 0 ? "+" : "")\(TokenSystem.formatTokens(abs(Double(transaction.amount)).ntdToTokens()))")
                    .font(.bodyText) // 使用自定義字體
                    .fontWeight(.medium)
                    .foregroundColor(transaction.amount > 0 ? .brandGreen : .brandOrange)
                
                HStack(spacing: 4) {
                    Circle()
                        .fill(transaction.transactionStatus == .confirmed ? Color.brandGreen : Color.warning)
                        .frame(width: 6, height: 6)
                    
                    Text(transaction.transactionStatus.displayName)
                        .font(.footnote) // 使用自定義字體
                        .foregroundColor(.gray600)
                }
            }
            
            Button(action: {
                // if let url = URL(string: "https://solscan.io/tx/\(transaction.id)") {
                //     UIApplication.shared.open(url)
                // }
            }) {
                Image(systemName: "link")
                    .font(.footnote) // 使用自定義字體
                    .foregroundColor(.brandGreen)
            }
        }
        .padding(.vertical, DesignTokens.spacingSM)
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
