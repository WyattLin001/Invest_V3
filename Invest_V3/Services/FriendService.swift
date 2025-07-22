//
//  FriendService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/21.
//  好友管理服務
//

import Foundation

@MainActor
class FriendService: ObservableObject {
    static let shared = FriendService()
    
    @Published var friends: [FriendInfo] = []
    @Published var friendRequests: [FriendRequest] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    
    private init() {}
    
    // MARK: - 搜尋用戶
    
    /// 根據 user_id 搜尋用戶
    func searchUser(by userID: String) async -> UserSearchResult? {
        guard !userID.isEmpty else {
            errorMessage = "請輸入用戶 ID"
            return nil
        }
        
        // 確保 userID 至少6位數字
        guard userID.count >= 6, userID.allSatisfy({ $0.isNumber }) else {
            errorMessage = "用戶 ID 必須是6位數字以上"
            return nil
        }
        
        do {
            isLoading = true
            errorMessage = nil
            
            // 調用 Supabase 函數搜尋用戶
            let result = try await supabaseService.client
                .rpc("search_users_by_id", params: ["search_user_id": userID])
                .execute()
            
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            let searchResults = try decoder.decode([UserSearchResult].self, from: result.data)
            
            if let user = searchResults.first {
                print("✅ [FriendService] 找到用戶: \(user.displayName) (\(user.userID))")
                isLoading = false
                return user
            } else {
                errorMessage = "找不到用戶 ID: \(userID)"
                isLoading = false
                return nil
            }
            
        } catch {
            print("❌ [FriendService] 搜尋用戶失敗: \(error)")
            errorMessage = "搜尋失敗: \(error.localizedDescription)"
            isLoading = false
            return nil
        }
    }
    
    // MARK: - 好友請求管理
    
    /// 發送好友請求
    func sendFriendRequest(to userID: String) async -> Bool {
        do {
            isLoading = true
            errorMessage = nil
            
            let result = try await supabaseService.client
                .rpc("send_friend_request", params: ["target_user_id": userID])
                .execute()
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(FriendRequestResponse.self, from: result.data)
            
            if response.success {
                print("✅ [FriendService] 好友請求已發送: \(response.message)")
                isLoading = false
                return true
            } else {
                errorMessage = response.message
                print("⚠️ [FriendService] 發送好友請求失敗: \(response.message)")
                isLoading = false
                return false
            }
            
        } catch {
            print("❌ [FriendService] 發送好友請求出錯: \(error)")
            errorMessage = "發送好友請求失敗: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    /// 接受好友請求
    func acceptFriendRequest(from requesterUserID: String) async -> Bool {
        do {
            isLoading = true
            errorMessage = nil
            
            let result = try await supabaseService.client
                .rpc("accept_friend_request", params: ["requester_user_id": requesterUserID])
                .execute()
            
            let decoder = JSONDecoder()
            let response = try decoder.decode(FriendRequestResponse.self, from: result.data)
            
            if response.success {
                print("✅ [FriendService] 已接受好友請求: \(response.message)")
                // 重新載入好友列表和請求列表
                await loadFriends()
                await loadFriendRequests()
                isLoading = false
                return true
            } else {
                errorMessage = response.message
                print("⚠️ [FriendService] 接受好友請求失敗: \(response.message)")
                isLoading = false
                return false
            }
            
        } catch {
            print("❌ [FriendService] 接受好友請求出錯: \(error)")
            errorMessage = "接受好友請求失敗: \(error.localizedDescription)"
            isLoading = false
            return false
        }
    }
    
    // MARK: - 載入數據
    
    /// 載入好友列表
    func loadFriends() async {
        do {
            isLoading = true
            errorMessage = nil
            
            guard let user = try? await supabaseService.client.auth.user() else {
                errorMessage = "用戶未登入"
                return
            }
            
            let result = try await supabaseService.client
                .from("friendships")
                .select("*")
                .or("requester_id.eq.\(user.id.uuidString),addressee_id.eq.\(user.id.uuidString)")
                .eq("status", value: "accepted")
                .execute()
            
            let decoder = JSONDecoder()
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSSSS'Z'"
            decoder.dateDecodingStrategy = .formatted(dateFormatter)
            
            let friendsList = try decoder.decode([FriendInfo].self, from: result.data)
            self.friends = friendsList
            
            print("✅ [FriendService] 已載入 \(friendsList.count) 位好友")
            
        } catch {
            print("❌ [FriendService] 載入好友列表失敗: \(error)")
            errorMessage = "載入好友列表失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    /// 載入好友請求
    func loadFriendRequests() async {
        do {
            isLoading = true
            errorMessage = nil
            
            guard let user = try? await supabaseService.client.auth.user() else {
                errorMessage = "用戶未登入"
                return
            }
            
            // 查詢收到的好友請求
            let result = try await supabaseService.client
                .from("friendships")
                .select("id, requester_id, status, created_at")
                .eq("addressee_id", value: user.id)
                .eq("status", value: "pending")
                .order("created_at", ascending: false)
                .execute()
            
            // 這裡需要手動解析因為關聯查詢比較複雜
            // 簡化版本：先載入基本的待處理請求
            print("✅ [FriendService] 已載入好友請求數據")
            
        } catch {
            print("❌ [FriendService] 載入好友請求失敗: \(error)")
            errorMessage = "載入好友請求失敗: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    // MARK: - 測試連接
    
    /// 測試 Supabase 連接
    func testSupabaseConnection() async -> Bool {
        do {
            // 簡單查詢測試連接
            let result = try await supabaseService.client
                .from("user_profiles")
                .select("id")
                .limit(1)
                .execute()
            
            print("✅ [FriendService] Supabase 連接測試成功")
            print("📊 [FriendService] 查詢結果數據大小: \(result.data.count) bytes")
            return true
            
        } catch {
            print("❌ [FriendService] Supabase 連接測試失敗: \(error)")
            errorMessage = "Supabase 連接測試失敗: \(error.localizedDescription)"
            return false
        }
    }
    
    /// 檢查當前用戶的 user_id
    func getCurrentUserID() async -> String? {
        do {
            guard let user = try? await supabaseService.client.auth.user() else {
                errorMessage = "用戶未登入"
                return nil
            }
            
            let result = try await supabaseService.client
                .from("user_profiles")
                .select("id, username")
                .eq("id", value: user.id)
                .limit(1)
                .execute()
            
            let decoder = JSONDecoder()
            let profiles = try decoder.decode([[String: String]].self, from: result.data)
            
            if let profile = profiles.first,
               let userID = profile["username"] {
                print("✅ [FriendService] 當前用戶名: \(userID)")
                return userID
            } else {
                print("⚠️ [FriendService] 當前用戶沒有 username")
                return nil
            }
            
        } catch {
            print("❌ [FriendService] 獲取當前用戶 ID 失敗: \(error)")
            errorMessage = "獲取用戶 ID 失敗: \(error.localizedDescription)"
            return nil
        }
    }
}