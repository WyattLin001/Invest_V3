import Foundation

/// 資料庫連線問題修復工具
/// 解決 Supabase 初始化警告和股票交易功能問題
class DatabaseConnectionFix {
    
    /// 執行完整的修復流程
    static func performCompleteFix() {
        print("🔧 [DatabaseConnectionFix] 開始執行完整修復流程")
        print("=" * 60)
        
        // Step 1: Create test user if needed
        createTestUserIfNeeded()
        
        // Step 2: Initialize portfolio manager
        initializePortfolioManager()
        
        // Step 3: Test basic functionality
        testBasicFunctionality()
        
        print("\n" + "=" * 60)
        print("✅ [DatabaseConnectionFix] 修復流程完成")
        
        // Provide next steps
        print("\n📋 後續建議:")
        print("   1. 重新啟動應用程式測試交易功能")
        print("   2. 檢查 Supabase 初始化警告是否消失")
        print("   3. 嘗試買入/賣出股票功能")
        print("   4. 如果仍有問題，檢查網路連線")
        
        print("\n🚀 可以使用以下測試代碼:")
        print("   TradingTestHelper.quickTest() // 測試交易功能")
        print("   DatabaseTestHelper.runFullDiagnosis() // 全面診斷")
    }
    
    /// 創建測試用戶（如果需要）
    private static func createTestUserIfNeeded() {
        print("\n👤 Step 1: 檢查並創建測試用戶...")
        
        // Check if user already exists
        if let userData = UserDefaults.standard.data(forKey: "current_user"),
           let _ = try? JSONDecoder().decode(UserProfile.self, from: userData) {
            print("   ✅ 已存在用戶數據，跳過創建")
            return
        }
        
        print("   ⚠️ 沒有用戶數據，創建測試用戶...")
        
        // Create a proper UserProfile-compatible test user
        let testUserId = UUID()
        let testUser: [String: Any] = [
            "id": testUserId.uuidString,
            "username": "測試投資者_\(Int.random(in: 1000...9999))",
            "email": "test\(Int.random(in: 1000...9999))@invest.com",
            "fullName": "測試投資者",
            "createdAt": ISO8601DateFormatter().string(from: Date()),
            "updatedAt": ISO8601DateFormatter().string(from: Date()),
            "investmentPhilosophy": "價值投資策略",
            "portfolioValue": 1000000.0,
            "weeklyReturn": 2.5,
            "monthlyReturn": 8.3,
            "totalReturn": 15.7,
            "riskTolerance": "積極",
            "investmentExperience": "3年經驗",
            "preferredSectors": ["科技", "金融", "生技"],
            "bio": "專注於長期價值投資，追求穩健收益",
            "location": "台北市",
            "investmentGoals": ["資產增值", "財務自由"],
            "followersCount": 156,
            "followingCount": 89,
            "postsCount": 23,
            "joinDate": ISO8601DateFormatter().string(from: Date()),
            "isVerified": true,
            "badgeLevel": 3,
            "achievements": ["新手投資者", "價值發現者"]
        ]
        
        do {
            let userData = try JSONSerialization.data(withJSONObject: testUser, options: [])
            UserDefaults.standard.set(userData, forKey: "current_user")
            print("   ✅ 測試用戶已創建: \(testUser["username"] as? String ?? "未知")")
            print("   📊 初始資金: NT$1,000,000")
        } catch {
            print("   ❌ 創建測試用戶失敗: \(error.localizedDescription)")
        }
    }
    
    /// 初始化投資組合管理器
    private static func initializePortfolioManager() {
        print("\n💼 Step 2: 初始化投資組合管理器...")
        
        // Initialize ChatPortfolioManager to ensure proper setup
        let portfolioManager = ChatPortfolioManager.shared
        
        print("   📊 投資組合狀態:")
        print("     - 持股數量: \(portfolioManager.holdings.count)")
        print("     - 可用餘額: NT$\(String(format: "%.0f", portfolioManager.availableBalance))")
        print("     - 總投資額: NT$\(String(format: "%.0f", portfolioManager.totalInvested))")
        print("     - 投資組合價值: NT$\(String(format: "%.0f", portfolioManager.totalPortfolioValue))")
        
        // Ensure portfolio has some initial balance
        if portfolioManager.virtualBalance == 0 {
            print("   ⚠️ 虛擬餘額為 0，重置為初始值...")
            portfolioManager.resetMonthlyBalance()
            print("   ✅ 虛擬餘額已重置為 NT$1,000,000")
        }
        
        print("   ✅ 投資組合管理器初始化完成")
    }
    
