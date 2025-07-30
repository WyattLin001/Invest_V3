//
//  SmartSearchService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/30.
//  智能搜尋服務 - 為交易記錄提供智能搜尋功能
//

import Foundation
import SwiftUI

/// 智能搜尋服務
/// 提供交易記錄的多條件智能搜尋功能
@MainActor
class SmartSearchService: ObservableObject {
    static let shared = SmartSearchService()
    
    @Published var searchResults: [TradingRecord] = []
    @Published var isSearching = false
    @Published var searchHistory: [String] = []
    @Published var suggestions: [SearchSuggestion] = []
    
    private let portfolioManager = ChatPortfolioManager.shared
    private let maxHistoryItems = 10
    private let userDefaults = UserDefaults.standard
    
    private init() {
        loadSearchHistory()
    }
    
    /// 執行智能搜尋
    func smartSearch(_ query: String, filters: SearchFilters = SearchFilters()) async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else {
            searchResults = []
            return
        }
        
        isSearching = true
        
        // 保存搜尋歷史
        addToSearchHistory(query)
        
        // 獲取所有交易記錄
        let allRecords = portfolioManager.tradingRecords
        
        // 執行搜尋
        let results = await performSearch(query: query, records: allRecords, filters: filters)
        
        searchResults = results
        isSearching = false
        
