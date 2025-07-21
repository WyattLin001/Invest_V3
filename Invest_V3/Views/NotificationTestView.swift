//
//  NotificationTestView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/21.
//  推播通知測試頁面
//

import SwiftUI

struct NotificationTestView: View {
    @EnvironmentObject private var notificationService: NotificationService
    @State private var showPermissionAlert = false
    @State private var testMessage = "這是一個測試訊息"
    @State private var testStockSymbol = "2330"
    @State private var testStockName = "台積電"
    @State private var testTargetPrice: Double = 600.0
    @State private var testCurrentPrice: Double = 605.0
    @State private var testRank = 5
    @State private var testPreviousRank = 8
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 權限狀態
                    permissionStatusCard
                    
                    // 未讀通知數量
                    unreadCountCard
                    
                    // 通知測試按鈕
                    testButtonsSection
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("推播通知測試")
            .navigationBarTitleDisplayMode(.inline)
        }
        .alert("需要推播通知權限", isPresented: $showPermissionAlert) {
            Button("前往設定") {
                openAppSettings()
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("請在設定中開啟推播通知權限，以便接收重要訊息。")
        }
        .onAppear {
            Task {
                await notificationService.loadUnreadCount()
            }
        }
    }
    
    // MARK: - 權限狀態卡片
    
    private var permissionStatusCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("推播通知權限")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Circle()
                    .fill(notificationService.isAuthorized ? .green : .red)
                    .frame(width: 12, height: 12)
            }
            
            HStack {
                Text(notificationService.isAuthorized ? "已授權" : "未授權")
                    .font(.subheadline)
                    .foregroundColor(notificationService.isAuthorized ? .green : .red)
                
                Spacer()
                
                if !notificationService.isAuthorized {
                    Button("請求權限") {
                        Task {
                            let granted = await notificationService.requestPermission()
                            if !granted {
                                showPermissionAlert = true
                            }
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if let deviceToken = notificationService.deviceToken {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Device Token:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(String(deviceToken.prefix(40)) + "...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 未讀通知數量卡片
    
    private var unreadCountCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("未讀通知")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Text("\(notificationService.unreadCount)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            HStack {
                Button("重新載入") {
                    Task {
                        await notificationService.loadUnreadCount()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                
                Spacer()
                
                Button("清除所有") {
                    Task {
                        await notificationService.clearAllNotifications()
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 測試按鈕區域
    
    private var testButtonsSection: some View {
        VStack(spacing: 16) {
            Text("測試推播通知")
                .font(.title2)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            // 主持人訊息測試
            VStack(spacing: 8) {
                HStack {
                    Text("主持人訊息")
                        .font(.headline)
                    Spacer()
                }
                
                TextField("輸入測試訊息", text: $testMessage)
                    .textFieldStyle(.roundedBorder)
                
                Button("發送主持人訊息通知") {
                    Task {
                        await notificationService.sendHostMessageNotification(
                            hostName: "投資大師王",
                            message: testMessage,
                            groupId: "test_group_001"
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.green.opacity(0.1))
            .cornerRadius(12)
            
            // 排名更新測試
            VStack(spacing: 8) {
                HStack {
                    Text("排名更新")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    VStack {
                        Text("新排名")
                            .font(.caption)
                        TextField("排名", value: $testRank, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack {
                        Text("前排名")
                            .font(.caption)
                        TextField("前排名", value: $testPreviousRank, format: .number)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Button("發送排名更新通知") {
                    Task {
                        await notificationService.sendRankingUpdateNotification(
                            newRank: testRank,
                            previousRank: testPreviousRank
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            
            // 股價提醒測試
            VStack(spacing: 8) {
                HStack {
                    Text("股價提醒")
                        .font(.headline)
                    Spacer()
                }
                
                HStack {
                    VStack {
                        Text("股票代號")
                            .font(.caption)
                        TextField("代號", text: $testStockSymbol)
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack {
                        Text("股票名稱")
                            .font(.caption)
                        TextField("名稱", text: $testStockName)
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                HStack {
                    VStack {
                        Text("目標價格")
                            .font(.caption)
                        TextField("目標價", value: $testTargetPrice, format: .currency(code: "TWD"))
                            .textFieldStyle(.roundedBorder)
                    }
                    
                    VStack {
                        Text("當前價格")
                            .font(.caption)
                        TextField("當前價", value: $testCurrentPrice, format: .currency(code: "TWD"))
                            .textFieldStyle(.roundedBorder)
                    }
                }
                
                Button("發送股價提醒通知") {
                    Task {
                        await notificationService.sendStockPriceAlert(
                            stockSymbol: testStockSymbol,
                            stockName: testStockName,
                            targetPrice: testTargetPrice,
                            currentPrice: testCurrentPrice
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.purple.opacity(0.1))
            .cornerRadius(12)
            
            // 一般本地通知測試
            Button("發送簡單測試通知") {
                Task {
                    await notificationService.sendLocalNotification(
                        title: "測試通知",
                        body: "這是一個測試推播通知，用於確認功能正常運作。",
                        delay: 1.0
                    )
                }
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.bordered)
        }
    }
    
    // MARK: - 輔助方法
    
    private func openAppSettings() {
        if let settingsUrl = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsUrl)
        }
    }
}

#Preview {
    NotificationTestView()
        .environmentObject(NotificationService.shared)
}