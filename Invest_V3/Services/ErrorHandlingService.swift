import Foundation
import Network
import UIKit

/// 錯誤處理和重試服務
/// 負責統一的錯誤處理、自動重試、錯誤報告和恢復策略
@MainActor
class ErrorHandlingService: ObservableObject {
    static let shared = ErrorHandlingService()
    
    // MARK: - 錯誤統計
    
    @Published var errorStats = ErrorStatistics()
    
    private var errorHistory: [ErrorRecord] = []
    private let maxErrorHistory = 500
    private let networkMonitor = NWPathMonitor()
    private var isNetworkAvailable = true
    
    private init() {
        setupNetworkMonitoring()
    }
    
    // MARK: - 網路監控
    
    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            Task {
                await MainActor.run {
                    self?.isNetworkAvailable = path.status == .satisfied
                    Logger.debug("📡 網路狀態: \(path.status)", category: .network)
                }
            }
        }
        
        let queue = DispatchQueue(label: "NetworkMonitor")
        networkMonitor.start(queue: queue)
    }
    
    // MARK: - 錯誤處理
    
    /// 處理錯誤並決定是否需要重試
    func handleError<T>(
        _ error: Error,
        context: ErrorContext,
        retryCount: Int = 0,
        maxRetries: Int = 3,
        retryStrategy: RetryStrategy = .exponentialBackoff,
        operation: @escaping () async throws -> T
    ) async throws -> T {
        
        // 記錄錯誤
        recordError(error, context: context, retryCount: retryCount)
        
        // 檢查是否應該重試
        let shouldRetry = shouldRetryError(error, retryCount: retryCount, maxRetries: maxRetries)
        
        if shouldRetry {
            Logger.info("🔄 重試操作 \(retryCount + 1)/\(maxRetries): \(context.operation)", category: .general)
            
            // 計算重試延遲
            let delay = calculateRetryDelay(retryStrategy: retryStrategy, retryCount: retryCount)
            
            // 等待
            try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            
            // 遞歸重試
            return try await handleError(
                error,
                context: context,
                retryCount: retryCount + 1,
                maxRetries: maxRetries,
                retryStrategy: retryStrategy,
                operation: operation
            )
        }
        
        // 重試失敗或不應重試，拋出最終錯誤
        let finalError = createUserFriendlyError(error, context: context)
        Logger.error("❌ 操作最終失敗: \(context.operation) - \(finalError.localizedDescription)", category: .general)
        
        throw finalError
    }
    
    /// 簡化版本的錯誤處理（不重試）
    func handleError(_ error: Error, context: ErrorContext) -> AppError {
        recordError(error, context: context, retryCount: 0)
        return createUserFriendlyError(error, context: context)
    }
    
    // MARK: - 重試邏輯
    
    private func shouldRetryError(_ error: Error, retryCount: Int, maxRetries: Int) -> Bool {
        // 已達到最大重試次數
        guard retryCount < maxRetries else { return false }
        
        // 網路不可用時不重試
        guard isNetworkAvailable else { return false }
        
        // 根據錯誤類型決定是否重試
        switch error {
        case let urlError as URLError:
            return shouldRetryURLError(urlError)
        case let appError as AppError:
            return appError.isRetryable
        case is CancellationError:
            return false // 取消的操作不重試
        default:
            // 其他網路相關錯誤可以重試
            return true
        }
    }
    
    private func shouldRetryURLError(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .notConnectedToInternet:
            return true
        case .badServerResponse, .cannotFindHost, .cannotConnectToHost:
            return true
        case .userCancelledAuthentication, .userAuthenticationRequired:
            return false
        default:
            return false
        }
    }
    
    private func calculateRetryDelay(retryStrategy: RetryStrategy, retryCount: Int) -> Double {
        switch retryStrategy {
        case .immediate:
            return 0
        case .linear(let baseDelay):
            return baseDelay * Double(retryCount + 1)
        case .exponentialBackoff:
            let baseDelay = 1.0
            let maxDelay = 30.0
            let delay = baseDelay * pow(2.0, Double(retryCount))
            return min(delay, maxDelay)
        case .custom(let delayCalculator):
            return delayCalculator(retryCount)
        }
    }
    
    // MARK: - 錯誤記錄
    
    private func recordError(_ error: Error, context: ErrorContext, retryCount: Int) {
        let errorRecord = ErrorRecord(
            error: error,
            context: context,
            retryCount: retryCount,
            timestamp: Date(),
            isNetworkAvailable: isNetworkAvailable
        )
        
        errorHistory.append(errorRecord)
        
        // 保持錯誤歷史記錄在合理範圍內
        if errorHistory.count > maxErrorHistory {
            errorHistory.removeFirst(errorHistory.count - maxErrorHistory)
        }
        
        // 更新統計
        updateErrorStatistics(errorRecord)
        
        Logger.error("📝 錯誤記錄: \(context.operation) - \(error.localizedDescription)", category: .general)
    }
    
    private func updateErrorStatistics(_ record: ErrorRecord) {
        errorStats.totalErrors += 1
        
        let errorType = classifyError(record.error)
        switch errorType {
        case .network:
            errorStats.networkErrors += 1
        case .authentication:
            errorStats.authenticationErrors += 1
        case .validation:
            errorStats.validationErrors += 1
        case .server:
            errorStats.serverErrors += 1
        case .client:
            errorStats.clientErrors += 1
        case .unknown:
            errorStats.unknownErrors += 1
        }
        
        if record.retryCount > 0 {
            errorStats.retriedErrors += 1
        }
    }
    
    private func classifyError(_ error: Error) -> ErrorType {
        switch error {
        case is URLError:
            return .network
        case let appError as AppError:
            return appError.type
        case is DecodingError, is EncodingError:
            return .client
        default:
            return .unknown
        }
    }
    
    // MARK: - 用戶友好錯誤
    
    private func createUserFriendlyError(_ error: Error, context: ErrorContext) -> AppError {
        switch error {
        case let urlError as URLError:
            return createNetworkError(urlError, context: context)
        case let appError as AppError:
            return appError
        case is DecodingError:
            return AppError(
                type: .client,
                title: "資料處理錯誤",
                message: "應用程式無法處理伺服器返回的資料，請稍後再試。",
                underlyingError: error,
                context: context,
                isRetryable: true
            )
        case is CancellationError:
            return AppError(
                type: .client,
                title: "操作已取消",
                message: "操作已被用戶取消。",
                underlyingError: error,
                context: context,
                isRetryable: false
            )
        default:
            return AppError(
                type: .unknown,
                title: "未知錯誤",
                message: "發生了未預期的錯誤，請稍後再試。",
                underlyingError: error,
                context: context,
                isRetryable: true
            )
        }
    }
    
    private func createNetworkError(_ urlError: URLError, context: ErrorContext) -> AppError {
        let (title, message, isRetryable) = getNetworkErrorInfo(urlError)
        
        return AppError(
            type: .network,
            title: title,
            message: message,
            underlyingError: urlError,
            context: context,
            isRetryable: isRetryable
        )
    }
    
    private func getNetworkErrorInfo(_ error: URLError) -> (title: String, message: String, isRetryable: Bool) {
        switch error.code {
        case .notConnectedToInternet:
            return ("網路連接錯誤", "請檢查您的網路連接後再試。", true)
        case .timedOut:
            return ("連接超時", "網路連接超時，請稍後再試。", true)
        case .cannotFindHost, .cannotConnectToHost:
            return ("無法連接伺服器", "無法連接到伺服器，請稍後再試。", true)
        case .networkConnectionLost:
            return ("網路連接中斷", "網路連接已中斷，請檢查網路設定。", true)
        case .badServerResponse:
            return ("伺服器錯誤", "伺服器回應異常，請稍後再試。", true)
        case .userCancelledAuthentication:
            return ("驗證已取消", "您已取消身份驗證。", false)
        case .userAuthenticationRequired:
            return ("需要身份驗證", "請重新登入後再試。", false)
        default:
            return ("網路錯誤", "網路請求失敗，請檢查網路連接。", true)
        }
    }
    
    // MARK: - 錯誤恢復
    
    /// 提供錯誤恢復建議
    func getRecoveryActions(for error: AppError) -> [RecoveryAction] {
        var actions: [RecoveryAction] = []
        
        switch error.type {
        case .network:
            actions.append(RecoveryAction(
                title: "重試",
                description: "重新嘗試操作",
                action: { /* 重試邏輯 */ }
            ))
            actions.append(RecoveryAction(
                title: "檢查網路",
                description: "檢查網路連接設定",
                action: { /* 導航到設定 */ }
            ))
            
        case .authentication:
            actions.append(RecoveryAction(
                title: "重新登入",
                description: "重新進行身份驗證",
                action: { /* 導航到登入頁面 */ }
            ))
            
        case .validation:
            actions.append(RecoveryAction(
                title: "檢查輸入",
                description: "檢查並修正輸入的資料",
                action: { /* 回到輸入頁面 */ }
            ))
            
        default:
            if error.isRetryable {
                actions.append(RecoveryAction(
                    title: "重試",
                    description: "重新嘗試操作",
                    action: { /* 重試邏輯 */ }
                ))
            }
        }
        
        // 通用操作
        actions.append(RecoveryAction(
            title: "回報問題",
            description: "向技術支援回報此問題",
            action: { /* 開啟回報功能 */ }
        ))
        
        return actions
    }
    
    // MARK: - 錯誤報告
    
    /// 生成錯誤報告
    func generateErrorReport() -> ErrorReport {
        let recentErrors = errorHistory.suffix(100) // 最近100個錯誤
        
        return ErrorReport(
            timestamp: Date(),
            statistics: errorStats,
            recentErrors: Array(recentErrors),
            networkStatus: isNetworkAvailable,
            deviceInfo: getDeviceInfo()
        )
    }
    
    private func getDeviceInfo() -> ErrorDeviceInfo {
        let device = UIDevice.current
        
        return ErrorDeviceInfo(
            model: device.model,
            systemName: device.systemName,
            systemVersion: device.systemVersion,
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown"
        )
    }
    
    /// 清除錯誤歷史記錄
    func clearErrorHistory() {
        Logger.info("🧹 清除錯誤歷史記錄", category: .general)
        
        errorHistory.removeAll()
        errorStats = ErrorStatistics()
    }
}

