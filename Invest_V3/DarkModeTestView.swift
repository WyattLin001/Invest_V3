//
//  DarkModeTestView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  深色模式測試視圖 - 用於驗證深色模式實現效果

import SwiftUI

/// 深色模式測試視圖 - 用於開發和調試
struct DarkModeTestView: View {
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 主題控制區域
                    themeControlSection
                    
                    // 顏色測試區域
                    colorTestSection
                    
                    // 圖表測試區域
                    chartTestSection
                    
                    // 投資面板測試
                    investmentPanelTestSection
                    
                    // 系統顏色測試
                    systemColorTestSection
                }
                .padding()
            }
            .adaptiveBackground()
            .navigationTitle("深色模式測試")
            .navigationBarTitleDisplayMode(.large)
        }
    }
    
    // MARK: - 主題控制區域
    private var themeControlSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("主題控制")
                .font(.headline)
                .adaptiveTextColor()
            
            HStack(spacing: 12) {
                ForEach(ThemeManager.ThemeMode.allCases) { mode in
                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            themeManager.setTheme(mode)
                        }
                    }) {
                        VStack(spacing: 4) {
                            Image(systemName: mode.iconName)
                                .font(.title2)
                            Text(mode.displayName)
                                .font(.caption)
                        }
                        .foregroundColor(themeManager.currentMode == mode ? .white : .systemLabel)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(themeManager.currentMode == mode ? Color.brandGreen : Color.surfaceSecondary)
                        )
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            
            Text("當前模式: \(themeManager.currentMode.displayName)")
                .font(.caption)
                .adaptiveTextColor(primary: false)
            
            Text("是否深色: \(themeManager.isDarkMode ? "是" : "否")")
                .font(.caption)
                .adaptiveTextColor(primary: false)
        }
        .brandCardStyle()
    }
    
    // MARK: - 顏色測試區域
    private var colorTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("語義化顏色測試")
                .font(.headline)
                .adaptiveTextColor()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                colorSample("Primary", Color.surfacePrimary)
                colorSample("Secondary", Color.surfaceSecondary)
                colorSample("Tertiary", Color.surfaceTertiary)
                colorSample("Brand Green", Color.brandGreen)
                colorSample("Brand Orange", Color.brandOrange)
                colorSample("Brand Blue", Color.brandBlue)
                colorSample("Success", Color.success)
                colorSample("Danger", Color.danger)
                colorSample("Warning", Color.warning)
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 圖表測試區域
    private var chartTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("股票顏色系統測試")
                .font(.headline)
                .adaptiveTextColor()
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(["2330", "0050", "2454", "2317", "2881", "2882", "2886", "2891"], id: \.self) { symbol in
                    VStack(spacing: 4) {
                        Circle()
                            .fill(StockColorPalette.colorForStock(symbol: symbol))
                            .frame(width: 30, height: 30)
                        Text(symbol)
                            .font(.caption2)
                            .adaptiveTextColor()
                    }
                }
            }
            
            Text("這些顏色會根據深色/淺色模式自動調整對比度")
                .font(.caption)
                .adaptiveTextColor(primary: false)
        }
        .brandCardStyle()
    }
    
    // MARK: - 投資面板測試
    private var investmentPanelTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("投資面板樣式測試")
                .font(.headline)
                .adaptiveTextColor()
            
            VStack(spacing: 8) {
                // 模擬股票項目
                ForEach(0..<3, id: \.self) { index in
                    let symbols = ["2330 台積電", "0050 台灣50", "2454 聯發科"]
                    let values = ["$50,000", "$30,000", "$20,000"]
                    let percentages = ["50%", "30%", "20%"]
                    
                    HStack {
                        Circle()
                            .fill(StockColorPalette.colorForStock(symbol: String(symbols[index].prefix(4))))
                            .frame(width: 12, height: 12)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(symbols[index])
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .adaptiveTextColor()
                        }
                        
                        Spacer()
                        
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(values[index])
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .adaptiveTextColor()
                            Text(percentages[index])
                                .font(.caption)
                                .adaptiveTextColor(primary: false)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.surfaceSecondary)
                    .cornerRadius(8)
                }
            }
        }
        .investmentPanelStyle()
    }
    
    // MARK: - 系統顏色測試
    private var systemColorTestSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("系統顏色測試")
                .font(.headline)
                .adaptiveTextColor()
            
            VStack(spacing: 8) {
                HStack {
                    Text("System Background")
                        .adaptiveTextColor()
                    Spacer()
                    Rectangle()
                        .fill(Color.systemBackground)
                        .frame(width: 30, height: 20)
                        .border(Color.systemSeparator)
                }
                
                HStack {
                    Text("Secondary Background")
                        .adaptiveTextColor()
                    Spacer()
                    Rectangle()
                        .fill(Color.systemSecondaryBackground)
                        .frame(width: 30, height: 20)
                        .border(Color.systemSeparator)
                }
                
                HStack {
                    Text("Label")
                        .adaptiveTextColor()
                    Spacer()
                    Rectangle()
                        .fill(Color.systemLabel)
                        .frame(width: 30, height: 20)
                        .border(Color.systemSeparator)
                }
                
                HStack {
                    Text("Secondary Label")
                        .adaptiveTextColor()
                    Spacer()
                    Rectangle()
                        .fill(Color.systemSecondaryLabel)
                        .frame(width: 30, height: 20)
                        .border(Color.systemSeparator)
                }
            }
        }
        .brandCardStyle()
    }
    
    // MARK: - 輔助方法
    private func colorSample(_ name: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Rectangle()
                .fill(color)
                .frame(height: 40)
                .cornerRadius(4)
            Text(name)
                .font(.caption2)
                .adaptiveTextColor()
        }
    }
}

// MARK: - 預覽
#Preview {
    DarkModeTestView()
        .environmentObject(ThemeManager.shared)
}

// MARK: - Debug 輔助
#if DEBUG
extension DarkModeTestView {
    /// 顯示調試信息
    private var debugInfo: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("調試信息")
                .font(.headline)
                .adaptiveTextColor()
            
            Text(themeManager.getDebugInfo())
                .font(.caption)
                .adaptiveTextColor(primary: false)
                .monospaced()
        }
        .brandCardStyle()
    }
}
#endif