//
//  TestDataService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/3.
//  測試數據服務 - 提供模擬數據和後備方案
//

import Foundation

@MainActor
class TestDataService: ObservableObject {
    static let shared = TestDataService()
    
    @Published var isTestMode = false
    @Published var hasMockData = false
    
    // MARK: - 測試用戶數據
    
    private let mockUsers: [MockUser] = [
        MockUser(
            id: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            username: "測試投資專家",
            email: "test.expert@invest.com",
            userType: .expert,
            hasWalletSetup: true,
            articlesCount: 5,
            followersCount: 150
        ),
        MockUser(
            id: UUID(uuidString: "87654321-4321-4321-4321-210987654321")!,
            username: "探索者用戶",
            email: "test.explorer@invest.com",
            userType: .explorer,
            hasWalletSetup: false,
            articlesCount: 0,
            followersCount: 10
        )
    ]
    
    // MARK: - 測試文章數據
    
    private let mockArticles: [MockArticle] = [
        MockArticle(
            id: UUID(),
            title: "台積電Q4財報深度解析",
            authorId: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            content: "深度分析台積電最新財報數據...",
            isPublished: true,
            views: 1250,
            likes: 45,
            publishedDaysAgo: 15
        ),
        MockArticle(
            id: UUID(),
            title: "2025年AI投資趨勢預測",
            authorId: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            content: "分析AI領域的投資機會...",
            isPublished: true,
            views: 890,
            likes: 32,
            publishedDaysAgo: 25
        ),
        MockArticle(
            id: UUID(),
            title: "美股科技股分析報告",
            authorId: UUID(uuidString: "12345678-1234-1234-1234-123456789012")!,
            content: "詳細分析美股科技板塊...",
            isPublished: true,
            views: 2100,
            likes: 78,
            publishedDaysAgo: 45
        )
    ]
    
    // MARK: - 測試閱讀記錄
    
    private func generateMockReadingLogs() -> [MockReadingLog] {
        var logs: [MockReadingLog] = []
        
        // 為每篇文章生成多個讀者的閱讀記錄
        for article in mockArticles {
            // 生成不同的讀者ID
            for i in 0..<Int.random(in: 50...150) {
                let readerId = UUID()
                let daysAgo = Int.random(in: 1...30)
                
                logs.append(MockReadingLog(
                    id: UUID(),
                    articleId: article.id,
                    readerId: readerId,
                    authorId: article.authorId,
                    readingDuration: Double.random(in: 30...300),
                    scrollPercentage: Double.random(in: 60...100),
                    isCompleted: Bool.random(),
                    readDate: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date()) ?? Date()
                ))
            }
        }
        
        return logs
    }
    
    // MARK: - 模擬數據生成
    
    func generateMockEligibilityData(for userId: UUID) -> MockEligibilityData {
        let userArticles = mockArticles.filter { $0.authorId == userId }
        let recentArticles = userArticles.filter { $0.publishedDaysAgo <= 90 }
        
        // 生成閱讀記錄
        let readingLogs = generateMockReadingLogs()
        let userReadingLogs = readingLogs.filter { $0.authorId == userId }
        let recentReadingLogs = userReadingLogs.filter {
            Calendar.current.dateInterval(of: .day, for: Date())?.contains($0.readDate) == false &&
            Calendar.current.dateComponents([.day], from: $0.readDate, to: Date()).day! <= 30
        }
        
        let uniqueReaders = Set(recentReadingLogs.map { $0.readerId }).count
        
        return MockEligibilityData(
            userId: userId,
            last90DaysArticles: recentArticles.count,
            last30DaysUniqueReaders: uniqueReaders,
            hasViolations: false,
            hasWalletSetup: mockUsers.first(where: { $0.id == userId })?.hasWalletSetup ?? false,
            eligibilityScore: calculateMockEligibilityScore(
                articles: recentArticles.count,
                readers: uniqueReaders,
                hasViolations: false,
                hasWallet: mockUsers.first(where: { $0.id == userId })?.hasWalletSetup ?? false
            )
        )
    }
    
    private func calculateMockEligibilityScore(articles: Int, readers: Int, hasViolations: Bool, hasWallet: Bool) -> Double {
        var score = 0.0
        
        // 文章條件 (25分)
        if articles >= 1 {
            score += 25.0
        }
        
        // 讀者條件 (25分)
        if readers >= 100 {
            score += 25.0
        } else if readers >= 50 {
            score += 15.0
        } else if readers >= 10 {
            score += 5.0
        }
        
        // 無違規條件 (25分)
        if !hasViolations {
            score += 25.0
        }
        
        // 錢包設置條件 (25分)
        if hasWallet {
            score += 25.0
        }
        
        return score
    }
    
    func generateMockRevenueData(for userId: UUID) -> MockRevenueData {
        let baseRevenue = Double.random(in: 1000...10000)
        
        return MockRevenueData(
            userId: userId,
            totalEarnings: baseRevenue,
            subscriptionEarnings: baseRevenue * 0.4,
            tipEarnings: baseRevenue * 0.3,
            articleEarnings: baseRevenue * 0.2,
            giftEarnings: baseRevenue * 0.1,
            withdrawableAmount: baseRevenue * 0.8,
            totalTransactions: Int.random(in: 10...50)
        )
    }
    
    // MARK: - 公開方法
    
    func enableTestMode() {
        isTestMode = true
        hasMockData = true
        print("✅ [TestDataService] 測試模式已啟用，模擬數據可用")
    }
    
    func disableTestMode() {
        isTestMode = false
        hasMockData = false
        print("✅ [TestDataService] 測試模式已關閉")
    }
    
    func getAvailableTestUsers() -> [MockUser] {
        return mockUsers
    }
    
    func getDefaultTestUserId() -> UUID {
        return mockUsers.first?.id ?? UUID()
    }
    
    func getMockArticles(for authorId: UUID? = nil) -> [MockArticle] {
        if let authorId = authorId {
            return mockArticles.filter { $0.authorId == authorId }
        }
        return mockArticles
    }
    
    private init() {
        // 私有初始化，確保單例模式
    }
}

// MARK: - Mock Data Models

struct MockUser {
    let id: UUID
    let username: String
    let email: String
    let userType: UserType
    let hasWalletSetup: Bool
    let articlesCount: Int
    let followersCount: Int
    
    enum UserType {
        case expert   // 投資專家
        case explorer // 探索者
    }
}

struct MockArticle {
    let id: UUID
    let title: String
    let authorId: UUID
    let content: String
    let isPublished: Bool
    let views: Int
    let likes: Int
    let publishedDaysAgo: Int
}

struct MockReadingLog {
    let id: UUID
    let articleId: UUID
    let readerId: UUID
    let authorId: UUID
    let readingDuration: Double
    let scrollPercentage: Double
    let isCompleted: Bool
    let readDate: Date
}

struct MockEligibilityData {
    let userId: UUID
    let last90DaysArticles: Int
    let last30DaysUniqueReaders: Int
    let hasViolations: Bool
    let hasWalletSetup: Bool
    let eligibilityScore: Double
    
    var isEligible: Bool {
        return last90DaysArticles >= 1 &&
               last30DaysUniqueReaders >= 100 &&
               !hasViolations &&
               hasWalletSetup
    }
}

struct MockRevenueData {
    let userId: UUID
    let totalEarnings: Double
    let subscriptionEarnings: Double
    let tipEarnings: Double
    let articleEarnings: Double
    let giftEarnings: Double
    let withdrawableAmount: Double
    let totalTransactions: Int
}