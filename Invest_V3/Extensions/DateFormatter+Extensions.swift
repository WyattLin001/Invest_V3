//
//  DateFormatter+Extensions.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/27.
//  Shared DateFormatter extensions for the entire project
//

import Foundation

extension DateFormatter {
    /// Time-only formatter (HH:mm format)
    static let timeOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter
    }()
    
    /// Full date formatter (yyyy-MM-dd format)
    static let dateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()
    
    /// Date and time formatter (yyyy-MM-dd HH:mm format)
    static let dateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
    
    /// Display date formatter (MM/dd format)
    static let displayDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter
    }()
    
    /// Supabase ISO8601 formatter
    static let supabaseISO8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"
        formatter.timeZone = TimeZone(abbreviation: "UTC")
        return formatter
    }()
}

extension Date {
    /// Convert Date to Supabase-compatible string format
    func toSupabaseString() -> String {
        return DateFormatter.supabaseISO8601.string(from: self)
    }
}