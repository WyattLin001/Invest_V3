//
//  EnhancedHomeView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct EnhancedHomeView: View {
    @StateObject private var supabaseService = SupabaseService.shared
    @State private var investmentGroups: [InvestmentGroup] = []
    @State private var weeklyRankings: [WeeklyRanking] = []
    @State private var userBalance: Int = 5000
    @State private var selectedCategory = "全部"
    @State private var isLoading = false
    
    private let categories = ["全部", "科技股", "綠能", "短期投機", "價值投資"]
    
    var filteredGroups: [InvestmentGroup] {
        if selectedCategory == "全部" {
            return investmentGroups
        }
        return investmentGroups.filter { $0.category == selectedCategory }
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Top Balance Bar
                    HStack {
                        Text("NTD")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Text("\(userBalance)")
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color(hex: "#00B900"))
                        
                        Spacer()
                        
                        HStack(spacing: 16) {
                            Button {
                                // Notification action
                            } label: {
                                Image(systemName: "bell")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                            
                            Button {
                                // Search action
                            } label: {
                                Image(systemName: "magnifyingglass")
                                    .font(.title3)
                                    .foregroundColor(.primary)
                            }
                        }
                    }
                    .padding(.horizontal)
                    .padding(.top)
                    
                    // Rankings Banner
                    if !weeklyRankings.isEmpty {
                        RankingsBannerView(rankings: Array(weeklyRankings.prefix(3)))
                            .padding(.horizontal)
                    }
                    
                    // Category Filter
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(categories, id: \.self) { category in
                                CategoryChip(
                                    title: category,
                                    isSelected: selectedCategory == category
                                ) {
                                    selectedCategory = category
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    // Recommended Groups Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("推薦群組")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(filteredGroups) { group in
                                EnhancedGroupCard(group: group) {
                                    joinGroup(group)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
            .refreshable {
                await loadData()
            }
        }
        .task {
            await loadData()
        }
    }
    
    private func loadData() async {
        isLoading = true
        
        do {
            async let groupsTask = supabaseService.fetchInvestmentGroups()
            async let rankingsTask = supabaseService.fetchWeeklyRankings()
            
            investmentGroups = try await groupsTask
            weeklyRankings = try await rankingsTask
        } catch {
            print("Failed to load data: \(error)")
        }
        
        isLoading = false
    }
    
    private func joinGroup(_ group: InvestmentGroup) {
        // Navigate to wallet for payment
        print("Joining group: \(group.name)")
    }
}

struct RankingsBannerView: View {
    let rankings: [WeeklyRanking]
    @State private var currentIndex = 0
    
    var body: some View {
        VStack(spacing: 12) {
            Text("排行榜")
                .font(.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            HStack(spacing: 12) {
                ForEach(Array(rankings.enumerated()), id: \.element.id) { index, ranking in
                    RankingCard(
                        ranking: ranking,
                        rank: index + 1,
                        isHighlighted: index == 0
                    )
                }
            }
            
            HStack(spacing: 12) {
                Button("本週冠軍") { }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(hex: "#00B900"))
                    .foregroundColor(.white)
                    .cornerRadius(12)
                
                Button("本季冠軍") { }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                
                Button("本年冠軍") { }
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color(.systemGray5))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                
                Spacer()
            }
        }
    }
}

struct RankingCard: View {
    let ranking: WeeklyRanking
    let rank: Int
    let isHighlighted: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            // Crown/Medal
            Text(rank == 1 ? "👑" : rank == 2 ? "🥈" : "🥉")
                .font(.title2)
            
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(rankColor)
                .clipShape(Circle())
            
            VStack(spacing: 4) {
                Text(ranking.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                
                HStack(spacing: 2) {
                    Image(systemName: ranking.returnRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(ranking.returnRate >= 0 ? .green : .red)
                    
                    Text("\(ranking.returnRate >= 0 ? "+" : "")\(ranking.returnRate, specifier: "%.1f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(ranking.returnRate >= 0 ? .green : .red)
                }
                
                Text("本週冠軍")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(isHighlighted ? Color.yellow.opacity(0.1) : Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isHighlighted ? Color.yellow : Color.clear, lineWidth: 2)
        )
        .cornerRadius(12)
    }
    
    private var rankColor: Color {
        switch rank {
        case 1: return .yellow
        case 2: return .gray
        case 3: return .orange
        default: return .blue
        }
    }
}

struct EnhancedGroupCard: View {
    let group: InvestmentGroup
    let onJoin: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(group.name)
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("主持人：\(group.host)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(group.category)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "person.2")
                            .font(.caption)
                        Text("\(group.memberCount)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
            }
            
            // Performance and Entry Fee
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Image(systemName: group.returnRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .foregroundColor(group.returnRate >= 0 ? .green : .red)
                        
                        Text("\(group.returnRate >= 0 ? "+" : "")\(group.returnRate, specifier: "%.1f")%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(group.returnRate >= 0 ? .green : .red)
                    }
                    
                    Text("2 花束 (200 NTD)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button(action: onJoin) {
                    Text("加入群組")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color(hex: "#FD7E14"))
                        .cornerRadius(20)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
    }
}

#Preview {
    EnhancedHomeView()
}