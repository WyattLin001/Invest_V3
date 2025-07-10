//
//  HomeView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct HomeView: View {
    @State private var totalPortfolioValue: Double = 125000
    @State private var dailyChange: Double = 2.5
    @State private var weeklyRankings = WeeklyRanking.sampleData
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Portfolio Summary Card
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("總投資組合價值")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("NT$ \(totalPortfolioValue, specifier: "%.0f")")
                                    .font(.title)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing) {
                                HStack {
                                    Image(systemName: dailyChange >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .foregroundColor(dailyChange >= 0 ? .green : .red)
                                    Text("\(dailyChange >= 0 ? "+" : "")\(dailyChange, specifier: "%.2f")%")
                                        .foregroundColor(dailyChange >= 0 ? .green : .red)
                                        .fontWeight(.semibold)
                                }
                                Text("今日變化")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        // Quick Actions
                        HStack(spacing: 12) {
                            QuickActionButton(title: "買入", icon: "plus.circle.fill", color: .green) {
                                // Buy action
                            }
                            
                            QuickActionButton(title: "賣出", icon: "minus.circle.fill", color: .red) {
                                // Sell action
                            }
                            
                            QuickActionButton(title: "分析", icon: "chart.bar.fill", color: .blue) {
                                // Analysis action
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Weekly Rankings
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("本週排行榜")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("查看全部") {
                                // View all rankings
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        LazyVStack(spacing: 12) {
                            ForEach(Array(weeklyRankings.prefix(5).enumerated()), id: \.element.id) { index, ranking in
                                WeeklyRankingRow(ranking: ranking, rank: index + 1)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Featured Articles
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("精選文章")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("查看更多") {
                                // View more articles
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        LazyVStack(spacing: 12) {
                            ForEach(Array(Article.sampleData.prefix(3))) { article in
                                ArticleCard(article: article)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Seeking Alpha")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color.opacity(0.1))
            .cornerRadius(12)
        }
    }
}

struct WeeklyRankingRow: View {
    let ranking: WeeklyRanking
    let rank: Int
    
    var body: some View {
        HStack {
            // Rank badge
            Text("\(rank)")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 32, height: 32)
                .background(rankColor)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                Text(ranking.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Text("本週表現")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                HStack {
                    Image(systemName: ranking.returnRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(ranking.returnRate >= 0 ? .green : .red)
                    
                    Text("\(ranking.returnRate >= 0 ? "+" : "")\(ranking.returnRate, specifier: "%.2f")%")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(ranking.returnRate >= 0 ? .green : .red)
                }
            }
        }
        .padding(.vertical, 8)
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

struct ArticleCard: View {
    let article: Article
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(article.category)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(8)
                
                Spacer()
                
                if !article.isFree {
                    Image(systemName: "crown.fill")
                        .foregroundColor(.yellow)
                        .font(.caption)
                }
            }
            
            Text(article.title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(2)
            
            Text(article.summary)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(3)
            
            HStack {
                Text("by \(article.author)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                HStack(spacing: 12) {
                    HStack(spacing: 4) {
                        Image(systemName: "heart")
                            .font(.caption)
                        Text("\(article.likesCount)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Image(systemName: "bubble.left")
                            .font(.caption)
                        Text("\(article.commentsCount)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    Text(article.readTime)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// Sample data for weekly rankings
struct WeeklyRanking: Identifiable {
    let id = UUID()
    let name: String
    let returnRate: Double
    
    static let sampleData = [
        WeeklyRanking(name: "投資高手", returnRate: 15.8),
        WeeklyRanking(name: "股市達人", returnRate: 12.3),
        WeeklyRanking(name: "價值投資者", returnRate: 9.7),
        WeeklyRanking(name: "技術分析師", returnRate: 8.2),
        WeeklyRanking(name: "長期持有者", returnRate: 6.5)
    ]
}

#Preview {
    HomeView()
}