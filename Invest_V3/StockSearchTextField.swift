import SwiftUI
import Foundation

/// 台股智能搜尋輸入框組件
/// 提供實時搜尋建議和鍵盤導航功能
struct StockSearchTextField: View {
    @Binding var text: String
    let placeholder: String
    let onStockSelected: ((CompleteTaiwanStockItem) -> Void)?
    
    // 搜尋狀態
    @State private var suggestions: [CompleteTaiwanStockItem] = []
    @State private var isSearching = false
    @State private var showSuggestions = false
    @State private var selectedIndex = -1
    @State private var searchError: String?
    
    // 防抖動相關
    @State private var debounceTimer: Timer?
    private let debounceDelay: TimeInterval = 0.25 // 250ms
    
    // UI 狀態
    @FocusState private var isTextFieldFocused: Bool
    
    init(
        text: Binding<String>,
        placeholder: String = "例如：2330 或 台積電",
        onStockSelected: ((CompleteTaiwanStockItem) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onStockSelected = onStockSelected
    }
    
    var body: some View {
        ZStack(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 0) {
                // 輸入框
                HStack {
                    TextField(placeholder, text: $text)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)
                        .autocapitalization(.allCharacters)
                        .accessibilityLabel("股票搜尋輸入框")
                        .accessibilityHint("輸入股票代號或公司名稱進行搜尋")
                        .onChange(of: text) { newValue in
                            handleTextChange(newValue)
                        }
                        .onSubmit {
                            selectCurrentSuggestion()
                        }
                        // 新增鍵盤導航支持
                        .onKeyPress(.upArrow) {
                            if showSuggestions && !suggestions.isEmpty {
                                selectedIndex = max(selectedIndex - 1, -1)
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.downArrow) {
                            if showSuggestions && !suggestions.isEmpty {
                                selectedIndex = min(selectedIndex + 1, suggestions.count - 1)
                                return .handled
                            }
                            return .ignored
                        }
                        .onKeyPress(.escape) {
                            showSuggestions = false
                            isTextFieldFocused = false
                            return .handled
                        }
                    
                    // 清除按鈕和搜尋指示器
                    HStack(spacing: 4) {
                        if isSearching {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                        
                        if !text.isEmpty {
                            Button(action: {
                                text = ""
                                suggestions = []
                                showSuggestions = false
                                searchError = nil
                            }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.gray)
                                    .scaleEffect(0.8)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.trailing, 8)
                }
                
                // 保留空間給建議列表，避免佈局跳動
                if showSuggestions && isTextFieldFocused {
                    Spacer()
                        .frame(height: min(CGFloat(suggestions.count * 60), 200))
                }
            }
            
            // 建議列表 - 使用獨立的 ZStack 層
            if showSuggestions && isTextFieldFocused {
                VStack(spacing: 0) {
                    // 佔位符，對齊到輸入框下方
                    Spacer()
                        .frame(height: 44) // TextField 的大約高度
                    
                    suggestionsList
                        .zIndex(1000) // 高 z-index 確保在最上層
                        .animation(.easeInOut(duration: 0.2), value: suggestions)
                }
            }
        }
        .onTapGesture {
            isTextFieldFocused = true
        }
    }
    
    // MARK: - 建議列表視圖
    private var suggestionsList: some View {
        VStack(spacing: 0) {
            if searchError != nil {
                // 錯誤狀態
                errorView
            } else if suggestions.isEmpty && !text.trimmingCharacters(in: .whitespaces).isEmpty {
                // 無結果狀態
                noResultsView
            } else {
                // 建議列表
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(suggestions.enumerated()), id: \.element.code) { index, stock in
                            suggestionRow(stock: stock, index: index)
                                .onTapGesture {
                                    selectSuggestion(at: index)
                                }
                        }
                    }
                }
                .frame(maxHeight: 200)
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.systemGray4), lineWidth: 0.5)
        )
        .padding(.top, 4)
    }
    
    // MARK: - 建議項目行
    private func suggestionRow(stock: CompleteTaiwanStockItem, index: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                // 股票代號（高亮匹配部分）
                Text(highlightedText(stock.code, searchTerm: text))
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                
                // 公司名稱（高亮匹配部分）
                Text(highlightedText(stock.name, searchTerm: text))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // 市場標識和股票代號
            VStack(alignment: .trailing, spacing: 2) {
                Text(stock.market)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stock.market == "上市" ? Color.blue.opacity(0.1) : Color.orange.opacity(0.1))
                    .foregroundColor(stock.market == "上市" ? .blue : .orange)
                    .cornerRadius(3)
                
                Text(stock.code)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            selectedIndex == index ? Color.green.opacity(0.1) : Color.clear
        )
        .overlay(
            Rectangle()
                .fill(Color(.separator))
                .frame(height: 0.5),
            alignment: .bottom
        )
        // 無障礙功能
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(stock.code) \(stock.name)")
        .accessibilityHint("點擊選擇此股票")
        .accessibilityAddTraits(selectedIndex == index ? .isSelected : [])
        // 視覺回饋
        .scaleEffect(selectedIndex == index ? 1.02 : 1.0)
        .animation(.easeInOut(duration: 0.1), value: selectedIndex)
    }
    
    // MARK: - 錯誤視圖
    private var errorView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundColor(.orange)
            Text(searchError ?? "搜尋失敗")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding()
    }
    
    // MARK: - 無結果視圖
    private var noResultsView: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text("找不到相關股票")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text("試試輸入：2330、台積電、0050、元大")
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
    
    // MARK: - 搜尋邏輯
    private func handleTextChange(_ newValue: String) {
        selectedIndex = -1
        
        // 清除之前的定時器
        debounceTimer?.invalidate()
        
        let trimmedValue = newValue.trimmingCharacters(in: .whitespaces)
        
        if trimmedValue.isEmpty {
            suggestions = []
            showSuggestions = false
            searchError = nil
            return
        }
        
        // 設置防抖動定時器
        debounceTimer = Timer.scheduledTimer(withTimeInterval: debounceDelay, repeats: false) { _ in
            Task {
                await performSearch(query: trimmedValue)
            }
        }
    }
    
    private func performSearch(query: String) async {
        await MainActor.run {
            isSearching = true
            searchError = nil
        }
        
        do {
            let searchResponse = try await TradingAPIService.shared.searchTaiwanStocks(
                query: query,
                limit: 20
            )
            
            await MainActor.run {
                self.suggestions = searchResponse.stocks
                self.showSuggestions = true
                self.isSearching = false
                self.selectedIndex = -1
            }
            
        } catch {
            await MainActor.run {
                self.suggestions = []
                self.showSuggestions = true
                self.isSearching = false
                
                if let tradingError = error as? TradingAPIError {
                    self.searchError = tradingError.localizedDescription
                } else {
                    self.searchError = "網路連線錯誤"
                }
            }
        }
    }
    
    // MARK: - 選擇邏輯
    private func selectSuggestion(at index: Int) {
        guard index >= 0 && index < suggestions.count else { return }
        
        let selectedStock = suggestions[index]
        
        // 優化用戶體驗：顯示完整的股票代號和名稱
        text = "\(selectedStock.code) \(selectedStock.name)"
        showSuggestions = false
        
        // 保持焦點讓用戶可以繼續編輯（可選）
        // isTextFieldFocused = false
        
        // 調用回調
        onStockSelected?(selectedStock)
    }
    
    private func selectCurrentSuggestion() {
        if selectedIndex >= 0 && selectedIndex < suggestions.count {
            selectSuggestion(at: selectedIndex)
        } else if !suggestions.isEmpty {
            selectSuggestion(at: 0)
        }
    }
    
    // MARK: - 高亮文字
    private func highlightedText(_ fullText: String, searchTerm: String) -> AttributedString {
        var attributedString = AttributedString(fullText)
        
        if !searchTerm.isEmpty {
            let ranges = fullText.ranges(of: searchTerm, options: .caseInsensitive)
            for range in ranges {
                let startIndex = attributedString.index(attributedString.startIndex, offsetByCharacters: fullText.distance(from: fullText.startIndex, to: range.lowerBound))
                let endIndex = attributedString.index(startIndex, offsetByCharacters: searchTerm.count)
                
                attributedString[startIndex..<endIndex].backgroundColor = .yellow.opacity(0.3)
                attributedString[startIndex..<endIndex].font = .headline.bold()
            }
        }
        
        return attributedString
    }
}

// MARK: - String Extension for Range Finding
extension String {
    func ranges(of searchString: String, options: String.CompareOptions = []) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = self.startIndex
        
        while searchStartIndex < self.endIndex,
              let range = self.range(of: searchString, options: options, range: searchStartIndex..<self.endIndex) {
            ranges.append(range)
            searchStartIndex = range.upperBound
        }
        
        return ranges
    }
}

// MARK: - Preview
#Preview {
    VStack {
        Text("台股搜尋測試")
            .font(.title)
            .padding()
        
        StockSearchTextField(
            text: .constant(""),
            placeholder: "搜尋股票代號或公司名稱"
        ) { selectedStock in
            print("選擇的股票: \(selectedStock.code) - \(selectedStock.name)")
        }
        .padding()
        
        Spacer()
    }
}