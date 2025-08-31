import Foundation
import os

// MARK: - Logger Utility
/// Centralized logging system for Invest_V3
/// Replaces scattered print() statements with structured logging
struct Logger {
    private static let subsystem = "com.invest.v3"
    
    // MARK: - Log Categories
    enum Category: String, CaseIterable {
        case general = "General"
        case network = "Network"
        case auth = "Authentication"
        case database = "Database"
        case ui = "UserInterface"
        case editor = "Editor"
        case trading = "Trading"
        case tournament = "Tournament"
        case performance = "Performance"
        case debug = "Debug"
        
        var osLog: OSLog {
            return OSLog(subsystem: Logger.subsystem, category: self.rawValue)
        }
    }
    
    // MARK: - Log Levels
    enum Level {
        case debug    // 🔍 Debug information (only in DEBUG builds)
        case info     // ℹ️ General information
        case warning  // ⚠️ Warnings
        case error    // ❌ Errors
        case critical // 🚨 Critical errors
        
        var emoji: String {
            switch self {
            case .debug: return "🔍"
            case .info: return "ℹ️"
            case .warning: return "⚠️"
            case .error: return "❌"
            case .critical: return "🚨"
            }
        }
        
        var osLogType: OSLogType {
            switch self {
            case .debug: return .debug
            case .info: return .info
            case .warning: return .default
            case .error: return .error
            case .critical: return .fault
            }
        }
    }
    
    // MARK: - Configuration
    static var isEnabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()
    
    // MARK: - Logging Methods
    
    /// Log a debug message (only shown in DEBUG builds)
    static func debug(_ message: String, category: Category = .debug, file: String = #file, function: String = #function, line: Int = #line) {
        #if DEBUG
        log(message, level: .debug, category: category, file: file, function: function, line: line)
        #endif
    }
    
    /// Log an info message
    static func info(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .info, category: category, file: file, function: function, line: line)
    }
    
    /// Log a warning message
    static func warning(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .warning, category: category, file: file, function: function, line: line)
    }
    
    /// Log an error message
    static func error(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .error, category: category, file: file, function: function, line: line)
    }
    
    /// Log a critical error message
    static func critical(_ message: String, category: Category = .general, file: String = #file, function: String = #function, line: Int = #line) {
        log(message, level: .critical, category: category, file: file, function: function, line: line)
    }
    
    // MARK: - Private Implementation
    
    private static func log(_ message: String, level: Level, category: Category, file: String, function: String, line: Int) {
        guard isEnabled else { return }
        
        let fileName = URL(fileURLWithPath: file).lastPathComponent
        let formattedMessage = "\(level.emoji) [\(category.rawValue)] \(message)"
        
        #if DEBUG
        // Console output for development
        let debugInfo = "[\(fileName):\(line) \(function)]"
        print("\(formattedMessage) \(debugInfo)")
        #endif
        
        // System logging for production
        os_log("%@", log: category.osLog, type: level.osLogType, formattedMessage)
    }
    
    // MARK: - Performance Logging
    
    /// Measure and log execution time of a block
    static func measureTime<T>(
        _ message: String,
        category: Category = .performance,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        operation: () throws -> T
    ) rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try operation()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        debug("⏱️ \(message) took \(String(format: "%.3f", executionTime))s", category: category, file: file, function: function, line: line)
        return result
    }
    
    /// Measure and log execution time of an async block
    static func measureTimeAsync<T>(
        _ message: String,
        category: Category = .performance,
        file: String = #file,
        function: String = #function,
        line: Int = #line,
        operation: () async throws -> T
    ) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = try await operation()
        let executionTime = CFAbsoluteTimeGetCurrent() - startTime
        
        debug("⏱️ \(message) took \(String(format: "%.3f", executionTime))s", category: category, file: file, function: function, line: line)
        return result
    }
}

// MARK: - Convenience Extensions

extension Logger {
    // 網絡請求日誌快捷方法
    static func networkRequest(_ url: String, method: String = "GET") {
        Logger.debug("🌐 \(method) \(url)", category: .network)
    }
    
    static func networkResponse(_ url: String, statusCode: Int, responseTime: TimeInterval? = nil) {
        let timeInfo = responseTime.map { " (\(String(format: "%.3f", $0))s)" } ?? ""
        if statusCode >= 200 && statusCode < 300 {
            Logger.debug("✅ \(statusCode) \(url)\(timeInfo)", category: .network)
        } else {
            Logger.warning("⚠️ \(statusCode) \(url)\(timeInfo)", category: .network)
        }
    }
    
    static func networkError(_ url: String, error: Error) {
        Logger.error("❌ 網絡請求錯誤 \(url): \(error.localizedDescription)", category: .network)
    }
    
    // 資料庫操作日誌快捷方法
    static func databaseQuery(_ query: String) {
        Logger.debug("🗄️ 資料庫查詢: \(query)", category: .database)
    }
    
    static func databaseResult(_ query: String, count: Int? = nil) {
        let countInfo = count.map { " (\($0) 筆記錄)" } ?? ""
        Logger.debug("✅ 查詢完成\(countInfo): \(query)", category: .database)
    }
    
    static func databaseError(_ query: String, error: Error) {
        Logger.error("❌ 資料庫錯誤 '\(query)': \(error.localizedDescription)", category: .database)
    }
    
    // 使用者介面日誌快捷方法
    static func viewDidAppear(_ viewName: String) {
        Logger.debug("👁️ 視圖出現: \(viewName)", category: .ui)
    }
    
    static func userAction(_ action: String, context: String = "") {
        let contextInfo = context.isEmpty ? "" : " (\(context))"
        Logger.info("👤 使用者動作: \(action)\(contextInfo)", category: .ui)
    }
}