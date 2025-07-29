//
//  InvestmentSimulationView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/28.
//  投資模擬主介面 - 用戶點擊投資模擬的入口點
//

import SwiftUI

/// 投資模擬主介面
struct InvestmentSimulationView: View {
    @StateObject private var simulationService = TournamentSimulationService.shared
    @StateObject private var portfolioManager = TournamentPortfolioManager.shared
    @StateObject private var rankingSystem = TournamentRankingSystem.shared
    
    @State private var showingTournamentDetails = false
    @State private var selectedTournament: Tournament?
    @State private var showingUserSummary = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // 主要投資模擬按鈕
                    investmentSimulationButton
                    
                    // 狀態顯示
                    simulationStatusView
                    
                    // 用戶錦標賽摘要
                    if simulationService.simulationStatus == .ready {
                        userTournamentSummaryView
                        
                        // 參與的錦標賽列表
                        participatingTournamentsView
                    }
                }
                .padding()
            }
            .navigationTitle("投資模擬")
            .refreshable {
                await refreshSimulationData()
            }
        }
        .sheet(isPresented: $showingTournamentDetails) {
            if let tournament = selectedTournament {
                TournamentDetailSheet(tournament: tournament)
            }
        }
        .sheet(isPresented: $showingUserSummary) {
            UserTournamentSummarySheet()
        }
    }
    
    // MARK: - View Components
    
    /// 主要投資模擬按鈕
    private var investmentSimulationButton: some View {
        Button(action: {
            Task {
                await startInvestmentSimulation()
            }
        }) {
            HStack(spacing: 16) {
                // 圖標
                Image(systemName: getSimulationButtonIcon())
                    .font(.title2)
                    .foregroundColor(.white)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(getSimulationButtonTitle())
                        .font(.headline)
                        .foregroundColor(.white)
                    
                    Text(getSimulationButtonSubtitle())
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                if simulationService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                }
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(getSimulationButtonColor())
            .cornerRadius(12)
            .shadow(color: getSimulationButtonColor().opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(simulationService.isLoading)
    }
    
    /// 模擬狀態顯示
    private var simulationStatusView: some View {
        Group {
            switch simulationService.simulationStatus {
            case .notStarted:
                InfoCard(
                    icon: "info.circle",
                    title: "準備開始",
                    description: "點擊上方按鈕開始投資模擬",
                    color: .blue
                )
                
            case .initializing:
                InfoCard(
                    icon: "gear",
                    title: "初始化中",
                    description: "正在設置您的錦標賽投資組合...",
                    color: .orange
                )
                
            case .ready:
                InfoCard(
                    icon: "checkmark.circle.fill",
                    title: "模擬已就緒",
                    description: "您的投資模擬已經啟動，可以開始交易了！",
                    color: .green
                )
                
            case .error(let message):
                InfoCard(
                    icon: "exclamationmark.triangle.fill",
                    title: "發生錯誤",
                    description: message,
                    color: .red
                )
            }
        }
    }
    
    /// 用戶錦標賽摘要
    private var userTournamentSummaryView: some View {
        let summary = simulationService.getUserTournamentSummary()
        
        return VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("投資摘要")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("詳細資訊") {
                    showingUserSummary = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            LazyVGrid(columns: [
                GridItem(.flexible()), 
                GridItem(.flexible())
            ], spacing: 12) {
                SummaryCard(
                    title: "參與錦標賽",
                    value: "\(summary.participatingTournaments)",
                    unit: "個",
                    icon: "trophy.fill",
                    color: .orange
                )
                
                SummaryCard(
                    title: "總投資組合價值",
                    value: String(format: "%.0f", summary.totalPortfolioValue),
                    unit: "NT$",
                    icon: "dollarsign.circle.fill",
                    color: .green
                )
                
                SummaryCard(
                    title: "總收益",
                    value: String(format: "%.2f", summary.totalReturnPercentage),
                    unit: "%",
                    icon: summary.totalReturn >= 0 ? "arrow.up.right" : "arrow.down.right",
                    color: summary.totalReturn >= 0 ? .green : .red
                )
                
                SummaryCard(
                    title: "最佳排名",
                    value: summary.bestRank > 0 ? "\(summary.bestRank)" : "N/A",
                    unit: "名",
                    icon: "crown.fill",
                    color: .yellow
                )
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(12)
    }
    
    /// 參與的錦標賽列表
    private var participatingTournamentsView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("參與的錦標賽")
                .font(.headline)
                .foregroundColor(.primary)
            
            ForEach(getParticipatingTournaments(), id: \.id) { tournament in
                TournamentParticipationCard(tournament: tournament) {
                    selectedTournament = tournament
                    showingTournamentDetails = true
                }
            }
        }
    }
    
    // MARK: - Helper Methods
    
    private func startInvestmentSimulation() async {
        await simulationService.startInvestmentSimulation()
    }
    
    private func refreshSimulationData() async {
        if simulationService.simulationStatus == .ready {
            await simulationService.startInvestmentSimulation()
        }
    }
    
    private func getSimulationButtonIcon() -> String {
        switch simulationService.simulationStatus {
        case .notStarted:
            return "play.fill"
        case .initializing:
            return "gear"
        case .ready:
            return "checkmark.circle.fill"
        case .error:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private func getSimulationButtonTitle() -> String {
        switch simulationService.simulationStatus {
        case .notStarted:
            return "開始投資模擬"
        case .initializing:
            return "初始化中..."
        case .ready:
            return "投資模擬已啟動"
        case .error:
            return "重新嘗試"
        }
    }
    
    private func getSimulationButtonSubtitle() -> String {
        switch simulationService.simulationStatus {
        case .notStarted:
            return "確認用戶身份並初始化錦標賽投資組合"
        case .initializing:
            return "正在設置您的投資模擬環境..."
        case .ready:
            return "已就緒，可以開始交易"
        case .error:
            return "點擊重新初始化"
        }
    }
    
    private func getSimulationButtonColor() -> Color {
        switch simulationService.simulationStatus {
        case .notStarted:
            return .blue
        case .initializing:
            return .orange
        case .ready:
            return .green
        case .error:
            return .red
        }
    }
    
    private func getParticipatingTournaments() -> [Tournament] {
        return simulationService.currentTournaments.filter { tournament in
            simulationService.userTournamentStatus[tournament.id]?.isParticipating == true
        }
    }
}

// MARK: - Supporting Views

/// 資訊卡片
struct InfoCard: View {
    let icon: String
    let title: String
    let description: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
            
            Spacer()
        }
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(10)
    }
}

/// 摘要卡片
struct SummaryCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .bottom, spacing: 2) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text(unit)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color.white)
        .cornerRadius(8)
        .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
    }
}

