//
//  FriendSystemTestView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/21.
//  好友系統簡化測試界面
//

import SwiftUI

struct FriendSystemTestView: View {
    @EnvironmentObject private var friendService: FriendService
    @State private var testResults: [String] = []
    @State private var isRunningTests = false
    @State private var currentUserID: String?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 測試控制
                    testControlSection
                    
                    // 當前用戶信息
                    if let userID = currentUserID {
                        currentUserSection(userID)
                    }
                    
                    // 測試結果
                    testResultsSection
                    
                    Spacer(minLength: 50)
                }
                .padding()
            }
            .navigationTitle("好友系統測試")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            Task {
                currentUserID = await friendService.getCurrentUserID()
            }
        }
    }
    
    // MARK: - 測試控制區域
    
    private var testControlSection: some View {
        VStack(spacing: 16) {
            Text("🧪 好友系統測試")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("點擊下方按鈕測試不同功能")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            if isRunningTests {
                ProgressView("測試進行中...")
                    .frame(maxWidth: .infinity)
            } else {
                VStack(spacing: 12) {
                    Button("🔗 測試 Supabase 連接") {
                        Task { await runConnectionTest() }
                    }
                    .buttonStyle(.borderedProminent)
                    .frame(maxWidth: .infinity)
                    
                    Button("🔍 測試用戶搜尋") {
                        Task { await runSearchTest() }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("👥 測試好友請求") {
                        Task { await runFriendRequestTest() }
                    }
                    .buttonStyle(.bordered)
                    .frame(maxWidth: .infinity)
                    
                    Button("🗑️清除測試結果") {
                        testResults.removeAll()
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 當前用戶區域
    
    private func currentUserSection(_ userID: String) -> some View {
        VStack(spacing: 12) {
            HStack {
                Text("👤 我的用戶信息")
                    .font(.headline)
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("用戶 ID:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(userID)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(6)
                }
                
                Text("其他用戶可以搜尋這個 ID 來添加你為好友")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 測試結果區域
    
    private var testResultsSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("📊 測試結果")
                    .font(.headline)
                Spacer()
                
                if !testResults.isEmpty {
                    Text("\(testResults.count) 項")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if testResults.isEmpty {
                Text("尚未執行測試")
                    .font(.subheadline)
                    .foregroundColor(.gray)
                    .frame(maxWidth: .infinity)
                    .padding()
            } else {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(testResults.indices, id: \.self) { index in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .frame(width: 20, alignment: .leading)
                            
                            Text(testResults[index])
                                .font(.caption)
                                .foregroundColor(.primary)
                            
                            Spacer()
                        }
                        .padding(.vertical, 2)
                        
                        if index < testResults.count - 1 {
                            Divider()
                        }
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.05))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 測試函數
    
    private func runConnectionTest() async {
        isRunningTests = true
        addTestResult("🔗 開始測試 Supabase 連接...")
        
        let success = await friendService.testSupabaseConnection()
        
        if success {
            addTestResult("✅ Supabase 連接測試成功")
        } else {
            addTestResult("❌ Supabase 連接測試失敗: \(friendService.errorMessage ?? "未知錯誤")")
        }
        
        isRunningTests = false
    }
    
    private func runSearchTest() async {
        isRunningTests = true
        addTestResult("🔍 開始測試用戶搜尋...")
        
        // 測試搜尋已知的測試用戶
        let testUserIDs = ["123456", "789012", "456789"]
        
        for userID in testUserIDs {
            addTestResult("搜尋用戶 ID: \(userID)")
            
            let result = await friendService.searchUser(by: userID)
            
            if let user = result {
                addTestResult("✅ 找到用戶: \(user.displayName) (\(user.userID))")
                if user.isFriend {
                    addTestResult("👥 已經是好友")
                } else {
                    addTestResult("💬 可以發送好友請求")
                }
            } else {
                addTestResult("❌ 搜尋失敗: \(friendService.errorMessage ?? "找不到用戶")")
            }
        }
        
        isRunningTests = false
    }
    
    private func runFriendRequestTest() async {
        isRunningTests = true
        addTestResult("👥 開始測試好友請求...")
        
        // 測試發送好友請求給測試用戶
        let testUserID = "123456"
        addTestResult("向用戶 \(testUserID) 發送好友請求")
        
        let success = await friendService.sendFriendRequest(to: testUserID)
        
        if success {
            addTestResult("✅ 好友請求發送成功")
        } else {
            addTestResult("❌ 好友請求發送失敗: \(friendService.errorMessage ?? "未知錯誤")")
        }
        
        // 載入好友列表
        addTestResult("載入好友列表...")
        await friendService.loadFriends()
        addTestResult("📋 目前有 \(friendService.friends.count) 位好友")
        
        isRunningTests = false
    }
    
    private func addTestResult(_ message: String) {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .none, timeStyle: .medium)
        let result = "[\(timestamp)] \(message)"
        
        DispatchQueue.main.async {
            self.testResults.append(result)
        }
    }
}

#Preview {
    FriendSystemTestView()
        .environmentObject(FriendService.shared)
}