        print("🔍 [SmartSearch] 搜尋 '\(query)' 找到 \(results.count) 筆結果")
    }
    
    /// 獲取搜尋建議
    func generateSuggestions(for query: String) async {
        guard !query.isEmpty else {
            suggestions = []
            return
        }
        
        let allRecords = portfolioManager.tradingRecords
        var newSuggestions: [SearchSuggestion] = []
        
        // 1. 股票代號建議
        let symbols = Set(allRecords.map { $0.symbol })
        let matchingSymbols = symbols.filter { $0.localizedCaseInsensitiveContains(query) }
        
        for symbol in matchingSymbols.prefix(3) {
            let recordCount = allRecords.filter { $0.symbol == symbol }.count
            newSuggestions.append(SearchSuggestion(
                text: symbol,
                type: .symbol,
                description: "\(recordCount) 筆交易",
                matchCount: recordCount
            ))
        }
        
        // 2. 股票名稱建議
        let stockNames = Set(allRecords.map { $0.stockName })
        let matchingNames = stockNames.filter { $0.localizedCaseInsensitiveContains(query) }
        
        for name in matchingNames.prefix(3) {
            let recordCount = allRecords.filter { $0.stockName == name }.count
            newSuggestions.append(SearchSuggestion(
                text: name,
                type: .stockName,
                description: "\(recordCount) 筆交易",
                matchCount: recordCount
            ))
        }
        
        // 3. 數值範圍建議
        if let amount = Double(query) {
            let amountSuggestions = generateAmountSuggestions(amount: amount, records: allRecords)
            newSuggestions.append(contentsOf: amountSuggestions)
        }
        
        // 4. 日期建議
        let dateSuggestions = generateDateSuggestions(query: query, records: allRecords)
        newSuggestions.append(contentsOf: dateSuggestions)
        
        // 5. 類型建議
        if query.localizedCaseInsensitiveContains("買") || query.localizedCaseInsensitiveContains("buy") {
            let buyCount = allRecords.filter { $0.type == .buy }.count
            newSuggestions.append(SearchSuggestion(
                text: "買入交易",
                type: .tradingType,
                description: "\(buyCount) 筆買入",
                matchCount: buyCount
            ))
        }
        
        if query.localizedCaseInsensitiveContains("賣") || query.localizedCaseInsensitiveContains("sell") {
            let sellCount = allRecords.filter { $0.type == .sell }.count
            newSuggestions.append(SearchSuggestion(
                text: "賣出交易",
                type: .tradingType,
                description: "\(sellCount) 筆賣出",
                matchCount: sellCount
            ))
        }
        
        // 按相關性排序
        suggestions = newSuggestions.sorted { $0.matchCount > $1.matchCount }
    }
    
    /// 清除搜尋結果
    func clearResults() {
        searchResults = []
        suggestions = []
    }
    
    /// 清除搜尋歷史
    func clearSearchHistory() {
        searchHistory.removeAll()
        saveSearchHistory()
    }
    
    // MARK: - 私有方法
    
    private func performSearch(query: String, records: [TradingRecord], filters: SearchFilters) async -> [TradingRecord] {
        let lowercaseQuery = query.lowercased()
        
        return records.filter { record in
            // 應用篩選器
            if !filters.matches(record) {
                return false
            }
            
            // 多維度搜尋
            let symbolMatch = record.symbol.lowercased().contains(lowercaseQuery)
            let nameMatch = record.stockName.lowercased().contains(lowercaseQuery)
            let typeMatch = record.type.displayName.lowercased().contains(lowercaseQuery)
            let notesMatch = (record.notes?.lowercased().contains(lowercaseQuery) ?? false)
            
            // 數值搜尋
            let amountMatch = searchInAmount(query: query, record: record)
            
            // 日期搜尋
            let dateMatch = searchInDate(query: query, record: record)
            
            return symbolMatch || nameMatch || typeMatch || notesMatch || amountMatch || dateMatch
        }
        .sorted { $0.timestamp > $1.timestamp } // 按時間排序
    }
    
    private func searchInAmount(query: String, record: TradingRecord) -> Bool {
        // 嘗試解析查詢為數值
        guard let queryAmount = Double(query) else { return false }
        
        // 檢查是否在合理範圍內
        let tolerance = queryAmount * 0.1 // 10% 容忍度
        
        return abs(record.totalAmount - queryAmount) <= tolerance ||
               abs(record.shares - queryAmount) <= tolerance ||
               abs(record.price - queryAmount) <= tolerance
    }
    
    private func searchInDate(query: String, record: TradingRecord) -> Bool {
        let formatter = DateFormatter()
        
        // 嘗試多種日期格式
        let formats = ["yyyy-MM-dd", "MM-dd", "yyyy/MM/dd", "MM/dd", "dd"]
        
        for format in formats {
            formatter.dateFormat = format
            if let queryDate = formatter.date(from: query) {
                let calendar = Calendar.current
                return calendar.isDate(record.timestamp, inSameDayAs: queryDate)
            }
        }
        
        // 文字日期搜尋
        let dateString = DateFormatter.displayDate.string(from: record.timestamp)
        return dateString.lowercased().contains(query.lowercased())
    }
    
    private func generateAmountSuggestions(amount: Double, records: [TradingRecord]) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        // 大於該金額的交易
        let greaterCount = records.filter { $0.totalAmount > amount }.count
        if greaterCount > 0 {
            suggestions.append(SearchSuggestion(
                text: "大於 $\(Int(amount))",
                type: .amount,
                description: "\(greaterCount) 筆交易",
                matchCount: greaterCount
            ))
        }
        
        // 小於該金額的交易
        let lessCount = records.filter { $0.totalAmount < amount }.count
        if lessCount > 0 {
            suggestions.append(SearchSuggestion(
                text: "小於 $\(Int(amount))",
                type: .amount,
                description: "\(lessCount) 筆交易",
                matchCount: lessCount
            ))
        }
        
        return suggestions
    }
    
    private func generateDateSuggestions(query: String, records: [TradingRecord]) -> [SearchSuggestion] {
        var suggestions: [SearchSuggestion] = []
        
        let calendar = Calendar.current
        let now = Date()
        
        // 今天
        if query.localizedCaseInsensitiveContains("今") || query.localizedCaseInsensitiveContains("today") {
            let todayCount = records.filter { calendar.isDateInToday($0.timestamp) }.count
            if todayCount > 0 {
                suggestions.append(SearchSuggestion(
                    text: "今天的交易",
                    type: .date,
                    description: "\(todayCount) 筆交易",
                    matchCount: todayCount
                ))
            }
        }
        
        // 本週
        if query.localizedCaseInsensitiveContains("週") || query.localizedCaseInsensitiveContains("week") {
            let weekCount = records.filter { calendar.isDate($0.timestamp, equalTo: now, toGranularity: .weekOfYear) }.count
            if weekCount > 0 {
                suggestions.append(SearchSuggestion(
                    text: "本週的交易",
                    type: .date,
                    description: "\(weekCount) 筆交易",
                    matchCount: weekCount
                ))
            }
        }
        
        // 本月
        if query.localizedCaseInsensitiveContains("月") || query.localizedCaseInsensitiveContains("month") {
            let monthCount = records.filter { calendar.isDate($0.timestamp, equalTo: now, toGranularity: .month) }.count
            if monthCount > 0 {
                suggestions.append(SearchSuggestion(
                    text: "本月的交易",
                    type: .date,
                    description: "\(monthCount) 筆交易",
                    matchCount: monthCount
                ))
            }
        }
        
        return suggestions
    }
    
    private func addToSearchHistory(_ query: String) {
        let trimmedQuery = query.trimmingCharacters(in: .whitespaces)
        guard !trimmedQuery.isEmpty else { return }
        
        // 移除重複項目
        searchHistory.removeAll { $0 == trimmedQuery }
        
        // 添加到開頭
        searchHistory.insert(trimmedQuery, at: 0)
        
        // 限制數量
        if searchHistory.count > maxHistoryItems {
            searchHistory.removeLast()
        }
        
        saveSearchHistory()
    }
    
    private func saveSearchHistory() {
        userDefaults.set(searchHistory, forKey: "SmartSearchHistory")
    }
    
    private func loadSearchHistory() {
        searchHistory = userDefaults.stringArray(forKey: "SmartSearchHistory") ?? []
    }
}

