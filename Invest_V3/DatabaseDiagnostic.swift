import Foundation

// 簡單的資料庫連線診斷工具
class SimpleDatabaseDiagnostic {
    
    /// 測試基本網路連通性
    static func testNetworkConnectivity() {
        Logger.debug("🌐 測試網路連通性到 Supabase...", category: .network)
        
        guard let url = URL(string: "https://wujlbjrouqcpnifbakmw.supabase.co") else {
            Logger.error("❌ 無效的 URL", category: .network)
            return
        }
        
        let semaphore = DispatchSemaphore(value: 0)
        
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            defer { semaphore.signal() }
            
            if let error = error {
                Logger.error("❌ 網路連線失敗: \(error.localizedDescription)", category: .network)
                return
            }
            
            if let httpResponse = response as? HTTPURLResponse {
                Logger.info("✅ Supabase 服務器回應狀態: \(httpResponse.statusCode)", category: .network)
                if httpResponse.statusCode == 200 {
                    Logger.info("✅ 網路連線正常", category: .network)
                } else {
                    Logger.warning("⚠️ 服務器回應異常，狀態碼: \(httpResponse.statusCode)", category: .network)
                }
            }
        }
        
        task.resume()
        semaphore.wait()
    }
    
    /// 檢查 UserDefaults 中的用戶數據
    static func checkUserData() {
        Logger.debug("👤 檢查本地用戶數據...", category: .database)
        
        // 檢查當前用戶數據
        if let userData = UserDefaults.standard.data(forKey: "current_user") {
            Logger.info("✅ 找到當前用戶數據，大小: \(userData.count) bytes", category: .database)
            
            // 嘗試解碼用戶數據
            do {
                if let userDict = try JSONSerialization.jsonObject(with: userData) as? [String: Any] {
                    let username = userDict["username"] as? String ?? "未知"
                    let email = userDict["email"] as? String ?? "未知"
                    Logger.info("✅ 用戶名: \(username), Email: \(email)", category: .database)
                }
            } catch {
                Logger.warning("⚠️ 用戶數據解碼失敗: \(error.localizedDescription)", category: .database)
            }
        } else {
            Logger.error("❌ 沒有找到當前用戶數據", category: .database)
        }
        
        // 檢查投資組合數據
        if let portfolioData = UserDefaults.standard.data(forKey: "chat_portfolio_holdings") {
            Logger.info("✅ 找到投資組合數據，大小: \(portfolioData.count) bytes", category: .database)
        } else {
            Logger.info("ℹ️ 沒有找到投資組合數據（這是正常的，如果是新用戶）", category: .database)
        }
        
        // 檢查虛擬餘額
        let virtualBalance = UserDefaults.standard.double(forKey: "chat_virtual_balance")
        if virtualBalance > 0 {
            Logger.info("✅ 虛擬餘額: NT$\(virtualBalance)", category: .database)
        } else {
            Logger.info("ℹ️ 沒有設置虛擬餘額（將使用預設值）", category: .database)
        }
    }
    
    /// 檢查交易記錄
    static func checkTradingRecords() {
        Logger.debug("📊 檢查交易記錄...", category: .database)
        
        if let tradingData = UserDefaults.standard.data(forKey: "chat_trading_records") {
            Logger.info("✅ 找到交易記錄數據，大小: \(tradingData.count) bytes", category: .database)
            
            // 嘗試計算交易記錄數量
            do {
                if let tradingArray = try JSONSerialization.jsonObject(with: tradingData) as? [[String: Any]] {
                    Logger.info("✅ 交易記錄數量: \(tradingArray.count)", category: .database)
                }
            } catch {
                Logger.warning("⚠️ 交易記錄數據解碼失敗: \(error.localizedDescription)", category: .database)
            }
        } else {
            Logger.info("ℹ️ 沒有找到交易記錄（這是正常的，如果是新用戶）", category: .database)
        }
    }
    
    /// 執行完整診斷
    @MainActor
    static func runFullDiagnosis() {
        Logger.info("🚀 開始執行完整診斷", category: .database)
        Logger.info("=" * 50, category: .database)
        
        // 1. 網路連通性測試
        testNetworkConnectivity()
        
        // 2. 檢查本地用戶數據
        checkUserData()
        
        // 3. 檢查交易記錄
        checkTradingRecords()
        
        // 4. 診斷數據庫連線問題的根本原因
        diagnoseConnectionIssues()
        
        Logger.info("=" * 50, category: .database)
        Logger.info("📋 診斷完成", category: .database)
        Logger.info("💡 解決方案建議：", category: .database)
        Logger.info("   1. 如果沒有用戶數據 → 創建測試用戶", category: .database)
        Logger.info("   2. 如果 Supabase 未初始化 → 檢查網路連線", category: .database)
        Logger.info("   3. 如果認證失敗 → 用戶需要重新登入", category: .database)
        Logger.info("   4. 如果資料表不存在 → 檢查 Supabase 資料庫設置", category: .database)
    }
    
    /// 診斷數據庫連線問題的根本原因
    @MainActor
    static func diagnoseConnectionIssues() {
        Logger.debug("🔍 診斷數據庫連線問題...", category: .database)
        
        // 檢查認證狀態
        Logger.debug("檢查認證狀態:", category: .database)
        let hasUserData = UserDefaults.standard.data(forKey: "current_user") != nil
        Logger.info("本地用戶數據: \(hasUserData ? "存在" : "不存在")", category: .database)
        
        // 檢查 SupabaseManager 初始化狀態
        let isInitialized = SupabaseManager.shared.isInitialized
        Logger.info("SupabaseManager 初始化: \(isInitialized ? "已初始化" : "未初始化")", category: .database)
        
        // 提供解決方案
        if !hasUserData {
            Logger.error("❌ 問題: 沒有用戶數據，無法進行數據庫查詢", category: .database)
            Logger.info("💡 解決方案: 創建測試用戶或重新登入", category: .database)
        }
        
        if !isInitialized {
            Logger.error("❌ 問題: SupabaseManager 未初始化", category: .database)
            Logger.info("💡 解決方案: 檢查網路連線和 Supabase 配置", category: .database)
        }
        
        if hasUserData && isInitialized {
            Logger.info("✅ 基本設置正常，可能是特定資料表權限問題", category: .database)
        }
    }
    
    /// 創建測試用戶數據
    static func createTestUserData() {
        Logger.debug("👤 創建測試用戶數據...", category: .database)
        
        let testUser = [
            "id": UUID().uuidString,
            "username": "測試用戶_\(Int.random(in: 1000...9999))",
            "email": "test\(Int.random(in: 1000...9999))@example.com",
            "fullName": "測試用戶",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "investmentPhilosophy": "價值投資",
            "portfolioValue": 1000000.0,
            "weeklyReturn": 0.0,
            "monthlyReturn": 0.0,
            "totalReturn": 0.0,
            "riskTolerance": "中等",
            "investmentExperience": "新手",
            "preferredSectors": ["科技", "金融"],
            "bio": "這是一個測試用戶",
            "location": "台北",
            "investmentGoals": ["長期增值"],
            "followersCount": 0,
            "followingCount": 0,
            "postsCount": 0,
            "joinDate": ISO8601DateFormatter().string(from: Date()),
            "isVerified": false,
            "badgeLevel": 1,
            "achievements": []
        ] as [String : Any]
        
        do {
            let userData = try JSONSerialization.data(withJSONObject: testUser)
            UserDefaults.standard.set(userData, forKey: "current_user")
            Logger.info("✅ 測試用戶已創建: \(testUser["username"] as? String ?? "未知")", category: .database)
        } catch {
            Logger.error("❌ 創建測試用戶失敗: \(error.localizedDescription)", category: .database)
        }
    }
}

// String 擴展用於重複字符
extension String {
    static func * (left: String, right: Int) -> String {
        return String(repeating: left, count: right)
    }
}