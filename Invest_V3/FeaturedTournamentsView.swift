//
//  FeaturedTournamentsView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/26.
//  精選錦標賽視圖 - 智能推薦適合用戶的錦標賽
//

import SwiftUI

// MARK: - 精選錦標賽視圖

/// 精選錦標賽視圖
/// 提供智能推薦的錦標賽，幫助用戶快速找到適合的比賽
struct FeaturedTournamentsView: View {
    @State private var featuredTournaments: [Tournament] = []
    @State private var isLoading = false
    @State private var selectedTournament: Tournament?
    @State private var showingTournamentDetail = false
    
    let onEnrollTournament: ((Tournament) -> Void)?
    let onViewTournamentDetails: ((Tournament) -> Void)?
    
    init(
        onEnrollTournament: ((Tournament) -> Void)? = nil,
        onViewTournamentDetails: ((Tournament) -> Void)? = nil
    ) {
        self.onEnrollTournament = onEnrollTournament
        self.onViewTournamentDetails = onViewTournamentDetails
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 精選標題區域
            featuredHeader
            
            if isLoading {
                // 載入狀態
                loadingView
            } else if featuredTournaments.isEmpty {
                // 空狀態
                emptyStateView
            } else {
                // 錦標賽列表
                tournamentsContent
            }
        }
        .onAppear {
            loadFeaturedTournaments()
        }
        .refreshable {
            await refreshFeaturedTournaments()
        }
    }
    
    // MARK: - 精選標題區域
    
    private var featuredHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 精選圖標和標題
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.title2)
                        .foregroundColor(.orange)
                    
                    Text("精選錦標賽")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                }
                
                Spacer()
                
                // 查看全部按鈕
                Button("查看全部") {
                    // 切換到所有錦標賽視圖
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }
            
            // 描述文字
            Text("根據您的投資經驗和偏好，為您推薦最適合的錦標賽")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .lineLimit(2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [
                    Color.orange.opacity(0.05),
                    Color.yellow.opacity(0.03)
                ],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
    }
    
    // MARK: - 載入狀態
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ForEach(0..<3, id: \.self) { _ in
                TournamentCardSkeleton()
            }
        }
        .padding()
    }
    
    // MARK: - 空狀態
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "star.slash")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("暫無精選錦標賽")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("我們正在為您尋找最適合的錦標賽\n請稍後再試或查看所有錦標賽")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("查看所有錦標賽") {
                // 切換到所有錦標賽視圖
            }
            .buttonStyle(PrimaryButtonStyle())
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - 錦標賽內容
    
    private var tournamentsContent: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(featuredTournaments) { tournament in
                    FeaturedTournamentCard(
                        tournament: tournament,
                        onEnroll: {
                            handleEnrollTournament(tournament)
                        },
                        onViewDetails: {
                            handleViewTournamentDetails(tournament)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - 資料載入
    
    private func loadFeaturedTournaments() {
        isLoading = true
        
        // 模擬API呼叫
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            featuredTournaments = Tournament.featuredMockTournaments
            isLoading = false
        }
    }
    
    @MainActor
    private func refreshFeaturedTournaments() async {
        // 模擬刷新
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1秒
        featuredTournaments = Tournament.featuredMockTournaments
    }
    
    // MARK: - 事件處理
    
    private func handleEnrollTournament(_ tournament: Tournament) {
        onEnrollTournament?(tournament)
    }
    
    private func handleViewTournamentDetails(_ tournament: Tournament) {
        selectedTournament = tournament
        onViewTournamentDetails?(tournament)
    }
}

// MARK: - 精選錦標賽卡片

/// 精選錦標賽卡片
/// 比普通卡片更突出，包含推薦理由
private struct FeaturedTournamentCard: View {
    let tournament: Tournament
    let onEnroll: () -> Void
    let onViewDetails: () -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // 精選標籤
            featuredBadge
            
            // 錦標賽卡片
            TournamentCardView(
                tournament: tournament,
                onEnroll: onEnroll,
                onViewDetails: onViewDetails
            )
            
            // 推薦理由
            recommendationReason
        }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.05))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(
                            LinearGradient(
                                colors: [.orange, .yellow],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: .orange.opacity(0.2), radius: 8, x: 0, y: 4)
        )
    }
    
    private var featuredBadge: some View {
        HStack {
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.system(size: 12, weight: .bold))
                
                Text("精選推薦")
                    .font(.system(size: 12, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                LinearGradient(
                    colors: [.orange, .red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(RoundedRectangle(cornerRadius: 16))
            
            Spacer()
        }
        .padding(.top, -8)
        .padding(.horizontal, 16)
        .zIndex(1)
    }
    
    private var recommendationReason: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("💡 推薦理由")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text(getRecommendationReason())
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            Rectangle()
                .fill(Color.orange.opacity(0.05))
        )
    }
    
    private func getRecommendationReason() -> String {
        switch tournament.type {
        case .monthly:
            return "月度賽事適合中期投資策略，獎金豐厚且參與度高，是累積經驗的最佳選擇"
        case .yearly:
            return "年度冠軍賽是最高榮譽的比賽，獎金池高達500萬，證明您的長期投資實力"
        case .special:
            return "限時特別賽事，把握重大經濟事件的投資機會，短時間內獲得高額回報"
        case .weekly:
            return "週賽節奏適中，適合練習波段操作策略，快速獲得交易經驗"
        case .daily:
            return "日賽挑戰您的短線交易技巧，適合喜歡快節奏交易的投資者"
        case .quarterly:
            return "季度賽事平衡短期與長期策略，是展現全面投資能力的舞台"
        }
    }
}

