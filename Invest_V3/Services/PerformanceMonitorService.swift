import Foundation
import SwiftUI
import UIKit

/// 效能監控服務
/// 負責監控應用程式效能、記憶體使用、網路請求等指標
@MainActor
class PerformanceMonitorService: ObservableObject {
    static let shared = PerformanceMonitorService()
    
    // MARK: - 監控狀態
    
    @Published var memoryUsage: MemoryUsage = MemoryUsage()
    @Published var networkMetrics: NetworkMetrics = NetworkMetrics()
    @Published var appPerformance: AppPerformance = AppPerformance()
    
    private var monitoringTimer: Timer?
    private var networkRequests: [NetworkRequest] = []
    private let maxRequestHistory = 100
    
    private init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoringNonisolated()
    }
    
    // MARK: - 監控控制
    
    /// 開始效能監控
    func startMonitoring() {
        Logger.info("📊 開始效能監控", category: .performance)
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.updateMetrics()
            }
        }
    }
    
    /// 停止效能監控
    func stopMonitoring() {
        Logger.info("⏹️ 停止效能監控", category: .performance)
        
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    /// 停止效能監控 (nonisolated version for deinit)
    nonisolated func stopMonitoringNonisolated() {
        Task { @MainActor in
            stopMonitoring()
        }
    }
    
    /// 更新監控指標
    private func updateMetrics() async {
        await MainActor.run {
            self.memoryUsage = self.getCurrentMemoryUsage()
            self.appPerformance.updateFPS()
            self.networkMetrics.updateAverageResponseTime(from: self.networkRequests)
        }
    }
    
    // MARK: - 記憶體監控
    
    /// 獲取當前記憶體使用情況
    private func getCurrentMemoryUsage() -> MemoryUsage {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let usedMemoryMB = Double(info.resident_size) / 1024.0 / 1024.0
            let totalMemoryMB = Double(ProcessInfo.processInfo.physicalMemory) / 1024.0 / 1024.0
            
            return MemoryUsage(
                usedMemoryMB: usedMemoryMB,
                totalMemoryMB: totalMemoryMB,
                memoryPressure: getMemoryPressure(usedMemoryMB, totalMemoryMB)
            )
        }
        
        return MemoryUsage()
    }
    
    private func getMemoryPressure(_ used: Double, _ total: Double) -> MemoryPressure {
        let percentage = used / total
        
        if percentage > 0.8 {
            return .critical
        } else if percentage > 0.6 {
            return .high
        } else if percentage > 0.4 {
            return .moderate
        } else {
            return .normal
        }
    }
    
    /// 檢查記憶體洩漏
    func checkForMemoryLeaks() -> MemoryLeakReport {
        Logger.info("🔍 檢查記憶體洩漏", category: .performance)
        
        let currentMemory = getCurrentMemoryUsage()
        
        // 簡化的記憶體洩漏檢測
        var suspiciousPatterns: [String] = []
        
        if currentMemory.usedMemoryMB > 500 { // 500MB以上可能有問題
            suspiciousPatterns.append("記憶體使用量過高: \(String(format: "%.1f", currentMemory.usedMemoryMB))MB")
        }
        
        if currentMemory.memoryPressure == .critical {
            suspiciousPatterns.append("記憶體壓力過高")
        }
        
        return MemoryLeakReport(
            timestamp: Date(),
            currentMemory: currentMemory,
            suspiciousPatterns: suspiciousPatterns,
            hasLeaks: !suspiciousPatterns.isEmpty
        )
    }
    
    // MARK: - 網路監控
    
    /// 記錄網路請求
    func recordNetworkRequest(_ request: NetworkRequest) {
        networkRequests.append(request)
        
        // 保持請求歷史記錄在合理範圍內
        if networkRequests.count > maxRequestHistory {
            networkRequests.removeFirst(networkRequests.count - maxRequestHistory)
        }
        
        // 更新網路指標
        networkMetrics.totalRequests += 1
        
        if request.isSuccessful {
            networkMetrics.successfulRequests += 1
        } else {
            networkMetrics.failedRequests += 1
        }
        
        Logger.debug("📡 記錄網路請求: \(request.url) - \(request.responseTime)ms", category: .performance)
    }
    
    /// 分析網路效能
    func analyzeNetworkPerformance() -> NetworkPerformanceReport {
        let recentRequests = networkRequests.suffix(50) // 最近50個請求
        
        let averageResponseTime = recentRequests.isEmpty ? 0 :
            recentRequests.reduce(0) { $0 + $1.responseTime } / Double(recentRequests.count)
        
        let successRate = networkMetrics.totalRequests == 0 ? 0 :
            Double(networkMetrics.successfulRequests) / Double(networkMetrics.totalRequests)
        
        let slowRequests = recentRequests.filter { $0.responseTime > 3000 } // 超過3秒的請求
        
        var performanceIssues: [String] = []
        
        if averageResponseTime > 2000 {
            performanceIssues.append("平均響應時間過長: \(String(format: "%.0f", averageResponseTime))ms")
        }
        
        if successRate < 0.95 {
            performanceIssues.append("成功率過低: \(String(format: "%.1f", successRate * 100))%")
        }
        
        if !slowRequests.isEmpty {
            performanceIssues.append("發現\(slowRequests.count)個慢請求")
        }
        
        return NetworkPerformanceReport(
            averageResponseTime: averageResponseTime,
            successRate: successRate,
            slowRequestsCount: slowRequests.count,
            performanceIssues: performanceIssues
        )
    }
    
    // MARK: - 快取監控
    
    /// 監控快取效能
    func monitorCachePerformance() -> CachePerformanceReport {
        // 獲取NSURLCache統計
        let urlCache = URLCache.shared
        
        // 獲取圖片快取統計（如果有自定義圖片快取）
        let imageCache = getImageCacheStatistics()
        
        return CachePerformanceReport(
            urlCacheSize: Double(urlCache.currentDiskUsage) / 1024.0 / 1024.0, // MB
            urlCacheHitRate: 0.0, // URLCache沒有提供命中率API
            imageCacheSize: imageCache.size,
            imageCacheHitRate: imageCache.hitRate
        )
    }
    
    private func getImageCacheStatistics() -> (size: Double, hitRate: Double) {
        // 這裡應該實現實際的圖片快取統計
        // 如果使用了像Kingfisher這樣的圖片快取庫，可以獲取其統計資訊
        return (size: 0.0, hitRate: 0.0)
    }
    
    // MARK: - 效能報告
    
    /// 生成完整的效能報告
    func generatePerformanceReport() -> PerformanceReport {
        let memoryLeakReport = checkForMemoryLeaks()
        let networkReport = analyzeNetworkPerformance()
        let cacheReport = monitorCachePerformance()
        
        return PerformanceReport(
            timestamp: Date(),
            memoryUsage: memoryUsage,
            networkMetrics: networkMetrics,
            appPerformance: appPerformance,
            memoryLeakReport: memoryLeakReport,
            networkPerformanceReport: networkReport,
            cachePerformanceReport: cacheReport
        )
    }
    
    /// 匯出效能數據
    func exportPerformanceData() -> String {
        let report = generatePerformanceReport()
        
        let jsonEncoder = JSONEncoder()
        jsonEncoder.dateEncodingStrategy = .iso8601
        jsonEncoder.outputFormatting = .prettyPrinted
        
        do {
            let jsonData = try jsonEncoder.encode(report)
            return String(data: jsonData, encoding: .utf8) ?? "無法匯出數據"
        } catch {
            Logger.error("❌ 匯出效能數據失敗: \(error)", category: .performance)
            return "匯出失敗: \(error.localizedDescription)"
        }
    }
}

