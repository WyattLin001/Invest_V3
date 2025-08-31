import Foundation
import Security
import UIKit

/// 安全服務
/// 負責處理敏感資料加密、安全儲存、輸入驗證等安全相關功能
@MainActor
class SecurityService: ObservableObject {
    static let shared = SecurityService()
    
    private let keychain = KeychainService()
    
    private init() {}
    
    // MARK: - 敏感資料管理
    
    /// 安全儲存敏感設定
    func storeSecureConfiguration(_ config: SecureConfiguration) throws {
        Logger.info("🔒 儲存安全設定", category: .general)
        
        let configData = try JSONEncoder().encode(config)
        try keychain.store(data: configData, for: .secureConfig)
        
        Logger.info("✅ 安全設定儲存成功", category: .general)
    }
    
    /// 獲取安全設定
    func getSecureConfiguration() throws -> SecureConfiguration {
        Logger.debug("🔍 獲取安全設定", category: .general)
        
        let configData = try keychain.retrieve(for: .secureConfig)
        let config = try JSONDecoder().decode(SecureConfiguration.self, from: configData)
        
        return config
    }
    
    /// 清除敏感資料
    func clearSensitiveData() throws {
        Logger.info("🧹 清除敏感資料", category: .general)
        
        try keychain.delete(.secureConfig)
        try keychain.delete(.authTokens)
        try keychain.delete(.userCredentials)
        
        // 清除UserDefaults中的敏感資料
        UserDefaults.standard.removeObject(forKey: "user_session")
        UserDefaults.standard.removeObject(forKey: "auth_token")
        
        Logger.info("✅ 敏感資料清除完成", category: .general)
    }
    
    // MARK: - 輸入驗證和清理
    
    /// 驗證和清理用戶輸入
    func validateAndSanitizeInput(_ input: String, type: InputType) throws -> String {
        guard !input.isEmpty else {
            throw SecurityError.emptyInput
        }
        
        // 長度檢查
        guard input.count <= type.maxLength else {
            throw SecurityError.inputTooLong(maxLength: type.maxLength)
        }
        
        // 字符檢查
        let allowedCharacterSet = type.allowedCharacters
        guard input.unicodeScalars.allSatisfy(allowedCharacterSet.contains) else {
            throw SecurityError.invalidCharacters
        }
        
        // SQL注入檢查
        if containsSQLInjectionPatterns(input) {
            Logger.warning("⚠️ 檢測到潛在SQL注入攻擊", category: .general)
            throw SecurityError.potentialSQLInjection
        }
        
        // XSS檢查
        if containsXSSPatterns(input) {
            Logger.warning("⚠️ 檢測到潛在XSS攻擊", category: .general)
            throw SecurityError.potentialXSS
        }
        
        // HTML清理
        let sanitizedInput = sanitizeHTML(input)
        
        Logger.debug("✅ 輸入驗證通過: \(type.displayName)", category: .general)
        return sanitizedInput
    }
    
    /// 驗證郵箱格式
    func validateEmail(_ email: String) -> Bool {
        let emailRegex = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let emailPredicate = NSPredicate(format: "SELF MATCHES %@", emailRegex)
        return emailPredicate.evaluate(with: email)
    }
    
    /// 驗證密碼強度
    func validatePassword(_ password: String) -> PasswordStrength {
        var score = 0
        var issues: [String] = []
        
        // 長度檢查
        if password.count >= 8 {
            score += 1
        } else {
            issues.append("密碼至少需要8個字符")
        }
        
        // 包含大寫字母
        if password.rangeOfCharacter(from: .uppercaseLetters) != nil {
            score += 1
        } else {
            issues.append("需要包含至少一個大寫字母")
        }
        
        // 包含小寫字母
        if password.rangeOfCharacter(from: .lowercaseLetters) != nil {
            score += 1
        } else {
            issues.append("需要包含至少一個小寫字母")
        }
        
        // 包含數字
        if password.rangeOfCharacter(from: .decimalDigits) != nil {
            score += 1
        } else {
            issues.append("需要包含至少一個數字")
        }
        
        // 包含特殊字符
        let specialCharacters = CharacterSet(charactersIn: "!@#$%^&*()_+-=[]{}|;:,.<>?")
        if password.rangeOfCharacter(from: specialCharacters) != nil {
            score += 1
        } else {
            issues.append("需要包含至少一個特殊字符")
        }
        
        let strength: PasswordStrength.Level
        switch score {
        case 0...2:
            strength = .weak
        case 3:
            strength = .medium
        case 4:
            strength = .strong
        case 5:
            strength = .veryStrong
        default:
            strength = .weak
        }
        
        return PasswordStrength(level: strength, score: score, issues: issues)
    }
    
    // MARK: - 資料加密
    
    /// 加密敏感資料
    func encrypt(_ data: Data, using key: String) throws -> Data {
        // 使用AES-256-GCM加密
        // 這裡應該實現真正的加密邏輯
        // 暫時返回原始資料（生產環境中絕不應該這樣做）
        Logger.warning("⚠️ 使用模擬加密，生產環境需要實現真正的加密", category: .general)
        return data
    }
    
    /// 解密資料
    func decrypt(_ encryptedData: Data, using key: String) throws -> Data {
        // 對應的解密邏輯
        Logger.warning("⚠️ 使用模擬解密，生產環境需要實現真正的解密", category: .general)
        return encryptedData
    }
    
    // MARK: - 私有方法
    