// MARK: - 數據模型

struct SearchSuggestion: Identifiable {
    let id = UUID()
    let text: String
    let type: SuggestionType
    let description: String
    let matchCount: Int
}

enum SuggestionType {
    case symbol
    case stockName
    case tradingType
    case amount
    case date
    case general
    
    var icon: String {
        switch self {
        case .symbol: return "chart.line.uptrend.xyaxis"
        case .stockName: return "building.2"
        case .tradingType: return "arrow.left.arrow.right"
        case .amount: return "dollarsign.circle"
        case .date: return "calendar"
        case .general: return "magnifyingglass"
        }
    }
    
    var color: Color {
        switch self {
        case .symbol: return .blue
        case .stockName: return .green
        case .tradingType: return .orange
        case .amount: return .purple
        case .date: return .pink
        case .general: return .gray
        }
    }
}

struct SearchFilters {
    var tradingType: TradingType?
    var dateRange: TradingRecordFilter.DateRange?
    var amountRange: ClosedRange<Double>?
    var symbols: Set<String> = []
    
    func matches(_ record: TradingRecord) -> Bool {
        // 交易類型篩選
        if let type = tradingType, record.type != type {
            return false
        }
        
        // 日期範圍篩選
        if let range = dateRange {
            let filter = TradingRecordFilter(dateRange: range)
            if !filter.matches(record) {
                return false
            }
        }
        
        // 金額範圍篩選
        if let range = amountRange, !range.contains(record.totalAmount) {
            return false
        }
        
        // 股票代號篩選
        if !symbols.isEmpty && !symbols.contains(record.symbol) {
            return false
        }
        
        return true
    }
}

// MARK: - SwiftUI 組件

struct SmartSearchBar: View {
    @StateObject private var searchService = SmartSearchService.shared
    @State private var searchText = ""
    @State private var showingSuggestions = false
    @FocusState private var isSearchFocused: Bool
    
    let onResultsChanged: ([TradingRecord]) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 搜尋框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                TextField("搜尋交易記錄...", text: $searchText)
                    .focused($isSearchFocused)
                    .onSubmit {
                        performSearch()
                    }
                    .onChange(of: searchText) { newValue in
                        if newValue.isEmpty {
                            searchService.clearResults()
                            onResultsChanged([])
                        } else {
                            Task {
                                await searchService.generateSuggestions(for: newValue)
                            }
                        }
                        showingSuggestions = !newValue.isEmpty
                    }
                
                if searchService.isSearching {
                    ProgressView()
                        .scaleEffect(0.8)
                } else if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        searchService.clearResults()
                        onResultsChanged([])
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // 搜尋建議
            if showingSuggestions && !searchService.suggestions.isEmpty {
                suggestionsView
            }
            
            // 搜尋歷史
            if searchText.isEmpty && !searchService.searchHistory.isEmpty {
                searchHistoryView
            }
        }
    }
    
    private var suggestionsView: some View {
        VStack(spacing: 0) {
            ForEach(searchService.suggestions) { suggestion in
                Button(action: {
                    searchText = suggestion.text
                    performSearch()
                    showingSuggestions = false
                }) {
                    HStack {
                        Image(systemName: suggestion.type.icon)
                            .foregroundColor(suggestion.type.color)
                            .frame(width: 20)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(suggestion.text)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                            
                            Text(suggestion.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                        
                        Image(systemName: "arrow.up.left")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                }
                .buttonStyle(PlainButtonStyle())
                
                if suggestion.id != searchService.suggestions.last?.id {
                    Divider()
                }
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .padding(.top, 4)
    }
    
    private var searchHistoryView: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("最近搜尋")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("清除") {
                    searchService.clearSearchHistory()
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 100))
            ], spacing: 8) {
                ForEach(searchService.searchHistory, id: \.self) { history in
                    Button(action: {
                        searchText = history
                        performSearch()
                    }) {
                        Text(history)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color(.systemGray5))
                            .cornerRadius(16)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.top, 8)
    }
    
    private func performSearch() {
        isSearchFocused = false
        showingSuggestions = false
        
        Task {
            await searchService.smartSearch(searchText)
            onResultsChanged(searchService.searchResults)
        }
    }
}

#Preview {
    SmartSearchBar { results in
        print("搜尋結果: \(results.count) 筆")
    }
    .padding()
}