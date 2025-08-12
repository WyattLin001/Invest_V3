//
//  CustomTimeRangePicker.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/11.
//  自定義時間範圍選擇器 - 支援預設和自定義時間範圍
//

import SwiftUI

// MARK: - 自定義時間範圍
struct CustomTimeRange: Equatable {
    let startDate: Date
    let endDate: Date
    let displayName: String
    
    init(startDate: Date, endDate: Date, displayName: String) {
        self.startDate = startDate
        self.endDate = endDate
        self.displayName = displayName
    }
    
    /// 從預設時間範圍創建
    init(from standardRange: PerformanceTimeRange, endDate: Date = Date()) {
        self.endDate = endDate
        self.displayName = standardRange.rawValue
        
        let calendar = Calendar.current
        switch standardRange {
        case .week:
            self.startDate = calendar.date(byAdding: .day, value: -7, to: endDate) ?? endDate
        case .month:
            self.startDate = calendar.date(byAdding: .month, value: -1, to: endDate) ?? endDate
        case .quarter:
            self.startDate = calendar.date(byAdding: .month, value: -3, to: endDate) ?? endDate
        case .year:
            self.startDate = calendar.date(byAdding: .year, value: -1, to: endDate) ?? endDate
        case .all:
            self.startDate = calendar.date(byAdding: .year, value: -2, to: endDate) ?? endDate
        }
    }
    
    /// 天數差
    var dayDifference: Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
    
    /// 是否為自定義範圍
    var isCustomRange: Bool {
        return !PerformanceTimeRange.allCases.contains { range in
            let standardRange = CustomTimeRange(from: range, endDate: endDate)
            return abs(startDate.timeIntervalSince(standardRange.startDate)) < 86400 // 1天誤差範圍
        }
    }
}

// MARK: - 自定義時間範圍選擇器
struct CustomTimeRangePicker: View {
    @Binding var selectedRange: CustomTimeRange
    @State private var showingCustomPicker = false
    @State private var tempStartDate: Date
    @State private var tempEndDate: Date
    
    // 預設時間範圍選項
    private let standardRanges: [PerformanceTimeRange] = [.week, .month, .quarter, .year, .all]
    
    init(selectedRange: Binding<CustomTimeRange>) {
        self._selectedRange = selectedRange
        self._tempStartDate = State(initialValue: selectedRange.wrappedValue.startDate)
        self._tempEndDate = State(initialValue: selectedRange.wrappedValue.endDate)
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // 預設時間範圍按鈕
            standardRangeButtons
            
            // 自定義時間範圍按鈕
            customRangeButton
            
            // 當前選擇的範圍顯示
            currentRangeDisplay
        }
        .sheet(isPresented: $showingCustomPicker) {
            customRangePickerSheet
        }
    }
    
    // MARK: - 預設時間範圍按鈕
    private var standardRangeButtons: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(standardRanges, id: \.self) { range in
                    TimeRangeButton(
                        title: range.rawValue,
                        isSelected: isStandardRangeSelected(range),
                        action: {
                            selectStandardRange(range)
                        }
                    )
                }
            }
            .padding(.horizontal, 16)
        }
    }
    
    // MARK: - 自定義時間範圍按鈕
    private var customRangeButton: some View {
        TimeRangeButton(
            title: "自定義",
            icon: "calendar.badge.plus",
            isSelected: selectedRange.isCustomRange,
            action: {
                showingCustomPicker = true
            }
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - 當前範圍顯示
    private var currentRangeDisplay: some View {
        VStack(spacing: 4) {
            Text("當前選擇")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Text(selectedRange.displayName)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
            
            HStack {
                Text(formatDate(selectedRange.startDate))
                Text("至")
                    .foregroundColor(.secondary)
                Text(formatDate(selectedRange.endDate))
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(getCurrentRangeBackgroundColor())
        )
        .padding(.horizontal, 16)
    }
    
    // MARK: - 自定義範圍選擇器視圖
    private var customRangePickerSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("選擇自定義時間範圍")
                    .font(.title3)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 16) {
                    // 開始日期選擇
                    VStack(alignment: .leading, spacing: 8) {
                        Text("開始日期")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        DatePicker(
                            "開始日期",
                            selection: $tempStartDate,
                            in: getDateRange(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }
                    
                    // 結束日期選擇
                    VStack(alignment: .leading, spacing: 8) {
                        Text("結束日期")
                            .font(.headline)
                            .fontWeight(.medium)
                        
                        DatePicker(
                            "結束日期",
                            selection: $tempEndDate,
                            in: tempStartDate...Date(),
                            displayedComponents: .date
                        )
                        .datePickerStyle(.compact)
                        .labelsHidden()
                    }
                }
                .padding(.horizontal, 20)
                
                // 範圍預覽
                rangePreview
                
                Spacer()
            }
            .navigationTitle("自定義範圍")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        resetTempDates()
                        showingCustomPicker = false
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("確認") {
                        applyCustomRange()
                        showingCustomPicker = false
                    }
                    .disabled(!isValidDateRange)
                }
            }
            .onChange(of: tempStartDate) { _, _ in
                validateAndAdjustDates()
            }
        }
    }
    
    // MARK: - 範圍預覽
    private var rangePreview: some View {
        VStack(spacing: 8) {
            Text("預覽")
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(spacing: 4) {
                Text("\(formatDateRange(from: tempStartDate, to: tempEndDate))")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text("共 \(getDaysBetween(tempStartDate, tempEndDate)) 天")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(getPreviewBackgroundColor())
        )
        .padding(.horizontal, 20)
    }
    
    // MARK: - 私有方法
    
    private func isStandardRangeSelected(_ range: PerformanceTimeRange) -> Bool {
        let standardRange = CustomTimeRange(from: range, endDate: selectedRange.endDate)
        return abs(selectedRange.startDate.timeIntervalSince(standardRange.startDate)) < 86400 && 
               abs(selectedRange.endDate.timeIntervalSince(standardRange.endDate)) < 86400
    }
    
    private func selectStandardRange(_ range: PerformanceTimeRange) {
        selectedRange = CustomTimeRange(from: range)
    }
    
    private func resetTempDates() {
        tempStartDate = selectedRange.startDate
        tempEndDate = selectedRange.endDate
    }
    
    private func applyCustomRange() {
        let dayDifference = getDaysBetween(tempStartDate, tempEndDate)
        let displayName = "自定義 (\(dayDifference) 天)"
        
        selectedRange = CustomTimeRange(
            startDate: tempStartDate,
            endDate: tempEndDate,
            displayName: displayName
        )
    }
    
    private var isValidDateRange: Bool {
        return tempStartDate < tempEndDate
    }
    
    private func validateAndAdjustDates() {
        // 如果開始日期晚於結束日期，調整結束日期
        if tempStartDate >= tempEndDate {
            tempEndDate = Calendar.current.date(byAdding: .day, value: 1, to: tempStartDate) ?? tempStartDate
        }
    }
    
    private func getDateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let twoYearsAgo = calendar.date(byAdding: .year, value: -2, to: Date()) ?? Date()
        return twoYearsAgo...Date()
    }
    
    private func getDaysBetween(_ startDate: Date, _ endDate: Date) -> Int {
        Calendar.current.dateComponents([.day], from: startDate, to: endDate).day ?? 0
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd"
        return formatter.string(from: date)
    }
    
    private func formatDateRange(from startDate: Date, to endDate: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy/MM/dd"
        return "\(formatter.string(from: startDate)) - \(formatter.string(from: endDate))"
    }
}

