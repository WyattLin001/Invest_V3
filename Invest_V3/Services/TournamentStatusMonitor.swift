//
//  TournamentStatusMonitor.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽狀態實時監控服務 - 負責監控錦標賽狀態變化並觸發相應操作
//

import Foundation
import Combine
import UserNotifications

// MARK: - 狀態變化事件
enum TournamentStatusChangeEvent {
    case aboutToStart(Tournament, timeRemaining: TimeInterval)
    case justStarted(Tournament)
    case aboutToEnd(Tournament, timeRemaining: TimeInterval)
    case justEnded(Tournament)
    case statusChanged(Tournament, from: TournamentStatus, to: TournamentStatus)
}

// MARK: - 錦標賽狀態實時監控服務
@MainActor
class TournamentStatusMonitor: ObservableObject {
    static let shared = TournamentStatusMonitor()
    
    // MARK: - Properties
    @Published var isMonitoring = false
    @Published var statusEvents: [TournamentStatusChangeEvent] = []
    
    private let tournamentService = TournamentService.shared
    private let stateManager = TournamentStateManager.shared
    private var monitorTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    // 監控配置
    private let monitorInterval: TimeInterval = 10.0  // 10秒檢查一次
    private let notificationThresholds: [TimeInterval] = [300, 600, 1800] // 5分鐘、10分鐘、30分鐘提醒
    private var lastNotificationTimes: [UUID: [TimeInterval: Date]] = [:] // 避免重複通知
    
    private init() {
        setupTournamentObservers()
        requestNotificationPermission()
    }
    
    // MARK: - Public Methods
    
