import Foundation
import Auth

/// 服務協調器
/// 統一管理所有業務服務，提供單一入口點訪問各種功能
@MainActor
class ServiceCoordinator: ObservableObject {
    static let shared = ServiceCoordinator()
    
    // MARK: - 服務實例
    
    /// 核心Supabase服務（認證和基本用戶操作）
    let core = CoreSupabaseService.shared
    
    /// 文章管理服務
    let articles = ArticleService.shared
    
    /// 群組管理服務
    let groups = GroupService.shared
    
    /// 聊天管理服務
    let chat = ChatService.shared
    
    /// 好友管理服務
    let friends = FriendsService.shared
    
    /// 安全服務
    let security = SecurityService.shared
    
    /// 配置服務
    let configuration = ConfigurationService.shared
    
    /// 效能監控服務
    let performance = PerformanceMonitorService.shared
    
    /// 錯誤處理服務
    let errorHandling = ErrorHandlingService.shared
    
    // MARK: - 向後兼容性
    
    /// 提供向後兼容的SupabaseService接口
    var supabaseService: SupabaseService {
        return SupabaseService.shared
    }
    
    private init() {
        Logger.info("🎯 服務協調器已初始化", category: .database)
    }
    
    // MARK: - 系統初始化
    
    /// 初始化所有服務
    func initializeServices() async throws {
        Logger.info("🚀 初始化所有服務", category: .database)
        
        // 1. 初始化配置服務
        configuration.initializeConfiguration()
        
        // 2. 檢查安全環境
        let environment = configuration.detectEnvironment()
        if !environment.isSecure && configuration.isProductionEnvironment() {
            Logger.warning("⚠️ 在非安全環境中運行生產配置", category: .general)
        }
        
        // 3. 檢查設備安全性
        if configuration.isJailbrokenDevice() {
            Logger.warning("⚠️ 檢測到越獄設備", category: .general)
        }
        
        // 4. 確保Supabase基礎設施已初始化
        try await SupabaseManager.shared.ensureInitializedAsync()
        
        // 5. 測試核心服務連線
        _ = try await core.testConnection()
        
        // 6. 啟動效能監控
        performance.startMonitoring()
        
        Logger.info("✅ 所有服務初始化完成", category: .database)
    }
    
    /// 獲取系統整體健康狀態
    func getSystemHealth() async throws -> SystemHealthReport {
        Logger.info("🔍 檢查系統健康狀態", category: .database)
        
        let coreHealth = try await core.getSystemHealth()
        
        // 檢查各個服務的可用性
        var serviceStatus: [String: Bool] = [:]
        
        // 測試文章服務
        do {
            _ = try await articles.getArticles(limit: 1)
            serviceStatus["articles"] = true
        } catch {
            serviceStatus["articles"] = false
            Logger.warning("⚠️ 文章服務不可用: \(error)", category: .database)
        }
        
        // 測試群組服務 
        do {
            _ = try await groups.searchPublicGroups(limit: 1)
            serviceStatus["groups"] = true
        } catch {
            serviceStatus["groups"] = false
            Logger.warning("⚠️ 群組服務不可用: \(error)", category: .database)
        }
        
        // 測試好友服務
        do {
            _ = try await friends.getFriends()
            serviceStatus["friends"] = true
        } catch {
            serviceStatus["friends"] = false
            Logger.warning("⚠️ 好友服務不可用: \(error)", category: .database)
        }
        
        // 獲取效能和安全狀態
        let performanceReport = performance.generatePerformanceReport()
        let errorReport = errorHandling.generateErrorReport()
        
        let healthReport = SystemHealthReport(
            coreHealth: coreHealth,
            serviceStatus: serviceStatus,
            overallHealth: serviceStatus.values.allSatisfy { $0 } && coreHealth.isConnected,
            performanceReport: performanceReport,
            errorReport: errorReport
        )
        
        Logger.info("✅ 系統健康檢查完成", category: .database)
        return healthReport
    }
    
    // MARK: - 快速訪問方法
    