// MARK: - 時間範圍按鈕
private struct TimeRangeButton: View {
    let title: String
    let icon: String?
    let isSelected: Bool
    let action: () -> Void
    
    init(title: String, icon: String? = nil, isSelected: Bool, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.caption)
                }
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .foregroundColor(isSelected ? .white : .primary)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? getDynamicBlue() : getButtonBackgroundColor())
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 預覽
#Preview("時間範圍選擇器") {
    struct PreviewContainer: View {
        @State private var selectedRange = CustomTimeRange(from: .month)
        
        var body: some View {
            VStack(spacing: 20) {
                Text("自定義時間範圍選擇器")
                    .font(.title2)
                    .fontWeight(.bold)
                
                CustomTimeRangePicker(selectedRange: $selectedRange)
                
                Spacer()
                
                // 顯示選擇結果
                VStack(alignment: .leading, spacing: 8) {
                    Text("選擇結果：")
                        .font(.headline)
                    
                    Text("範圍：\(selectedRange.displayName)")
                    Text("開始：\(selectedRange.startDate.formatted(date: .abbreviated, time: .omitted))")
                    Text("結束：\(selectedRange.endDate.formatted(date: .abbreviated, time: .omitted))")
                    Text("天數：\(selectedRange.dayDifference)")
                    Text("自定義：\(selectedRange.isCustomRange ? "是" : "否")")
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(getPreviewResultBackgroundColor())
                )
            }
            .padding()
        }
    }
    
    return PreviewContainer()
}

// MARK: - 深色模式支援方法

/// 獲取當前範圍背景顏色
private func getCurrentRangeBackgroundColor() -> Color {
    return Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark 
            ? UIColor.systemGray5.withAlphaComponent(0.3)
            : UIColor.systemGray6.withAlphaComponent(0.5)
    })
}

/// 獲取預覽背景顏色
private func getPreviewBackgroundColor() -> Color {
    return Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark 
            ? UIColor.systemGray5.withAlphaComponent(0.2)
            : UIColor.systemGray6.withAlphaComponent(0.3)
    })
}

/// 獲取按鈕背景顏色
private func getButtonBackgroundColor() -> Color {
    return Color(UIColor { traitCollection in
        return traitCollection.userInterfaceStyle == .dark 
            ? UIColor.systemGray4
            : UIColor.systemGray5
    })
}

/// 獲取動態藍色
private func getDynamicBlue() -> Color {
    return Color.blue
}

/// 獲取預覽結果背景顏色
private func getPreviewResultBackgroundColor() -> Color {
    return getCurrentRangeBackgroundColor()
}