// MARK: - 數據結構

/// 記憶體使用情況
struct MemoryUsage: Codable {
    let usedMemoryMB: Double
    let totalMemoryMB: Double
    let memoryPressure: MemoryPressure
    
    init() {
        self.usedMemoryMB = 0
        self.totalMemoryMB = 0
        self.memoryPressure = .normal
    }
    
    init(usedMemoryMB: Double, totalMemoryMB: Double, memoryPressure: MemoryPressure) {
        self.usedMemoryMB = usedMemoryMB
        self.totalMemoryMB = totalMemoryMB
        self.memoryPressure = memoryPressure
    }
    
    var usagePercentage: Double {
        guard totalMemoryMB > 0 else { return 0 }
        return usedMemoryMB / totalMemoryMB
    }
}

/// 記憶體壓力等級
enum MemoryPressure: String, Codable {
    case normal = "normal"
    case moderate = "moderate" 
    case high = "high"
    case critical = "critical"
    
    var displayName: String {
        switch self {
        case .normal: return "正常"
        case .moderate: return "中等"
        case .high: return "高"
        case .critical: return "嚴重"
        }
    }
    
    var color: UIColor {
        switch self {
        case .normal: return .systemGreen
        case .moderate: return .systemYellow
        case .high: return .systemOrange
        case .critical: return .systemRed
        }
    }
}

/// 網路指標
struct NetworkMetrics: Codable {
    var totalRequests: Int = 0
    var successfulRequests: Int = 0
    var failedRequests: Int = 0
    var averageResponseTime: Double = 0
    
    var successRate: Double {
        guard totalRequests > 0 else { return 0 }
        return Double(successfulRequests) / Double(totalRequests)
    }
    
    mutating func updateAverageResponseTime(from requests: [NetworkRequest]) {
        guard !requests.isEmpty else { return }
        
        let recentRequests = requests.suffix(20) // 最近20個請求
        averageResponseTime = recentRequests.reduce(0) { $0 + $1.responseTime } / Double(recentRequests.count)
    }
}

/// 網路請求記錄
struct NetworkRequest: Codable {
    let url: String
    let method: String
    let responseTime: Double // 毫秒
    let statusCode: Int
    let timestamp: Date
    
    var isSuccessful: Bool {
        return statusCode >= 200 && statusCode < 300
    }
}

/// 應用程式效能
struct AppPerformance: Codable {
    var currentFPS: Double = 60.0
    var averageFPS: Double = 60.0
    var frameDrops: Int = 0
    var launchTime: TimeInterval = 0
    
    mutating func updateFPS() {
        // 這裡應該實現實際的FPS監控邏輯
        // iOS沒有直接的FPS監控API，需要使用CADisplayLink或其他方法
        currentFPS = 60.0 // 預設值
    }
}

/// 記憶體洩漏報告
struct MemoryLeakReport: Codable {
    let timestamp: Date
    let currentMemory: MemoryUsage
    let suspiciousPatterns: [String]
    let hasLeaks: Bool
}

/// 網路效能報告
struct NetworkPerformanceReport: Codable {
    let averageResponseTime: Double
    let successRate: Double
    let slowRequestsCount: Int
    let performanceIssues: [String]
}

/// 快取效能報告
struct CachePerformanceReport: Codable {
    let urlCacheSize: Double // MB
    let urlCacheHitRate: Double
    let imageCacheSize: Double // MB
    let imageCacheHitRate: Double
}

/// 完整效能報告
struct PerformanceReport: Codable {
    let timestamp: Date
    let memoryUsage: MemoryUsage
    let networkMetrics: NetworkMetrics
    let appPerformance: AppPerformance
    let memoryLeakReport: MemoryLeakReport
    let networkPerformanceReport: NetworkPerformanceReport
    let cachePerformanceReport: CachePerformanceReport
}