    /// 快速獲取當前用戶
    func getCurrentUser() async throws -> User {
        return try await core.getCurrentUserAsync()
    }
    
    /// 快速獲取用戶資料
    func getCurrentUserProfile() async throws -> UserProfile {
        let user = try await getCurrentUser()
        return try await core.getUserProfile(userId: user.id)
    }
    
    /// 快速檢查用戶是否已登入
    func isUserAuthenticated() -> Bool {
        return core.getCurrentUser() != nil
    }
    
    // MARK: - 批量操作
    
    /// 獲取用戶儀表板資料
    func getDashboardData() async throws -> DashboardData {
        Logger.info("📊 獲取儀表板資料", category: .database)
        
        async let articlesTask = articles.getRecommendedArticles(limit: 5)
        async let groupsTask = groups.getUserGroups()
        async let friendsTask = friends.getFriends()
        async let friendRequestsTask = friends.getPendingFriendRequests()
        
        let dashboardArticles = try await articlesTask
        let userGroups = try await groupsTask
        let userFriends = try await friendsTask
        let pendingRequests = try await friendRequestsTask
        
        Logger.info("✅ 儀表板資料獲取完成", category: .database)
        
        return DashboardData(
            recommendedArticles: dashboardArticles,
            userGroups: userGroups,
            friends: userFriends,
            pendingFriendRequests: pendingRequests
        )
    }
    
    /// 搜尋所有內容
    func searchAll(query: String, limit: Int = 10) async throws -> SearchResults {
        Logger.info("🔍 全域搜尋: \(query)", category: .database)
        
        async let articlesTask = articles.searchArticles(query: query, limit: limit)
        async let groupsTask = groups.searchPublicGroups(query: query, limit: limit)
        async let usersTask = friends.searchUsers(query: query, limit: limit)
        
        let searchedArticles = try await articlesTask
        let searchedGroups = try await groupsTask
        let searchedUsers = try await usersTask
        
        Logger.info("✅ 全域搜尋完成", category: .database)
        
        return SearchResults(
            articles: searchedArticles,
            groups: searchedGroups,
            users: searchedUsers
        )
    }
}

// MARK: - 數據結構

/// 系統健康報告
struct SystemHealthReport {
    let coreHealth: SystemHealth
    let serviceStatus: [String: Bool]
    let overallHealth: Bool
    let performanceReport: PerformanceReport
    let errorReport: ErrorReport
    
    var healthPercentage: Double {
        let totalServices = serviceStatus.count + 1 // +1 for core service
        let healthyServices = serviceStatus.values.filter { $0 }.count + (coreHealth.isConnected ? 1 : 0)
        return Double(healthyServices) / Double(totalServices)
    }
    
    var statusDescription: String {
        if overallHealth {
            return "所有服務正常運行"
        } else if healthPercentage >= 0.8 {
            return "大部分服務正常，部分服務有問題"
        } else if healthPercentage >= 0.5 {
            return "部分服務正常，建議檢查系統"
        } else {
            return "多個服務不可用，需要立即檢修"
        }
    }
    
    var hasPerformanceIssues: Bool {
        return performanceReport.memoryUsage.memoryPressure == .critical ||
               performanceReport.networkPerformanceReport.averageResponseTime > 3000
    }
    
    var hasHighErrorRate: Bool {
        return errorReport.statistics.totalErrors > 50
    }
}

/// 儀表板資料
struct DashboardData {
    let recommendedArticles: [Article]
    let userGroups: [InvestmentGroup]
    let friends: [Friend]
    let pendingFriendRequests: [FriendRequestDisplay]
    
    var hasNotifications: Bool {
        return !pendingFriendRequests.isEmpty
    }
    
    var notificationCount: Int {
        return pendingFriendRequests.count
    }
}

/// 搜尋結果
struct SearchResults {
    let articles: [Article]
    let groups: [InvestmentGroup]
    let users: [FriendSearchResult]
    
    var totalCount: Int {
        return articles.count + groups.count + users.count
    }
    
    var isEmpty: Bool {
        return totalCount == 0
    }
}