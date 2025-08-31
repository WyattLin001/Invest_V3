import Foundation

/// 配置管理服務
/// 負責安全地管理應用程式配置，包括環境變數、敏感資料等
@MainActor
class ConfigurationService: ObservableObject {
    static let shared = ConfigurationService()
    
    private let securityService = SecurityService.shared
    private var cachedConfig: SecureConfiguration?
    
    private init() {
        loadConfiguration()
    }
    
    // MARK: - 配置管理
    
    /// 初始化配置（首次運行時調用）
    func initializeConfiguration() {
        Logger.info("🔧 初始化應用程式配置", category: .general)
        
        // 從環境變數或安全來源獲取配置
        let config = SecureConfiguration(
            supabaseURL: getSupabaseURL(),
            supabaseAnonKey: getSupabaseAnonKey(),
            apnsTeamId: getAPNSTeamId(),
            apnsKeyId: getAPNSKeyId()
        )
        
        do {
            try securityService.storeSecureConfiguration(config)
            self.cachedConfig = config
            Logger.info("✅ 配置初始化完成", category: .general)
        } catch {
            Logger.error("❌ 配置初始化失敗: \(error)", category: .general)
            // 使用預設配置
            self.cachedConfig = getDefaultConfiguration()
        }
    }
    
    /// 獲取Supabase配置
    func getSupabaseConfiguration() -> (url: URL, key: String) {
        let config = getCurrentConfiguration()
        
        guard let url = URL(string: config.supabaseURL) else {
            Logger.error("❌ 無效的Supabase URL", category: .general)
            fatalError("Invalid Supabase URL configuration")
        }
        
        return (url: url, key: config.supabaseAnonKey)
    }
    
    /// 獲取APNS配置
    func getAPNSConfiguration() -> (teamId: String?, keyId: String?) {
        let config = getCurrentConfiguration()
        return (teamId: config.apnsTeamId, keyId: config.apnsKeyId)
    }
    
    /// 檢查是否為生產環境
    func isProductionEnvironment() -> Bool {
        let config = getCurrentConfiguration()
        return config.isProduction
    }
    
    /// 獲取應用程式版本資訊
    func getAppVersion() -> AppVersionInfo {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        let buildNumber = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "Unknown"
        let bundleId = bundle.bundleIdentifier ?? "Unknown"
        
        return AppVersionInfo(
            version: version,
            buildNumber: buildNumber,
            bundleIdentifier: bundleId
        )
    }
    
    // MARK: - 環境檢測
    
    /// 檢測運行環境
    func detectEnvironment() -> AppEnvironment {
        #if DEBUG
        return .debug
        #elseif targetEnvironment(simulator)
        return .simulator
        #else
        if isTestFlightBuild() {
            return .testFlight
        } else {
            return .production
        }
        #endif
    }
    
    /// 檢查是否為TestFlight建置
    private func isTestFlightBuild() -> Bool {
        guard let receiptURL = Bundle.main.appStoreReceiptURL else {
            return false
        }
        
        return receiptURL.path.contains("sandboxReceipt")
    }
    
    /// 檢查是否為越獄設備
    func isJailbrokenDevice() -> Bool {
        // 檢查常見的越獄路徑
        let jailbreakPaths = [
            "/Applications/Cydia.app",
            "/Library/MobileSubstrate/MobileSubstrate.dylib",
            "/bin/bash",
            "/usr/sbin/sshd",
            "/etc/apt"
        ]
        
        for path in jailbreakPaths {
            if FileManager.default.fileExists(atPath: path) {
                return true
            }
        }
        
        // 檢查是否可以寫入系統目錄
        let testPath = "/private/test_jailbreak.txt"
        do {
            try "test".write(toFile: testPath, atomically: true, encoding: .utf8)
            try FileManager.default.removeItem(atPath: testPath)
            return true // 如果能寫入系統目錄，可能是越獄設備
        } catch {
            // 無法寫入是正常的
        }
        
        return false
    }
    
    // MARK: - 私有方法
    
    private func loadConfiguration() {
        do {
            cachedConfig = try securityService.getSecureConfiguration()
            Logger.info("✅ 配置載入成功", category: .general)
        } catch {
            Logger.warning("⚠️ 無法載入儲存的配置，使用預設配置", category: .general)
            cachedConfig = getDefaultConfiguration()
        }
    }
    
    private func getCurrentConfiguration() -> SecureConfiguration {
        return cachedConfig ?? getDefaultConfiguration()
    }
    
    private func getDefaultConfiguration() -> SecureConfiguration {
        Logger.warning("⚠️ 使用預設配置，生產環境應避免", category: .general)
        
        return SecureConfiguration(
            supabaseURL: "https://wujlbjrouqcpnifbakmw.supabase.co",
            supabaseAnonKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MTMxNjcsImV4cCI6MjA2NzM4OTE2N30.2-l82gsxWDLMj3gUnSpj8sHddMLtX-JgqrbnY5c_9bg",
            apnsTeamId: nil,
            apnsKeyId: nil
        )
    }
    
    // MARK: - 環境變數獲取
    
    private func getSupabaseURL() -> String {
        // 優先從環境變數獲取
        if let envURL = ProcessInfo.processInfo.environment["SUPABASE_URL"] {
            return envURL
        }
        
        // 從Info.plist獲取
        if let plistURL = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_URL") as? String {
            return plistURL
        }
        
        // 預設值（開發環境）
        Logger.warning("⚠️ 未找到SUPABASE_URL環境變數，使用預設值", category: .general)
        return "https://wujlbjrouqcpnifbakmw.supabase.co"
    }
    
    private func getSupabaseAnonKey() -> String {
        // 優先從環境變數獲取
        if let envKey = ProcessInfo.processInfo.environment["SUPABASE_ANON_KEY"] {
            return envKey
        }
        
        // 從Info.plist獲取
        if let plistKey = Bundle.main.object(forInfoDictionaryKey: "SUPABASE_ANON_KEY") as? String {
            return plistKey
        }
        
        // 預設值（開發環境）
        Logger.warning("⚠️ 未找到SUPABASE_ANON_KEY環境變數，使用預設值", category: .general)
        return "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MTMxNjcsImV4cCI6MjA2NzM4OTE2N30.2-l82gsxWDLMj3gUnSpj8sHddMLtX-JgqrbnY5c_9bg"
    }
    
    private func getAPNSTeamId() -> String? {
        return ProcessInfo.processInfo.environment["APNS_TEAM_ID"] 
            ?? Bundle.main.object(forInfoDictionaryKey: "APNS_TEAM_ID") as? String
    }
    
    private func getAPNSKeyId() -> String? {
        return ProcessInfo.processInfo.environment["APNS_KEY_ID"]
            ?? Bundle.main.object(forInfoDictionaryKey: "APNS_KEY_ID") as? String
    }
}

// MARK: - 數據結構

/// 應用程式版本資訊
struct AppVersionInfo {
    let version: String
    let buildNumber: String
    let bundleIdentifier: String
    
    var fullVersion: String {
        return "\(version) (\(buildNumber))"
    }
}

/// 應用程式環境
enum AppEnvironment {
    case debug
    case simulator
    case testFlight
    case production
    
    var displayName: String {
        switch self {
        case .debug: return "開發環境"
        case .simulator: return "模擬器"
        case .testFlight: return "TestFlight"
        case .production: return "生產環境"
        }
    }
    
    var isSecure: Bool {
        switch self {
        case .debug, .simulator: return false
        case .testFlight, .production: return true
        }
    }
}