    /// 開始監控錦標賽狀態變化
    func startMonitoring() {
        guard !isMonitoring else { return }
        
        print("🎯 [TournamentStatusMonitor] 開始監控錦標賽狀態變化")
        isMonitoring = true
        
        monitorTimer = Timer.scheduledTimer(withTimeInterval: monitorInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.checkTournamentStatusChanges()
            }
        }
    }
    
    /// 停止監控
    func stopMonitoring() {
        guard isMonitoring else { return }
        
        print("🎯 [TournamentStatusMonitor] 停止監控錦標賽狀態變化")
        isMonitoring = false
        
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
    
    /// 手動檢查狀態變化
    func checkStatusChanges() async {
        await checkTournamentStatusChanges()
    }
    
    /// 清除事件記錄
    func clearStatusEvents() {
        statusEvents.removeAll()
    }
    
    // MARK: - Private Methods
    
    private func setupTournamentObservers() {
        // 監聽錦標賽服務的錦標賽更新
        tournamentService.$tournaments
            .sink { [weak self] tournaments in
                Task { @MainActor in
                    await self?.handleTournamentUpdates(tournaments)
                }
            }
            .store(in: &cancellables)
        
        // 監聽錦標賽狀態管理器的狀態變化
        stateManager.$currentTournamentContext
            .sink { [weak self] context in
                Task { @MainActor in
                    await self?.handleContextChange(context)
                }
            }
            .store(in: &cancellables)
    }
    
    private func handleTournamentUpdates(_ tournaments: [Tournament]) async {
        // 檢查所有錦標賽的狀態轉換點
        for tournament in tournaments {
            await checkTournamentTransitions(tournament)
        }
    }
    
    private func handleContextChange(_ context: TournamentContext?) async {
        guard let context = context else { return }
        
        // 重點監控當前參與的錦標賽
        await checkTournamentTransitions(context.tournament)
    }
    
    private func checkTournamentStatusChanges() async {
        let tournaments = tournamentService.tournaments
        
        for tournament in tournaments {
            await checkTournamentTransitions(tournament)
        }
    }
    
    private func checkTournamentTransitions(_ tournament: Tournament) async {
        let nowUTC = Date().toUTC()
        let startDateUTC = tournament.startDateUTC
        let endDateUTC = tournament.endDateUTC
        
        // 檢查即將開始的錦標賽
        let timeToStart = startDateUTC.timeIntervalSince(nowUTC)
        if timeToStart > 0 && timeToStart <= (notificationThresholds.max() ?? 1800) {
            await handleUpcomingStart(tournament, timeRemaining: timeToStart)
        }
        
        // 檢查剛開始的錦標賽
        if timeToStart <= 0 && timeToStart >= -60 { // 剛開始的1分鐘內
            await handleJustStarted(tournament)
        }
        
        // 檢查即將結束的錦標賽
        let timeToEnd = endDateUTC.timeIntervalSince(nowUTC)
        if timeToEnd > 0 && timeToEnd <= (notificationThresholds.max() ?? 1800) {
            await handleUpcomingEnd(tournament, timeRemaining: timeToEnd)
        }
        
        // 檢查剛結束的錦標賽
        if timeToEnd <= 0 && timeToEnd >= -60 { // 剛結束的1分鐘內
            await handleJustEnded(tournament)
        }
        
        // 檢查狀態變化
        await checkStatusChange(tournament)
    }
    
    private func handleUpcomingStart(_ tournament: Tournament, timeRemaining: TimeInterval) async {
        // 檢查是否需要發送通知
        for threshold in notificationThresholds {
            if timeRemaining <= threshold && timeRemaining > threshold - monitorInterval {
                if !hasRecentNotification(for: tournament.id, threshold: threshold) {
                    let event = TournamentStatusChangeEvent.aboutToStart(tournament, timeRemaining: timeRemaining)
                    await processStatusEvent(event)
                    recordNotification(for: tournament.id, threshold: threshold)
                }
            }
        }
    }
    
    private func handleJustStarted(_ tournament: Tournament) async {
        if !hasRecentNotification(for: tournament.id, threshold: 0) {
            let event = TournamentStatusChangeEvent.justStarted(tournament)
            await processStatusEvent(event)
            recordNotification(for: tournament.id, threshold: 0)
        }
    }
    
    private func handleUpcomingEnd(_ tournament: Tournament, timeRemaining: TimeInterval) async {
        // 只在錦標賽進行中時提醒即將結束
        guard tournament.computedStatusUTC == .ongoing else { return }
        
        for threshold in notificationThresholds {
            if timeRemaining <= threshold && timeRemaining > threshold - monitorInterval {
                if !hasRecentNotification(for: tournament.id, threshold: -threshold) { // 負數區分結束提醒
                    let event = TournamentStatusChangeEvent.aboutToEnd(tournament, timeRemaining: timeRemaining)
                    await processStatusEvent(event)
                    recordNotification(for: tournament.id, threshold: -threshold)
                }
            }
        }
    }
    
    private func handleJustEnded(_ tournament: Tournament) async {
        if !hasRecentNotification(for: tournament.id, threshold: -1) { // -1 代表剛結束
            let event = TournamentStatusChangeEvent.justEnded(tournament)
            await processStatusEvent(event)
            recordNotification(for: tournament.id, threshold: -1)
        }
    }
    
    private func checkStatusChange(_ tournament: Tournament) async {
        let currentStatus = tournament.status
        let computedStatus = tournament.computedStatusUTC
        
        if currentStatus != computedStatus {
            let event = TournamentStatusChangeEvent.statusChanged(tournament, from: currentStatus, to: computedStatus)
            await processStatusEvent(event)
        }
    }
    
    private func processStatusEvent(_ event: TournamentStatusChangeEvent) async {
        statusEvents.append(event)
        
        // 記錄事件
        await logStatusEvent(event)
        
        // 發送系統通知
        await sendSystemNotification(for: event)
        
        // 觸發相關服務更新
        await triggerServiceUpdates(for: event)
        
        // 限制事件數量，避免記憶體膨脹
        if statusEvents.count > 100 {
            statusEvents.removeFirst(20)
        }
    }
    
    private func logStatusEvent(_ event: TournamentStatusChangeEvent) async {
        switch event {
        case .aboutToStart(let tournament, let timeRemaining):
            let minutes = Int(timeRemaining / 60)
            print("⏰ [TournamentStatusMonitor] 錦標賽 '\(tournament.name)' 將在 \(minutes) 分鐘後開始")
            
        case .justStarted(let tournament):
            print("🚀 [TournamentStatusMonitor] 錦標賽 '\(tournament.name)' 已開始！")
            
        case .aboutToEnd(let tournament, let timeRemaining):
            let minutes = Int(timeRemaining / 60)
            print("⏰ [TournamentStatusMonitor] 錦標賽 '\(tournament.name)' 將在 \(minutes) 分鐘後結束")
            
        case .justEnded(let tournament):
            print("🏁 [TournamentStatusMonitor] 錦標賽 '\(tournament.name)' 已結束！")
            
        case .statusChanged(let tournament, let from, let to):
            print("🔄 [TournamentStatusMonitor] 錦標賽 '\(tournament.name)' 狀態變更: \(from.displayName) → \(to.displayName)")
        }
    }
    
    private func sendSystemNotification(for event: TournamentStatusChangeEvent) async {
        let content = UNMutableNotificationContent()
        
        // 從事件中提取錦標賽
        let tournament: Tournament
        switch event {
        case .aboutToStart(let t, _):
            tournament = t
        case .justStarted(let t):
            tournament = t
        case .aboutToEnd(let t, _):
            tournament = t
        case .justEnded(let t):
            tournament = t
        case .statusChanged(let t, _, _):
            tournament = t
        }
        
        switch event {
        case .aboutToStart(_, let timeRemaining):
            let minutes = Int(timeRemaining / 60)
            content.title = "錦標賽即將開始"
            content.body = "'\(tournament.name)' 將在 \(minutes) 分鐘後開始"
            content.sound = .default
            
        case .justStarted(_):
            content.title = "錦標賽已開始"
            content.body = "'\(tournament.name)' 現在開始進行交易！"
            content.sound = .default
            
        case .aboutToEnd(_, let timeRemaining):
            let minutes = Int(timeRemaining / 60)
            content.title = "錦標賽即將結束"
            content.body = "'\(tournament.name)' 將在 \(minutes) 分鐘後結束"
            content.sound = .default
            
        case .justEnded(_):
            content.title = "錦標賽已結束"
            content.body = "'\(tournament.name)' 已結束，查看最終排名！"
            content.sound = .default
            
        case .statusChanged(_, _, let to):
            content.title = "錦標賽狀態更新"
            content.body = "'\(tournament.name)' 現在是 \(to.displayName)"
            content.sound = .default
        }
        
        // 設置通知 ID，避免重複
        let identifier = "tournament_\(tournament.id)_\(Date().timeIntervalSince1970)"
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        
        do {
            try await UNUserNotificationCenter.current().add(request)
        } catch {
            print("❌ [TournamentStatusMonitor] 發送通知失敗: \(error)")
        }
    }
    
    private func triggerServiceUpdates(for event: TournamentStatusChangeEvent) async {
        switch event {
        case .justStarted(let tournament):
            // 錦標賽開始時，更新相關服務
            await tournamentService.forceUpdateAllTournamentStatuses()
            
        case .justEnded(let tournament):
            // 錦標賽結束時，刷新排名和績效
            if let currentContext = stateManager.currentTournamentContext,
               currentContext.tournament.id == tournament.id {
                await stateManager.refreshCurrentTournamentContext()
            }
            
        case .statusChanged(let tournament, _, _):
            // 狀態變化時，強制刷新錦標賽數據
            await tournamentService.forceUpdateAllTournamentStatuses()
            
        default:
            break
        }
    }
    
    // MARK: - Notification Management
    
    private func hasRecentNotification(for tournamentId: UUID, threshold: TimeInterval) -> Bool {
        guard let notifications = lastNotificationTimes[tournamentId],
              let lastTime = notifications[threshold] else {
            return false
        }
        
        // 檢查是否在最近5分鐘內發送過相同類型的通知
        return Date().timeIntervalSince(lastTime) < 300
    }
    
    private func recordNotification(for tournamentId: UUID, threshold: TimeInterval) {
        if lastNotificationTimes[tournamentId] == nil {
            lastNotificationTimes[tournamentId] = [:]
        }
        lastNotificationTimes[tournamentId]?[threshold] = Date()
    }
    
    private func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("❌ [TournamentStatusMonitor] 通知權限請求失敗: \(error)")
            } else {
                print(granted ? "✅ [TournamentStatusMonitor] 已獲得通知權限" : "⚠️ [TournamentStatusMonitor] 未獲得通知權限")
            }
        }
    }
    
    deinit {
        // 在 deinit 中無法調用 @MainActor 方法，需要直接清理
        monitorTimer?.invalidate()
        monitorTimer = nil
    }
}

