//
//  TournamentTabBarView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//  錦標賽標籤導航組件 - 可滾動的標籤欄，包含精選功能
//

import SwiftUI

// MARK: - 錦標賽標籤導航組件

/// 錦標賽標籤導航欄
/// 提供水平滾動的標籤選擇，包含精選錦標賽快速入口
struct TournamentTabBarView: View {
    @Binding var selectedFilter: TournamentFilter
    @Namespace private var tabBarAnimation
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TournamentFilter.allCases) { filter in
                    TournamentTabItem(
                        filter: filter,
                        isSelected: selectedFilter == filter,
                        animation: tabBarAnimation
                    ) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            selectedFilter = filter
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
        }
        .background(.gray.opacity(0.05))
        .overlay(
            // 底部分隔線
            Rectangle()
                .fill(.gray.opacity(0.3))
                .frame(height: 0.5),
            alignment: .bottom
        )
    }
}

// MARK: - 標籤項目組件

/// 單個標籤項目
private struct TournamentTabItem: View {
    let filter: TournamentFilter
    let isSelected: Bool
    let animation: Namespace.ID
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                // 圖標
                Image(systemName: filter.iconName)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(iconColor)
                
                // 文字
                Text(filter.displayName)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .medium))
                    .foregroundColor(textColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Group {
                    if isSelected {
                        backgroundColorSelected
                            .clipShape(RoundedRectangle(cornerRadius: 20))
                            .matchedGeometryEffect(id: "selectedTab", in: animation)
                    } else {
                        RoundedRectangle(cornerRadius: 20)
                            .fill(backgroundColorNormal)
                    }
                }
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(borderColor, lineWidth: isSelected ? 1.5 : 0.5)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 顏色計算
    
    private var iconColor: Color {
        if isSelected {
            if filter == .featured {
                return .white
            } else {
                return filter.accentColor
            }
        } else {
            return .secondary
        }
    }
    
    private var textColor: Color {
        if isSelected {
            if filter == .featured {
                return .white
            } else {
                return .primary
            }
        } else {
            return .secondary
        }
    }
    
    @ViewBuilder
    private var backgroundColorSelected: some View {
        if filter == .featured {
            LinearGradient(
                colors: [.orange, .red],
                startPoint: .leading,
                endPoint: .trailing
            )
        } else {
            Rectangle()
                .fill(filter.accentColor.opacity(0.1))
        }
    }
    
    private var backgroundColorNormal: Color {
        return .gray.opacity(0.1)
    }
    
    private var borderColor: Color {
        if isSelected {
            return filter.accentColor
        } else {
            return .gray.opacity(0.3)
        }
    }
}

// MARK: - 精選標籤漸變背景

/// 精選標籤的漸變背景修飾器
private struct FeaturedGradientBackground: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color.orange,
                Color.red.opacity(0.8)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 標籤欄容器

/// 錦標賽標籤欄容器，包含陰影和背景
struct TournamentTabBarContainer: View {
    @Binding var selectedFilter: TournamentFilter
    
    var body: some View {
        VStack(spacing: 0) {
            TournamentTabBarView(selectedFilter: $selectedFilter)
        }
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(.gray.opacity(0.05))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
        )
    }
}

// MARK: - Preview

/*
#Preview("錦標賽標籤導航") {
    VStack {
        TournamentTabBarContainer(selectedFilter: .constant(.featured))
        
        Spacer()
        
        Text("錦標賽內容區域")
            .font(.title2)
            .foregroundColor(.secondary)
        
        Spacer()
    }
    .background(.gray.opacity(0.05))
}
*/

/*
#Preview("標籤狀態") {
    ScrollView {
        VStack(spacing: 16) {
            Text("錦標賽標籤狀態展示")
                .font(.headline)
            
            ForEach(TournamentFilter.allCases) { filter in
                HStack {
                    Text(filter.displayName)
                        .frame(width: 100, alignment: .leading)
                    
                    TournamentTabItem(
                        filter: filter,
                        isSelected: false,
                        animation: Namespace().wrappedValue
                    ) { }
                    
                    TournamentTabItem(
                        filter: filter,
                        isSelected: true,
                        animation: Namespace().wrappedValue
                    ) { }
                }
            }
        }
        .padding()
    }
}
*/