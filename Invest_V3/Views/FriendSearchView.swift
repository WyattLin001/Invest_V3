//
//  FriendSearchView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/21.
//  好友搜尋和管理頁面
//

import SwiftUI

struct FriendSearchView: View {
    @EnvironmentObject private var friendService: FriendService
    @State private var searchUserID = ""
    @State private var searchResult: UserSearchResult?
    @State private var currentUserID: String?
    @State private var showConnectionTest = false
    @State private var connectionTestResult: Bool?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 當前用戶信息
                    currentUserCard
                    
                    // 連接測試
                    connectionTestCard
                    
                    // 搜尋用戶
                    searchUserCard
                    
                    // 搜尋結果
                    if let result = searchResult {
                        searchResultCard(result)
                    }
                    
                    // 好友列表
                    friendsListCard
                    
                    Spacer(minLength: 100)
                }
                .padding()
            }
            .navigationTitle("好友管理")
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
                await friendService.loadFriends()
            }
        }
    }
    
    // MARK: - 當前用戶卡片
    
    private var currentUserCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("我的用戶 ID")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                if let userID = currentUserID {
                    Text(userID)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(8)
                } else {
                    Text("未設定")
                        .font(.subheadline)
                        .foregroundColor(.red)
                }
            }
            
            if currentUserID != nil {
                Text("其他用戶可以用這個 ID 找到並添加你為好友")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 連接測試卡片
    
    private var connectionTestCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Supabase 連接測試")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                if let result = connectionTestResult {
                    Circle()
                        .fill(result ? .green : .red)
                        .frame(width: 12, height: 12)
                }
            }
            
            HStack {
                Button("測試連接") {
                    Task {
                        showConnectionTest = true
                        connectionTestResult = await friendService.testSupabaseConnection()
                        showConnectionTest = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(showConnectionTest)
                
                Spacer()
                
                if showConnectionTest {
                    ProgressView()
                        .controlSize(.small)
                } else if let result = connectionTestResult {
                    Text(result ? "連接正常" : "連接失敗")
                        .font(.subheadline)
                        .foregroundColor(result ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 搜尋用戶卡片
    
    private var searchUserCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("搜尋好友")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
            }
            
            HStack {
                TextField("輸入用戶 ID（6位數字以上）", text: $searchUserID)
                    .textFieldStyle(.roundedBorder)
                    .keyboardType(.numberPad)
                
                Button("搜尋") {
                    Task {
                        let result = await friendService.searchUser(by: searchUserID)
                        await MainActor.run {
                            searchResult = result
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .disabled(friendService.isLoading || searchUserID.count < 6)
            }
            
            if friendService.isLoading {
                HStack {
                    ProgressView()
                        .controlSize(.small)
                    Text("搜尋中...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            if let error = friendService.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 搜尋結果卡片
    
    private func searchResultCard(_ user: UserSearchResult) -> some View {
        VStack(spacing: 12) {
            HStack {
                // 頭像
                AsyncImage(url: user.avatarUrl.flatMap(URL.init)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.gray)
                        )
                }
                .frame(width: 50, height: 50)
                .clipShape(Circle())
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.displayName)
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("ID: \(user.userID)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    if let bio = user.bio, !bio.isEmpty {
                        Text(bio)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }
                }
                
                Spacer()
                
                // 操作按鈕
                VStack(spacing: 8) {
                    if user.isFriend {
                        Text("已是好友")
                            .font(.caption)
                            .foregroundColor(.green)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 4)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(6)
                    } else {
                        Button("加好友") {
                            Task {
                                let success = await friendService.sendFriendRequest(to: user.userID)
                                if success {
                                    // 清除搜尋結果
                                    searchResult = nil
                                    searchUserID = ""
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                        .disabled(friendService.isLoading)
                    }
                }
            }
        }
        .padding()
        .background(Color.green.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 好友列表卡片
    
    private var friendsListCard: some View {
        VStack(spacing: 12) {
            HStack {
                Text("我的好友")
                    .font(.headline)
                    .foregroundColor(.primary)
                Spacer()
                
                Text("\(friendService.friends.count)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.blue)
            }
            
            if friendService.friends.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "person.2")
                        .font(.system(size: 40))
                        .foregroundColor(.gray)
                    
                    Text("還沒有好友")
                        .font(.subheadline)
                        .foregroundColor(.gray)
                    
                    Text("使用上方搜尋功能來添加好友")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(friendService.friends) { friend in
                        friendRowView(friend)
                    }
                }
            }
        }
        .padding()
        .background(Color.purple.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - 好友行視圖
    
    private func friendRowView(_ friend: FriendInfo) -> some View {
        HStack(spacing: 12) {
            // 頭像
            AsyncImage(url: friend.friendAvatarUrl.flatMap(URL.init)) { image in
                image
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } placeholder: {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundColor(.gray)
                    )
            }
            .frame(width: 40, height: 40)
            .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(friend.friendDisplayName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text("ID: \(friend.friendCustomID)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(friend.status.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .cornerRadius(4)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    FriendSearchView()
        .environmentObject(FriendService.shared)
}