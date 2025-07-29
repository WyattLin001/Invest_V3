//
//  DatabaseTestHelper.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/28.
//  資料庫連線測試輔助工具
//

import Foundation

/// 資料庫連線測試輔助工具
/// 提供檢查數據庫連接狀態和基本操作的測試方法
class DatabaseTestHelper {
    static let shared = DatabaseTestHelper()
    private init() {}
    
    /// 測試資料庫連線狀態
    @MainActor
    func testDatabaseConnection() async {
        print("🧪 [DatabaseTestHelper] 開始測試資料庫連線")
        
        let supabaseService = SupabaseService.shared
        
        // 測試 1: 檢查 Supabase 初始化狀態
        print("\n🔄 [DatabaseTestHelper] 測試 1: 檢查 Supabase 初始化狀態")
        let isInitialized = SupabaseManager.shared.isInitialized
        print("   SupabaseManager 初始化狀態: \(isInitialized ? "已初始化" : "未初始化")")
        
        // 測試 2: 基本資料庫查詢
        print("\n🔄 [DatabaseTestHelper] 測試 2: 嘗試基本資料庫查詢")
        do {
            // 嘗試獲取用戶資料
            let currentUser = supabaseService.getCurrentUser()
            print("   當前用戶: \(currentUser?.username ?? "未登入")")
            
            // 嘗試獲取錢包餘額
            let balance = try await supabaseService.fetchWalletBalance()
            print("   錢包餘額查詢成功: $\(balance)")
            
        } catch {
            print("   ❌ 資料庫查詢失敗: \(error.localizedDescription)")
            
            // 進一步分析錯誤
            if let supabaseError = error as? SupabaseError {
                print("   錯誤類型: \(supabaseError)")
            }
        }
        
        // 測試 3: 檢查必要的資料表是否存在
        print("\n🔄 [DatabaseTestHelper] 測試 3: 檢查資料表結構")
        await testTableStructure()
        
        // 測試 4: 測試好友系統
        print("\n🔄 [DatabaseTestHelper] 測試 4: 測試好友系統")
        await testFriendSystem()
        
        print("\n✅ [DatabaseTestHelper] 資料庫連線測試完成")
    }
    
    /// 測試資料表結構
    private func testTableStructure() async {
        let supabaseService = SupabaseService.shared
        
        // 檢查核心資料表
        let criticalTables = [
            "user_profiles",
            "user_balances", 
            "friendships",
            "tournaments",
            "tournament_participants"
        ]
        
        for tableName in criticalTables {
            await testTableAccess(tableName: tableName, service: supabaseService)
        }
    }
    
    /// 測試單個資料表的存取
    private func testTableAccess(tableName: String, service: SupabaseService) async {
        do {
            // 嘗試查詢資料表（限制1筆結果以減少網路負載）
            let _ = try await service.client
                .from(tableName)
                .select("*")
                .limit(1)
                .execute().value
            print("   ✅ 資料表 '\(tableName)' 存取正常")
            
        } catch {
            print("   ❌ 資料表 '\(tableName)' 存取失敗: \(error.localizedDescription)")
            
            // 嘗試分析錯誤原因
            let errorString = error.localizedDescription.lowercased()
            if errorString.contains("does not exist") || errorString.contains("relation") {
                print("      💡 建議：資料表可能不存在，需要創建")
            } else if errorString.contains("permission") || errorString.contains("denied") {
                print("      💡 建議：權限問題，檢查 RLS 政策")
            } else if errorString.contains("network") || errorString.contains("connection") {
                print("      💡 建議：網路連線問題")
            }
        }
    }
    
    /// 測試好友系統
    private func testFriendSystem() async {
        let supabaseService = SupabaseService.shared
        
        do {
            // 測試獲取好友列表
            let friends = try await supabaseService.fetchFriends()
            print("   ✅ 好友列表查詢成功，共 \(friends.count) 位好友")
            
            // 測試搜尋用戶
            let searchResults = try await supabaseService.searchUsers(query: "test")
            print("   ✅ 用戶搜尋功能正常，找到 \(searchResults.count) 個結果")
            
        } catch {
            print("   ❌ 好友系統測試失敗: \(error.localizedDescription)")
        }
    }
    
    /// 診斷網路連線
    @MainActor
    func diagnoseNetworkConnection() async {
        print("🌐 [DatabaseTestHelper] 診斷網路連線")
        
        // 測試基本網路連通性
        do {
            let url = URL(string: "https://wujlbjrouqcpnifbakmw.supabase.co")!
            let (_, response) = try await URLSession.shared.data(from: url)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("   HTTP 狀態碼: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    print("   ✅ Supabase 服務器連接正常")
                } else {
                    print("   ⚠️ Supabase 服務器回應異常")
                }
            }
        } catch {
            print("   ❌ 網路連線失敗: \(error.localizedDescription)")
        }
    }
    
    /// 重置本地狀態
    @MainActor
    func resetLocalState() {
        print("🔄 [DatabaseTestHelper] 重置本地狀態")
        
        // 清除 UserDefaults 中的用戶資料
        UserDefaults.standard.removeObject(forKey: "current_user")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        
        // 清除投資組合資料
        ChatPortfolioManager.shared.clearCurrentUserPortfolio()
        
        print("   ✅ 本地狀態已重置")
    }
    
    /// 創建測試用戶
    @MainActor
    func createTestUser() {
        print("👤 [DatabaseTestHelper] 創建測試用戶")
        
        let testUser = UserProfile(
            id: UUID(),
            email: "test\(Int.random(in: 1000...9999))@example.com",
            username: "測試用戶_\(Int.random(in: 1000...9999))",
            displayName: "測試用戶",
            avatarUrl: nil,
            bio: "這是一個測试用戶",
            createdAt: Date(),
            updatedAt: Date()
        )
        
        // 保存到 UserDefaults
        if let encoded = try? JSONEncoder().encode(testUser) {
            UserDefaults.standard.set(encoded, forKey: "current_user")
            print("   ✅ 測試用戶已創建: \(testUser.username)")
        } else {
            print("   ❌ 測試用戶創建失敗")
        }
    }
}

/// 快速診斷命令
extension DatabaseTestHelper {
    /// 執行完整的資料庫診斷
    @MainActor
    static func runFullDiagnosis() async {
        print("🚀 [DatabaseTestHelper] 執行完整資料庫診斷")
        
        let helper = shared
        
        // 1. 檢查並創建測試用戶（如果需要）
        let supabaseService = SupabaseService.shared  
        if supabaseService.getCurrentUser() == nil {
            print("👤 沒有當前用戶，創建測試用戶...")
            helper.createTestUser()
        }
        
        // 2. 網路連線診斷
        await helper.diagnoseNetworkConnection()
        
        // 3. 資料庫連線測試
        await helper.testDatabaseConnection()
        
        print("\n📋 [DatabaseTestHelper] 診斷完成，請查看上方日誌了解詳細結果")
    }
    
    /// 快速連線測試
    @MainActor
    static func quickConnectionTest() async {
        print("⚡ [DatabaseTestHelper] 快速連線測試")
        
        do {
            let supabaseService = SupabaseService.shared
            let balance = try await supabaseService.fetchWalletBalance()
            print("   ✅ 資料庫連線正常，餘額: $\(balance)")
        } catch {
            print("   ❌ 資料庫連線失敗: \(error.localizedDescription)")
            print("   💡 建議執行完整診斷: DatabaseTestHelper.runFullDiagnosis()")
        }
    }
}