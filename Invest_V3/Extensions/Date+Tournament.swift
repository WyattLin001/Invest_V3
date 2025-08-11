//
//  Date+Tournament.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  錦標賽相關的日期處理擴展
//

import Foundation

// MARK: - Date Extensions for Tournament Time Management

extension Date {
    
    // MARK: - 時區轉換
    
    /// 轉換為UTC時區的日期
    func toUTC() -> Date {
        let timeZoneOffset = TimeZone.current.secondsFromGMT(for: self)
        return self.addingTimeInterval(-TimeInterval(timeZoneOffset))
    }
    
    /// 從UTC轉換為本地時區的日期
    func fromUTC() -> Date {
        let timeZoneOffset = TimeZone.current.secondsFromGMT(for: self)
        return self.addingTimeInterval(TimeInterval(timeZoneOffset))
    }
    
    /// 獲取UTC時間戳字符串
    var utcTimeString: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        return formatter.string(from: self)
    }
    
    // MARK: - 錦標賽專用時間判斷
    
    /// 是否為今天（基於UTC）
    var isToday: Bool {
        let calendar = Calendar.current
        let today = Date()
        return calendar.isDate(self.toUTC(), inSameDayAs: today.toUTC())
    }
    
    /// 是否為本週（基於UTC）
    var isThisWeek: Bool {
        let calendar = Calendar.current
        let today = Date()
        return calendar.isDate(self.toUTC(), equalTo: today.toUTC(), toGranularity: .weekOfYear)
    }
    
    /// 是否為本月（基於UTC）
    var isThisMonth: Bool {
        let calendar = Calendar.current
        let today = Date()
        return calendar.isDate(self.toUTC(), equalTo: today.toUTC(), toGranularity: .month)
    }
    
    // MARK: - 錦標賽時間格式化
    
    /// 錦標賽專用的日期格式化
    var tournamentDateString: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current // 使用用戶本地時區顯示
        formatter.dateFormat = "MM月dd日 HH:mm"
        return formatter.string(from: self)
    }
    
    /// 錦標賽專用的完整日期時間格式化
    var tournamentFullDateString: String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone.current
        formatter.dateFormat = "yyyy年MM月dd日 HH:mm:ss"
        return formatter.string(from: self)
    }
    
    /// 錦標賽持續時間格式化
    func durationString(to endDate: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day, .hour, .minute], from: self, to: endDate)
        
        let days = components.day ?? 0
        let hours = components.hour ?? 0
        let minutes = components.minute ?? 0
        
        if days > 0 {
            return "\(days)天\(hours)小時"
        } else if hours > 0 {
            return "\(hours)小時\(minutes)分鐘"
        } else {
            return "\(minutes)分鐘"
        }
    }
    
    // MARK: - 錦標賽時間驗證
    
    /// 驗證開始時間是否有效（不能是過去時間）
    var isValidStartTime: Bool {
        return self.toUTC() > Date().toUTC()
    }
    
    /// 驗證結束時間是否有效（必須晚於開始時間）
    func isValidEndTime(after startDate: Date) -> Bool {
        return self.toUTC() > startDate.toUTC()
    }
    
    /// 獲取下一個整點時間（用於錦標賽開始時間建議）
    var nextHour: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day, .hour], from: self)
        components.hour = (components.hour ?? 0) + 1
        components.minute = 0
        components.second = 0
        return calendar.date(from: components) ?? self
    }
    
    /// 獲取當天結束時間（23:59:59）
    var endOfDay: Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = 23
        components.minute = 59
        components.second = 59
        return calendar.date(from: components) ?? self
    }
}

// MARK: - 錦標賽時間工具類

struct TournamentTimeUtils {
    
    /// 建議的錦標賽開始時間（下一個整點）
    static var suggestedStartTime: Date {
        return Date().nextHour
    }
    
    /// 根據錦標賽類型獲取建議的結束時間
    static func suggestedEndTime(for type: TournamentType, startDate: Date) -> Date {
        let calendar = Calendar.current
        
        switch type {
        case .daily:
            return calendar.date(byAdding: .day, value: 1, to: startDate) ?? startDate
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: 1, to: startDate) ?? startDate
        case .monthly:
            return calendar.date(byAdding: .month, value: 1, to: startDate) ?? startDate
        case .quarterly:
            return calendar.date(byAdding: .month, value: 3, to: startDate) ?? startDate
        case .yearly:
            return calendar.date(byAdding: .year, value: 1, to: startDate) ?? startDate
        case .special:
            return calendar.date(byAdding: .day, value: 7, to: startDate) ?? startDate // 特別賽事默認7天
        }
    }
    
    /// 驗證錦標賽時間設置
    static func validateTournamentTimes(start: Date, end: Date) -> (isValid: Bool, errorMessage: String?) {
        let now = Date().toUTC()
        let startUTC = start.toUTC()
        let endUTC = end.toUTC()
        
        // 檢查開始時間不能是過去
        if startUTC <= now {
            return (false, "開始時間不能是過去時間")
        }
        
        // 檢查結束時間必須晚於開始時間
        if endUTC <= startUTC {
            return (false, "結束時間必須晚於開始時間")
        }
        
        // 檢查最短持續時間（至少1小時）
        let minimumDuration: TimeInterval = 3600 // 1小時
        if endUTC.timeIntervalSince(startUTC) < minimumDuration {
            return (false, "錦標賽持續時間至少需要1小時")
        }
        
        // 檢查最長持續時間（不超過1年）
        let maximumDuration: TimeInterval = 365 * 24 * 3600 // 1年
        if endUTC.timeIntervalSince(startUTC) > maximumDuration {
            return (false, "錦標賽持續時間不能超過1年")
        }
        
        return (true, nil)
    }
    
    /// 計算兩個時間點之間的差異描述
    static func timeDifferenceDescription(from startDate: Date, to endDate: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], 
                                              from: startDate.toUTC(), 
                                              to: endDate.toUTC())
        
        var parts: [String] = []
        
        if let years = components.year, years > 0 {
            parts.append("\(years)年")
        }
        
        if let months = components.month, months > 0 {
            parts.append("\(months)月")
        }
        
        if let days = components.day, days > 0 {
            parts.append("\(days)天")
        }
        
        if let hours = components.hour, hours > 0 {
            parts.append("\(hours)小時")
        }
        
        if let minutes = components.minute, minutes > 0 && parts.count < 2 {
            parts.append("\(minutes)分鐘")
        }
        
        return parts.isEmpty ? "0分鐘" : parts.joined(separator: "")
    }
}