// MARK: - Extensions for Event Display

extension TournamentStatusChangeEvent: Identifiable {
    var id: String {
        switch self {
        case .aboutToStart(let tournament, let timeRemaining):
            return "start_\(tournament.id)_\(timeRemaining)"
        case .justStarted(let tournament):
            return "started_\(tournament.id)"
        case .aboutToEnd(let tournament, let timeRemaining):
            return "end_\(tournament.id)_\(timeRemaining)"
        case .justEnded(let tournament):
            return "ended_\(tournament.id)"
        case .statusChanged(let tournament, let from, let to):
            return "changed_\(tournament.id)_\(from)_\(to)"
        }
    }
    
    var displayMessage: String {
        switch self {
        case .aboutToStart(let tournament, let timeRemaining):
            let minutes = Int(timeRemaining / 60)
            return "錦標賽 '\(tournament.name)' 將在 \(minutes) 分鐘後開始"
        case .justStarted(let tournament):
            return "錦標賽 '\(tournament.name)' 已開始！"
        case .aboutToEnd(let tournament, let timeRemaining):
            let minutes = Int(timeRemaining / 60)
            return "錦標賽 '\(tournament.name)' 將在 \(minutes) 分鐘後結束"
        case .justEnded(let tournament):
            return "錦標賽 '\(tournament.name)' 已結束！"
        case .statusChanged(let tournament, let from, let to):
            return "錦標賽 '\(tournament.name)' 狀態變更: \(from.displayName) → \(to.displayName)"
        }
    }
    
    var timestamp: Date {
        return Date()
    }
}