// MARK: - 卡片骨架載入

/// 錦標賽卡片骨架載入效果
private struct TournamentCardSkeleton: View {
    @State private var isAnimating = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 頂部標籤區域
            HStack {
                skeletonRectangle(width: 60, height: 24)
                Spacer()
                skeletonRectangle(width: 50, height: 20)
            }
            
            // 標題區域
            skeletonRectangle(width: 200, height: 20)
            
            // 描述區域
            VStack(alignment: .leading, spacing: 4) {
                skeletonRectangle(width: .infinity, height: 16)
                skeletonRectangle(width: 150, height: 16)
            }
            
            // 統計區域
            HStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    skeletonRectangle(width: 60, height: 14)
                    skeletonRectangle(width: 80, height: 18)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    skeletonRectangle(width: 60, height: 14)
                    skeletonRectangle(width: 70, height: 18)
                }
            }
            
            // 按鈕區域
            HStack(spacing: 12) {
                skeletonRectangle(width: 100, height: 36)
                skeletonRectangle(width: 120, height: 36)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.gray.opacity(0.05))
        )
        .onAppear {
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                isAnimating.toggle()
            }
        }
    }
    
    private func skeletonRectangle(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(.gray.opacity(0.1))
            .frame(width: width == .infinity ? nil : width, height: height)
            .frame(maxWidth: width == .infinity ? .infinity : nil)
            .opacity(isAnimating ? 0.3 : 0.6)
            .clipShape(RoundedRectangle(cornerRadius: 4))
    }
}

// MARK: - 按鈕樣式

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.blue)
                    .opacity(configuration.isPressed ? 0.8 : 1.0)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview

/* #Preview("精選錦標賽") {
    NavigationView {
        FeaturedTournamentsView(
            onEnrollTournament: { tournament in
                print("報名錦標賽: \(tournament.name)")
            },
            onViewTournamentDetails: { tournament in
                print("查看詳情: \(tournament.name)")
            }
        )
        .navigationTitle("精選錦標賽")
    }
}
*/

/*
#Preview("載入狀態") {
    FeaturedTournamentsView()
        .onAppear {
            // 模擬載入狀態
        }
}
*/

/*
#Preview("空狀態") {
    struct EmptyFeaturedView: View {
        var body: some View {
            VStack(spacing: 16) {
                Image(systemName: "star.slash")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                
                Text("暫無精選錦標賽")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text("我們正在為您尋找最適合的錦標賽\n請稍後再試或查看所有錦標賽")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
        }
    }
    
    return EmptyFeaturedView()
}*/
