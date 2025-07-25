//
//  TournamentSelectionView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  錦標賽選擇視圖 - 多類型錦標賽選擇與管理

import SwiftUI

struct TournamentSelectionView: View {
    @Binding var selectedTournament: Tournament?
    @Binding var showingDetail: Bool
    @State private var tournaments = Tournament.sampleData
    @State private var selectedType: TournamentType? = nil
    @State private var searchText = ""
    @State private var isRefreshing = false
    
    var body: some View {
        ScrollView {
            LazyVStack(spacing: DesignTokens.spacingMD) {
                // 搜尋和篩選區域
                searchAndFilterSection
                
                // 錦標賽類型選擇器
                tournamentTypeSelector
                
                // 錦標賽列表
                tournamentsList
            }
            .padding()
        }
        .adaptiveBackground()
        .refreshable {
            await refreshTournaments()
        }
    }
    
    // MARK: - 搜尋和篩選區域
    private var searchAndFilterSection: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // 搜尋框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray600)
                
                TextField("搜尋錦標賽...", text: $searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray600)
                    }
                }
            }
            .padding()
            .background(Color.surfaceSecondary)
            .cornerRadius(12)
            
            // 快速篩選按鈕
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingSM) {
                    quickFilterButton("全部", selectedType == nil) {
                        selectedType = nil
                    }
                    
                    quickFilterButton("進行中", false) {
                        // TODO: 篩選進行中的錦標賽
                    }
                    
                    quickFilterButton("即將開始", false) {
                        // TODO: 篩選即將開始的錦標賽
                    }
                    
                    quickFilterButton("可參加", false) {
                        // TODO: 篩選可參加的錦標賽
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - 錦標賽類型選擇器
    private var tournamentTypeSelector: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("錦標賽類型")
                .font(.headline)
                .adaptiveTextColor()
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(TournamentType.allCases, id: \.self) { type in
                        tournamentTypeCard(type)
                    }
                }
                .padding(.horizontal)
            }
        }
    }
    
    // MARK: - 錦標賽列表
    private var tournamentsList: some View {
        LazyVStack(spacing: DesignTokens.spacingSM) {
            ForEach(filteredTournaments, id: \.id) { tournament in
                tournamentCard(tournament)
                    .onTapGesture {
                        selectedTournament = tournament
                        showingDetail = true
                    }
            }
            
            if filteredTournaments.isEmpty {
                emptyStateView
            }
        }
    }
    
    // MARK: - 錦標賽類型卡片
    private func tournamentTypeCard(_ type: TournamentType) -> some View {
        VStack(spacing: 8) {
            Image(systemName: type.iconName)
                .font(.title2)
                .foregroundColor(selectedType == type ? .white : .brandGreen)
            
            Text(type.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(selectedType == type ? .white : .adaptiveTextColor)
            
            Text(type.duration)
                .font(.caption2)
                .foregroundColor(selectedType == type ? .white.opacity(0.8) : .adaptiveTextColor.opacity(0.6))
        }
        .frame(width: 80, height: 80)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(selectedType == type ? Color.brandGreen : Color.surfaceSecondary)
        )
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedType = selectedType == type ? nil : type
            }
        }
    }
    
    // MARK: - 錦標賽卡片
    private func tournamentCard(_ tournament: Tournament) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            // 標題和狀態
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: tournament.type.iconName)
                        .foregroundColor(.brandGreen)
                        .font(.title3)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text(tournament.name)
                            .font(.headline)
                            .adaptiveTextColor()
                        
                        Text(tournament.type.displayName)
                            .font(.caption)
                            .adaptiveTextColor(primary: false)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(tournament.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(tournament.status.color)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(tournament.status.color.opacity(0.1))
                        .cornerRadius(6)
                    
                    if tournament.status != .ended {
                        Text(tournament.timeRemaining)
                            .font(.caption2)
                            .adaptiveTextColor(primary: false)
                    }
                }
            }
            
            // 描述
            Text(tournament.description)
                .font(.subheadline)
                .adaptiveTextColor(primary: false)
                .lineLimit(2)
            
            Divider()
                .background(Color.divider)
            
            // 詳細信息
            HStack {
                // 參與人數
                Label("\(tournament.currentParticipants)/\(tournament.maxParticipants)", systemImage: "person.2.fill")
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
                
                Spacer()
                
                // 獎金池
                Label("$\(tournament.prizePool, specifier: "%.0f")", systemImage: "dollarsign.circle.fill")
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
                
                Spacer()
                
                // 初始資金
                Label("$\(tournament.initialBalance / 10000, specifier: "%.0f")萬", systemImage: "banknote.fill")
                    .font(.caption)
                    .adaptiveTextColor(primary: false)
            }
            
            // 參與進度條
            if tournament.maxParticipants > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("參與度")
                            .font(.caption2)
                            .adaptiveTextColor(primary: false)
                        
                        Spacer()
                        
                        Text("\(Int(tournament.participantsPercentage * 100))%")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .adaptiveTextColor(primary: false)
                    }
                    
                    ProgressView(value: tournament.participantsPercentage)
                        .tint(tournament.participantsFull ? .danger : .brandGreen)
                        .background(Color.gray300)
                }
            }
            
            // 動作按鈕
            HStack {
                if tournament.isJoinable {
                    Button("加入錦標賽") {
                        // TODO: 加入錦標賽邏輯
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.brandGreen)
                    .cornerRadius(8)
                } else if tournament.isActive {
                    Button("查看詳情") {
                        selectedTournament = tournament
                        showingDetail = true
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.brandOrange)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(Color.brandOrange.opacity(0.1))
                    .cornerRadius(8)
                } else {
                    Text("錦標賽已結束")
                        .font(.subheadline)
                        .foregroundColor(.gray600)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Color.gray200)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    selectedTournament = tournament
                    showingDetail = true
                }) {
                    Image(systemName: "info.circle")
                        .foregroundColor(.brandGreen)
                }
                .padding(.leading, 8)
            }
        }
        .padding()
        .background(Color.surfacePrimary)
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
    }
    
    // MARK: - 快速篩選按鈕
    private func quickFilterButton(_ title: String, _ isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(isSelected ? .white : .brandGreen)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? Color.brandGreen : Color.brandGreen.opacity(0.1))
                )
        }
    }
    
    // MARK: - 空狀態視圖
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trophy.slash")
                .font(.system(size: 48))
                .foregroundColor(.gray400)
            
            Text("沒有找到符合條件的錦標賽")
                .font(.headline)
                .adaptiveTextColor(primary: false)
            
            Text("試試調整搜尋條件或稍後再來查看")
                .font(.subheadline)
                .adaptiveTextColor(primary: false)
                .multilineTextAlignment(.center)
            
            Button("重新整理") {
                Task {
                    await refreshTournaments()
                }
            }
            .font(.subheadline)
            .foregroundColor(.brandGreen)
        }
        .padding(.vertical, 40)
    }
    
    // MARK: - 計算屬性
    private var filteredTournaments: [Tournament] {
        var filtered = tournaments
        
        // 按類型篩選
        if let selectedType = selectedType {
            filtered = filtered.filter { $0.type == selectedType }
        }
        
        // 按搜尋文字篩選
        if !searchText.isEmpty {
            filtered = filtered.filter { tournament in
                tournament.name.localizedCaseInsensitiveContains(searchText) ||
                tournament.description.localizedCaseInsensitiveContains(searchText) ||
                tournament.type.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered.sorted { tournament1, tournament2 in
            // 優先顯示可參加的錦標賽
            if tournament1.isJoinable && !tournament2.isJoinable {
                return true
            } else if !tournament1.isJoinable && tournament2.isJoinable {
                return false
            }
            
            // 然後按狀態排序
            let statusOrder: [TournamentStatus] = [.active, .upcoming, .ended, .cancelled]
            let status1Index = statusOrder.firstIndex(of: tournament1.status) ?? statusOrder.count
            let status2Index = statusOrder.firstIndex(of: tournament2.status) ?? statusOrder.count
            
            if status1Index != status2Index {
                return status1Index < status2Index
            }
            
            // 最後按開始時間排序
            return tournament1.startDate < tournament2.startDate
        }
    }
    
    // MARK: - 數據刷新
    private func refreshTournaments() async {
        isRefreshing = true
        // TODO: 實際的數據刷新邏輯
        try? await Task.sleep(nanoseconds: 1_500_000_000) // 模擬網路請求
        isRefreshing = false
    }
}

// MARK: - 預覽
#Preview {
    TournamentSelectionView(
        selectedTournament: .constant(nil),
        showingDetail: .constant(false)
    )
    .environmentObject(ThemeManager.shared)
}