// MARK: - 數據結構

/// 錯誤上下文
struct ErrorContext {
    let operation: String
    let userId: String?
    let additionalInfo: [String: Any]?
    
    init(operation: String, userId: String? = nil, additionalInfo: [String: Any]? = nil) {
        self.operation = operation
        self.userId = userId
        self.additionalInfo = additionalInfo
    }
}

/// 應用程式錯誤
struct AppError: LocalizedError, Identifiable {
    let id = UUID()
    let type: ErrorType
    let title: String
    let message: String
    let underlyingError: Error?
    let context: ErrorContext
    let isRetryable: Bool
    let timestamp: Date
    
    init(type: ErrorType, title: String, message: String, underlyingError: Error? = nil, context: ErrorContext, isRetryable: Bool) {
        self.type = type
        self.title = title
        self.message = message
        self.underlyingError = underlyingError
        self.context = context
        self.isRetryable = isRetryable
        self.timestamp = Date()
    }
    
    var errorDescription: String? {
        return message
    }
    
    var failureReason: String? {
        return title
    }
}

/// 錯誤類型
enum ErrorType {
    case network
    case authentication
    case validation
    case server
    case client
    case unknown
    
    var displayName: String {
        switch self {
        case .network: return "網路錯誤"
        case .authentication: return "驗證錯誤"
        case .validation: return "驗證錯誤"
        case .server: return "伺服器錯誤"
        case .client: return "用戶端錯誤"
        case .unknown: return "未知錯誤"
        }
    }
}