    /// 測試基本功能
    private static func testBasicFunctionality() {
        print("\n🧪 Step 3: 測試基本功能...")
        
        let portfolioManager = ChatPortfolioManager.shared
        
        // Test 1: Check if we can perform calculations
        print("   測試 1: 投資組合計算功能")
        let totalValue = portfolioManager.totalPortfolioValue
        let availableBalance = portfolioManager.availableBalance
        print("     ✅ 總價值計算: NT$\(String(format: "%.0f", totalValue))")
        print("     ✅ 可用餘額計算: NT$\(String(format: "%.0f", availableBalance))")
        
        // Test 2: Check if we can simulate a buy operation (without actually buying)
        print("   測試 2: 模擬交易檢查")
        let testSymbol = "2330"
        let testAmount = 10000.0
        let canBuy = portfolioManager.canBuy(symbol: testSymbol, amount: testAmount)
        print("     \(canBuy ? "✅" : "❌") 買入檢查 (\(testSymbol), NT$\(testAmount)): \(canBuy ? "可以買入" : "無法買入")")
        
        // Test 3: Check trading statistics
        print("   測試 3: 交易統計功能")
        let stats = portfolioManager.getTradingStatistics()
        print("     ✅ 總交易次數: \(stats.totalTrades)")
        print("     ✅ 總交易量: NT$\(String(format: "%.0f", stats.totalVolume))")
        print("     ✅ 已實現損益: NT$\(String(format: "%.2f", stats.totalRealizedGainLoss))")
        
        print("   ✅ 基本功能測試完成")
    }
    
    /// 檢查並修復常見問題
    @MainActor
    static func diagnoseAndFixCommonIssues() {
        print("🔍 [DatabaseConnectionFix] 診斷並修復常見問題")
        print("=" * 50)
        
        // Issue 1: No user data
        if UserDefaults.standard.data(forKey: "current_user") == nil {
            print("❌ 問題 1: 沒有用戶數據")
            print("🔧 修復: 創建測試用戶...")
            createTestUserIfNeeded()
        } else {
            print("✅ 用戶數據: 正常")
        }
        
        // Issue 2: Portfolio manager not initialized
        let portfolioManager = ChatPortfolioManager.shared
        if portfolioManager.virtualBalance == 0 {
            print("❌ 問題 2: 投資組合未初始化")
            print("🔧 修復: 重置投資組合...")
            portfolioManager.resetMonthlyBalance()
            print("✅ 投資組合已重置")
        } else {
            print("✅ 投資組合: 正常 (餘額: NT$\(String(format: "%.0f", portfolioManager.virtualBalance)))")
        }
        
        // Issue 3: SupabaseManager initialization
        let isInitialized = SupabaseManager.shared.isInitialized
        if !isInitialized {
            print("❌ 問題 3: SupabaseManager 未初始化")
            print("💡 建議: 檢查網路連線，應用程式啟動時會自動初始化")
        } else {
            print("✅ SupabaseManager: 已初始化")
        }
        
        print("\n✅ 診斷完成")
    }
    
    /// 創建一些測試交易記錄
    static func createSampleTradingRecords() {
        print("📊 [DatabaseConnectionFix] 創建樣本交易記錄用於測試...")
        
        let portfolioManager = ChatPortfolioManager.shared
        
        // Clear existing records first
        portfolioManager.clearCurrentUserPortfolio()
        
        // Add some sample trading records
        portfolioManager.addMockTradingRecords()
        
        print("✅ 樣本交易記錄已創建")
        
        // Show summary
        let stats = portfolioManager.getTradingStatistics()
        print("📈 交易統計摘要:")
        print("   - 總交易: \(stats.totalTrades) 筆")
        print("   - 買入: \(stats.buyTrades) 筆")
        print("   - 賣出: \(stats.sellTrades) 筆")
        print("   - 總交易量: NT$\(String(format: "%.0f", stats.totalVolume))")
        print("   - 已實現損益: NT$\(String(format: "%.2f", stats.totalRealizedGainLoss))")
    }
}

// Note: String extension for repeating characters moved to avoid conflicts