    private func containsSQLInjectionPatterns(_ input: String) -> Bool {
        let sqlPatterns = [
            "(?i)(union|select|insert|update|delete|drop|create|alter|exec|execute)",
            "(?i)(script|javascript|vbscript)",
            "(?i)('|(\\-\\-)|(;)|(\\||\\|)|(\\*|\\*))",
            "(?i)(or\\s+1=1|and\\s+1=1)",
            "(?i)(exec\\s*\\(|sp_|xp_)"
        ]
        
        for pattern in sqlPatterns {
            if input.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func containsXSSPatterns(_ input: String) -> Bool {
        let xssPatterns = [
            "(?i)<script[^>]*>.*?</script>",
            "(?i)<.*?on\\w+\\s*=",
            "(?i)javascript:",
            "(?i)vbscript:",
            "(?i)<iframe[^>]*>",
            "(?i)<object[^>]*>",
            "(?i)<embed[^>]*>"
        ]
        
        for pattern in xssPatterns {
            if input.range(of: pattern, options: .regularExpression) != nil {
                return true
            }
        }
        
        return false
    }
    
    private func sanitizeHTML(_ input: String) -> String {
        // 移除潛在的HTML標籤
        var sanitized = input
        
        // 基本HTML實體轉換
        let htmlEntities = [
            "<": "&lt;",
            ">": "&gt;",
            "\"": "&quot;",
            "'": "&#x27;",
            "&": "&amp;"
        ]
        
        for (char, entity) in htmlEntities {
            sanitized = sanitized.replacingOccurrences(of: char, with: entity)
        }
        
        return sanitized
    }
}

// MARK: - Keychain服務

private class KeychainService {
    
    func store(data: Data, for key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecValueData as String: data
        ]
        
        // 刪除現有項目
        SecItemDelete(query as CFDictionary)
        
        // 添加新項目
        let status = SecItemAdd(query as CFDictionary, nil)
        
        guard status == errSecSuccess else {
            throw SecurityError.keychainError(status)
        }
    }
    
    func retrieve(for key: KeychainKey) throws -> Data {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        
        guard status == errSecSuccess else {
            throw SecurityError.keychainError(status)
        }
        
        guard let data = result as? Data else {
            throw SecurityError.invalidKeychainData
        }
        
        return data
    }
    
    func delete(_ key: KeychainKey) throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        
        let status = SecItemDelete(query as CFDictionary)
        
        // 如果項目不存在也視為成功
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw SecurityError.keychainError(status)
        }
    }
}

// MARK: - 數據結構

/// 安全配置
struct SecureConfiguration: Codable {
    let supabaseURL: String
    let supabaseAnonKey: String
    let apnsTeamId: String?
    let apnsKeyId: String?
    
    // 環境檢查
    var isProduction: Bool {
        return !supabaseURL.contains("localhost") && !supabaseURL.contains("test")
    }
}

/// Keychain鍵
enum KeychainKey: String {
    case secureConfig = "secure_config"
    case authTokens = "auth_tokens"
    case userCredentials = "user_credentials"
}

/// 輸入類型
enum InputType {
    case username
    case email
    case message
    case articleContent
    case groupName
    case searchQuery
    
    var maxLength: Int {
        switch self {
        case .username: return 50
        case .email: return 255
        case .message: return 1000
        case .articleContent: return 50000
        case .groupName: return 100
        case .searchQuery: return 200
        }
    }
    
    var allowedCharacters: CharacterSet {
        switch self {
        case .username:
            return CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        case .email:
            return CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "@.-_"))
        case .message, .articleContent:
            return CharacterSet.alphanumerics
                .union(.whitespaces)
                .union(.punctuationCharacters)
                .union(.symbols)
        case .groupName:
            return CharacterSet.alphanumerics
                .union(.whitespaces)
                .union(CharacterSet(charactersIn: "-_()[]"))
        case .searchQuery:
            return CharacterSet.alphanumerics
                .union(.whitespaces)
                .union(CharacterSet(charactersIn: "\"'"))
        }
    }
    
    var displayName: String {
        switch self {
        case .username: return "username"
        case .email: return "email"
        case .message: return "message"
        case .articleContent: return "articleContent"
        case .groupName: return "groupName"
        case .searchQuery: return "searchQuery"
        }
    }
}

/// 密碼強度
struct PasswordStrength {
    enum Level {
        case weak
        case medium
        case strong
        case veryStrong
        
        var description: String {
            switch self {
            case .weak: return "弱"
            case .medium: return "中等"
            case .strong: return "強"
            case .veryStrong: return "非常強"
            }
        }
        
        var color: UIColor {
            switch self {
            case .weak: return .systemRed
            case .medium: return .systemOrange
            case .strong: return .systemBlue
            case .veryStrong: return .systemGreen
            }
        }
    }
    
    let level: Level
    let score: Int
    let issues: [String]
}

/// 安全錯誤
enum SecurityError: LocalizedError {
    case emptyInput
    case inputTooLong(maxLength: Int)
    case invalidCharacters
    case potentialSQLInjection
    case potentialXSS
    case keychainError(OSStatus)
    case invalidKeychainData
    
    var errorDescription: String? {
        switch self {
        case .emptyInput:
            return "輸入不能為空"
        case .inputTooLong(let maxLength):
            return "輸入長度不能超過\(maxLength)個字符"
        case .invalidCharacters:
            return "輸入包含不允許的字符"
        case .potentialSQLInjection:
            return "輸入包含潛在的SQL注入攻擊"
        case .potentialXSS:
            return "輸入包含潛在的XSS攻擊"
        case .keychainError(let status):
            return "Keychain錯誤: \(status)"
        case .invalidKeychainData:
            return "Keychain數據格式錯誤"
        }
    }
}