/// 錦標賽參與卡片
struct TournamentParticipationCard: View {
    let tournament: Tournament
    let onTap: () -> Void
    
    @StateObject private var portfolioManager = TournamentPortfolioManager.shared
    @StateObject private var rankingSystem = TournamentRankingSystem.shared
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 錦標賽圖標和狀態
                VStack {
                    Image(systemName: tournament.type.iconName)
                        .font(.title2)
                        .foregroundColor(tournament.status.color)
                    
                    Text(tournament.status.displayName)
                        .font(.caption2)
                        .foregroundColor(tournament.status.color)
                }
                .frame(width: 60)
                
                // 錦標賽資訊
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.name)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.leading)
                    
                    if let portfolio = portfolioManager.getPortfolio(for: tournament.id) {
                        HStack(spacing: 16) {
                            Text("收益: \(String(format: "%.2f", portfolio.totalReturnPercentage))%")
                                .font(.caption)
                                .foregroundColor(portfolio.totalReturn >= 0 ? .green : .red)
                            
                            if let ranking = rankingSystem.getUserRanking(tournamentId: tournament.id, userId: portfolio.userId) {
                                Text("排名: \(ranking.currentRank)")
                                    .font(.caption)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
            .padding()
            .background(Color.white)
            .cornerRadius(10)
            .shadow(color: .gray.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

/// 錦標賽詳細資訊彈窗
struct TournamentDetailSheet: View {
    let tournament: Tournament
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var simulationService = TournamentSimulationService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 錦標賽基本資訊
                    VStack(alignment: .leading, spacing: 12) {
                        Text(tournament.name)
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text(tournament.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    // 用戶在此錦標賽的詳細資訊將在後續實現
                    Text("錦標賽詳細資訊功能開發中...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("錦標賽詳情")
            .navigationBarItems(trailing: Button("關閉") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

/// 用戶錦標賽摘要彈窗
struct UserTournamentSummarySheet: View {
    @Environment(\.presentationMode) var presentationMode
    @StateObject private var simulationService = TournamentSimulationService.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("用戶投資摘要詳細資訊功能開發中...")
                        .font(.caption)
                        .foregroundColor(.gray)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                }
                .padding()
            }
            .navigationTitle("投資摘要")
            .navigationBarItems(trailing: Button("關閉") {
                presentationMode.wrappedValue.dismiss()
            })
        }
    }
}

// MARK: - Preview

#if DEBUG
struct InvestmentSimulationView_Previews: PreviewProvider {
    static var previews: some View {
        InvestmentSimulationView()
    }
}
#endif