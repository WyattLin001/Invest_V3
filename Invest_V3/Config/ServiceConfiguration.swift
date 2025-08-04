//
//  ServiceConfiguration.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//

import Foundation

// MARK: - Service Configuration
struct ServiceConfiguration {
    
    // MARK: - Environment Settings
    enum Environment: String, CaseIterable {
        case development = "development"
        case staging = "staging"
        case production = "production"
        
        var displayName: String {
            switch self {
            case .development:
                return "開發環境"
            case .staging:
                return "測試環境"
            case .production:
                return "正式環境"
            }
        }
        
        var baseURL: String {
            switch self {
            case .development:
                return "https://api-dev.invest-v3.com/v1"
            case .staging:
                return "https://api-staging.invest-v3.com/v1"
            case .production:
                return "https://api.invest-v3.com/v1"
            }
        }
        
        var enableMockServices: Bool {
            switch self {
            case .development:
                return true  // 開發環境預設使用 Mock 服務
            case .staging:
                return false // 測試環境使用真實 API
            case .production:
                return false // 正式環境使用真實 API
            }
        }
    }
    
    // MARK: - Current Environment
    static var current: Environment {
        #if DEBUG
        return .development
        #elseif STAGING
        return .staging
        #else
        return .production
        #endif
    }
    
    // MARK: - Service Selection
    static var useMockServices: Bool {
        // 可以通過環境變數或 UserDefaults 來覆蓋預設設定
        if let mockOverride = UserDefaults.standard.object(forKey: "UseMockServices") as? Bool {
            return mockOverride
        }
        return current.enableMockServices
    }
    
    // MARK: - API Configuration
    static var apiBaseURL: String {
        return current.baseURL
    }
    
    static var apiTimeout: TimeInterval {
        return 30.0
    }
    
    static var maxRetryAttempts: Int {
        return 3
    }
    
    // MARK: - Feature Flags
    static var enableTournamentSystem: Bool {
        return true
    }
    
    static var enablePerformanceTracking: Bool {
        return true
    }
    
    static var enableSocialFeatures: Bool {
        return current != .development
    }
    
    static var enablePushNotifications: Bool {
        return current == .production
    }
    
    // MARK: - Debug Settings
    static var enableNetworkLogging: Bool {
        return current == .development
    }
    
    static var enablePerformanceMonitoring: Bool {
        return current != .development
    }
    
    // MARK: - Cache Settings
    static var cacheExpiration: TimeInterval {
        switch current {
        case .development:
            return 300 // 5 minutes
        case .staging:
            return 1800 // 30 minutes
        case .production:
            return 3600 // 1 hour
        }
    }
    
    // MARK: - Service Factory
    static func makeTournamentService() -> TournamentServiceProtocol {
        print("🔧 [ServiceConfig] 使用真實 Tournament Service")
        return TournamentService.shared
    }
    
    // MARK: - Configuration Methods
    static func enableMockServices(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: "UseMockServices")
        print("🔧 [ServiceConfig] Mock Services \(enabled ? "已啟用" : "已停用")")
    }
    
    static func resetToDefault() {
        UserDefaults.standard.removeObject(forKey: "UseMockServices")
        print("🔧 [ServiceConfig] 重置為預設設定")
    }
    
    // MARK: - Environment Info
    static func printCurrentConfiguration() {
        print("""
        🔧 [ServiceConfig] 當前配置:
        - 環境: \(current.displayName)
        - API 基礎網址: \(apiBaseURL)
        - 使用 Mock 服務: \(useMockServices ? "是" : "否")
        - 網路日誌: \(enableNetworkLogging ? "啟用" : "停用")
        - 快取過期時間: \(Int(cacheExpiration)) 秒
        """)
    }
}

// MARK: - Service Factory Extension
extension ServiceConfiguration {
    
    /// 創建配置好的 URLSession
    static func makeURLSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = apiTimeout
        configuration.timeoutIntervalForResource = apiTimeout * 2
        
        if enableNetworkLogging {
            // 可以在這裡添加網路請求日誌攔截器
            print("🌐 [ServiceConfig] 網路日誌已啟用")
        }
        
        return URLSession(configuration: configuration)
    }
    
    /// 創建通用的 HTTP Headers
    static func makeHTTPHeaders() -> [String: String] {
        var headers = [
            "Content-Type": "application/json",
            "Accept": "application/json",
            "User-Agent": "Invest_V3_iOS/1.0"
        ]
        
        // 可以在這裡添加認證 token 等
        if let authToken = UserDefaults.standard.string(forKey: "AuthToken") {
            headers["Authorization"] = "Bearer \(authToken)"
        }
        
        return headers
    }
}