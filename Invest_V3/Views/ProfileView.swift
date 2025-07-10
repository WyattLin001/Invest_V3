//
//  ProfileView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct ProfileView: View {
    @State private var userName = "投資新手"
    @State private var userEmail = "investor@example.com"
    @State private var balance = 50000
    @State private var withdrawableAmount = 25000
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Header
                    VStack(spacing: 16) {
                        // Avatar
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .overlay(
                                Text(String(userName.prefix(1)))
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                            )
                        
                        VStack(spacing: 4) {
                            Text(userName)
                                .font(.title2)
                                .fontWeight(.bold)
                            
                            Text(userEmail)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        
                        Button("編輯個人資料") {
                            // Edit profile action
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(20)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Wallet Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("錢包餘額")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("總餘額")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("NT$ \(balance)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            
                            Spacer()
                            
                            VStack(alignment: .trailing, spacing: 8) {
                                Text("可提領")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("NT$ \(withdrawableAmount)")
                                    .font(.title3)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.green)
                            }
                        }
                        
                        HStack(spacing: 12) {
                            Button("儲值") {
                                // Deposit action
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                            
                            Button("提領") {
                                // Withdraw action
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.blue.opacity(0.1))
                            .cornerRadius(10)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Menu Items
                    VStack(spacing: 0) {
                        ProfileMenuItem(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "投資表現",
                            subtitle: "查看投資統計"
                        ) {
                            // Performance action
                        }
                        
                        Divider()
                            .padding(.leading, 60)
                        
                        ProfileMenuItem(
                            icon: "person.3.fill",
                            title: "我的群組",
                            subtitle: "管理加入的投資群組"
                        ) {
                            // My groups action
                        }
                        
                        Divider()
                            .padding(.leading, 60)
                        
                        ProfileMenuItem(
                            icon: "doc.text.fill",
                            title: "我的文章",
                            subtitle: "查看發布的文章"
                        ) {
                            // My articles action
                        }
                        
                        Divider()
                            .padding(.leading, 60)
                        
                        ProfileMenuItem(
                            icon: "clock.fill",
                            title: "交易紀錄",
                            subtitle: "查看所有交易歷史"
                        ) {
                            // Transaction history action
                        }
                        
                        Divider()
                            .padding(.leading, 60)
                        
                        ProfileMenuItem(
                            icon: "gearshape.fill",
                            title: "設定",
                            subtitle: "應用程式設定"
                        ) {
                            // Settings action
                        }
                        
                        Divider()
                            .padding(.leading, 60)
                        
                        ProfileMenuItem(
                            icon: "questionmark.circle.fill",
                            title: "幫助與支援",
                            subtitle: "常見問題與客服"
                        ) {
                            // Help action
                        }
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Logout Button
                    Button("登出") {
                        // Logout action
                    }
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(10)
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("個人資料")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

struct ProfileMenuItem: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

#Preview {
    ProfileView()
}