/// 資料庫操作錯誤
enum DatabaseError: LocalizedError {
    case unauthorized(String)
    case invalidOperation(String)
    case notFound(String)
    case constraintViolation(String)
    case connectionError(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorized(let message):
            return "權限錯誤: \(message)"
        case .invalidOperation(let message):
            return "無效操作: \(message)"
        case .notFound(let message):
            return "資料未找到: \(message)"
        case .constraintViolation(let message):
            return "資料約束錯誤: \(message)"
        case .connectionError(let message):
            return "連線錯誤: \(message)"
        }
    }
}

/// 重試策略
enum RetryStrategy {
    case immediate
    case linear(baseDelay: Double)
    case exponentialBackoff
    case custom((Int) -> Double)
}

/// 錯誤記錄
struct ErrorRecord {
    let error: Error
    let context: ErrorContext
    let retryCount: Int
    let timestamp: Date
    let isNetworkAvailable: Bool
}

/// 錯誤統計
struct ErrorStatistics {
    var totalErrors: Int = 0
    var networkErrors: Int = 0
    var authenticationErrors: Int = 0
    var validationErrors: Int = 0
    var serverErrors: Int = 0
    var clientErrors: Int = 0
    var unknownErrors: Int = 0
    var retriedErrors: Int = 0
}

/// 恢復操作
struct RecoveryAction {
    let title: String
    let description: String
    let action: () -> Void
}

/// 錯誤報告
struct ErrorReport: Codable {
    let timestamp: Date
    let statistics: ErrorStatistics
    let recentErrors: [ErrorRecordInfo] // 簡化版本的錯誤記錄
    let networkStatus: Bool
    let deviceInfo: ErrorDeviceInfo
}

/// 簡化的錯誤記錄資訊（用於報告）
struct ErrorRecordInfo: Codable {
    let operation: String
    let errorType: String
    let retryCount: Int
    let timestamp: Date
}

/// 錯誤報告用設備資訊
struct ErrorDeviceInfo: Codable {
    let model: String
    let systemName: String
    let systemVersion: String
    let appVersion: String
}

// MARK: - ErrorStatistics Codable 擴展

extension ErrorStatistics: Codable {
    // 讓ErrorStatistics符合Codable協議
}

extension ErrorRecord {
    var simplified: ErrorRecordInfo {
        return ErrorRecordInfo(
            operation: context.operation,
            errorType: String(describing: type(of: error)),
            retryCount: retryCount,
            timestamp: timestamp
        )
    }
}

extension ErrorReport {
    init(timestamp: Date, statistics: ErrorStatistics, recentErrors: [ErrorRecord], networkStatus: Bool, deviceInfo: ErrorDeviceInfo) {
        self.timestamp = timestamp
        self.statistics = statistics
        self.recentErrors = recentErrors.map { $0.simplified }
        self.networkStatus = networkStatus
        self.deviceInfo = deviceInfo
    }
}