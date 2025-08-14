import Foundation

// MARK: - 統一的 Supabase 錯誤處理系統
enum SupabaseError: Error, LocalizedError {
    // 初始化相關錯誤
    case notInitialized
    case initializationFailed(String)
    
    // 認證相關錯誤
    case notAuthenticated
    case invalidCredentials
    case userNotFound
    case emailAlreadyInUse
    case weakPassword
    case invalidInput(String)
    
    // 網路相關錯誤
    case networkError
    case serverError(Int)
    case timeout
    
    // 資料相關錯誤
    case dataNotFound
    case dataFetchFailed(String)
    case dataCorrupted
    case uploadFailed
    case downloadFailed
    
    // 權限相關錯誤
    case accessDenied
    case insufficientPermissions
    
    // 代幣相關錯誤
    case insufficientBalance
    case invalidTokenAmount
    
    // 一般錯誤
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        // 初始化錯誤
        case .notInitialized:
            return "系統尚未初始化，請稍後再試"
        case .initializationFailed(let reason):
            return "系統初始化失敗：\(reason)"
            
        // 認證錯誤
        case .notAuthenticated:
            return "請先登入才能使用此功能"
        case .invalidCredentials:
            return "帳號或密碼錯誤，請重新輸入"
        case .userNotFound:
            return "找不到此用戶，請檢查帳號是否正確"
        case .emailAlreadyInUse:
            return "此 Email 已被使用，請使用其他 Email 註冊"
        case .weakPassword:
            return "密碼強度不足，請設定至少 8 個字元的密碼"
        case .invalidInput(let field):
            return "請正確填寫\(field)"
            
        // 網路錯誤
        case .networkError:
            return "網路連線有問題，請檢查網路設定"
        case .serverError(let code):
            return "伺服器錯誤 (\(code))，請稍後再試"
        case .timeout:
            return "連線逾時，請重新嘗試"
            
        // 資料錯誤
        case .dataNotFound:
            return "找不到相關資料"
        case .dataFetchFailed(let reason):
            return "資料獲取失敗：\(reason)"
        case .dataCorrupted:
            return "資料格式錯誤，請重新操作"
        case .uploadFailed:
            return "上傳失敗，請重新嘗試"
        case .downloadFailed:
            return "下載失敗，請重新嘗試"
            
        // 權限錯誤
        case .accessDenied:
            return "沒有權限執行此操作"
        case .insufficientPermissions:
            return "權限不足，請聯絡管理員"
            
        // 代幣錯誤
        case .insufficientBalance:
            return "代幣餘額不足，請先儲值"
        case .invalidTokenAmount:
            return "代幣數量無效"
            
        // 一般錯誤
        case .unknown(let message):
            return "未知錯誤：\(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .notAuthenticated:
            return "請前往登入頁面重新登入"
        case .networkError, .timeout:
            return "請檢查網路連線後重試"
        case .invalidCredentials:
            return "請確認帳號密碼正確性"
        case .emailAlreadyInUse:
            return "請使用其他 Email 或嘗試登入"
        case .weakPassword:
            return "密碼須包含至少 8 個字元"
        case .serverError:
            return "請稍後再試，若問題持續請聯絡客服"
        case .insufficientBalance:
            return "請前往錢包頁面儲值代幣"
        default:
            return "請重新嘗試，若問題持續請聯絡客服"
        }
    }
}

// MARK: - 錯誤轉換工具
extension SupabaseError {
    /// 將其他錯誤轉換為 SupabaseError
    static func from(_ error: Error) -> SupabaseError {
        if let supabaseError = error as? SupabaseError {
            return supabaseError
        }
        
        let errorString = error.localizedDescription.lowercased()
        
        // 認證相關錯誤判斷
        if errorString.contains("invalid_credentials") || 
           errorString.contains("invalid login") ||
           errorString.contains("email not confirmed") {
            return .invalidCredentials
        }
        
        if errorString.contains("user_not_found") {
            return .userNotFound
        }
        
        if errorString.contains("email_already_in_use") ||
           errorString.contains("user already registered") {
            return .emailAlreadyInUse
        }
        
        if errorString.contains("weak_password") ||
           errorString.contains("password") {
            return .weakPassword
        }
        
        // 網路相關錯誤判斷
        if errorString.contains("network") ||
           errorString.contains("connection") ||
           errorString.contains("internet") {
            return .networkError
        }
        
        if errorString.contains("timeout") ||
           errorString.contains("timed out") {
            return .timeout
        }
        
        // 伺服器錯誤判斷
        if errorString.contains("500") || errorString.contains("internal server error") {
            return .serverError(500)
        }
        
        if errorString.contains("401") || errorString.contains("unauthorized") {
            return .notAuthenticated
        }
        
        if errorString.contains("403") || errorString.contains("forbidden") {
            return .accessDenied
        }
        
        if errorString.contains("404") || errorString.contains("not found") {
            return .dataNotFound
        }
        
        // 預設為未知錯誤
        return .unknown(error.localizedDescription)
    }
}