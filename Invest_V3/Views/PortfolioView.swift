//
//  PortfolioView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct PortfolioView: View {
    @State private var portfolios = Portfolio.sampleData
    @State private var totalValue: Double = 4300.0
    @State private var totalReturn: Double = 16.3
    @State private var showingAddStock = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Portfolio Summary
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("投資組合總值")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Text("NT$ \(totalValue, specifier: "%.0f")")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                
                                HStack {
                                    Image(systemName: totalReturn >= 0 ? "arrow.up.right" : "arrow.down.right")
                                        .foregroundColor(totalReturn >= 0 ? .green : .red)
                                    
                                    Text("\(totalReturn >= 0 ? "+" : "")\(totalReturn, specifier: "%.1f")%")
                                        .fontWeight(.semibold)
                                        .foregroundColor(totalReturn >= 0 ? .green : .red)
                                    
                                    Text("總報酬")
                                        .foregroundColor(.secondary)
                                }
                                .font(.subheadline)
                            }
                            
                            Spacer()
                            
                            // Portfolio Chart Placeholder
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
                                    Text("📊")
                                        .font(.title)
                                )
                        }
                        
                        // Quick Actions
                        HStack(spacing: 12) {
                            PortfolioActionButton(title: "買入", icon: "plus.circle.fill", color: .green) {
                                showingAddStock = true
                            }
                            
                            PortfolioActionButton(title: "賣出", icon: "minus.circle.fill", color: .red) {
                                // Sell action
                            }
                            
                            PortfolioActionButton(title: "分析", icon: "chart.line.uptrend.xyaxis", color: .blue) {
                                // Analysis action
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Holdings List
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text("持股明細")
                                .font(.headline)
                                .fontWeight(.bold)
                            
                            Spacer()
                            
                            Button("交易紀錄") {
                                // View transaction history
                            }
                            .font(.subheadline)
                            .foregroundColor(.blue)
                        }
                        
                        LazyVStack(spacing: 12) {
                            ForEach(portfolios) { portfolio in
                                PortfolioRow(portfolio: portfolio)
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
            .navigationTitle("投資組合")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showingAddStock = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddStock) {
            AddStockView()
        }
    }
}

struct PortfolioActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
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

struct PortfolioRow: View {
    let portfolio: Portfolio
    
    var body: some View {
        HStack {
            // Stock Symbol
            VStack(alignment: .leading, spacing: 4) {
                Text(portfolio.symbol)
                    .font(.headline)
                    .fontWeight(.bold)
                
                Text("\(portfolio.shares, specifier: "%.2f") 股")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Performance
            VStack(alignment: .trailing, spacing: 4) {
                Text("NT$ \(portfolio.currentValue, specifier: "%.0f")")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack(spacing: 4) {
                    Image(systemName: portfolio.returnRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption)
                        .foregroundColor(portfolio.returnRate >= 0 ? .green : .red)
                    
                    Text("\(portfolio.returnRate >= 0 ? "+" : "")\(portfolio.returnRate, specifier: "%.2f")%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(portfolio.returnRate >= 0 ? .green : .red)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct AddStockView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var symbol = ""
    @State private var shares = ""
    @State private var price = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("股票資訊") {
                    TextField("股票代號 (例如: AAPL)", text: $symbol)
                        .textInputAutocapitalization(.characters)
                    
                    TextField("股數", text: $shares)
                        .keyboardType(.decimalPad)
                    
                    TextField("買入價格", text: $price)
                        .keyboardType(.decimalPad)
                }
                
                Section {
                    Button("新增到投資組合") {
                        // Add stock logic
                        dismiss()
                    }
                    .disabled(symbol.isEmpty || shares.isEmpty || price.isEmpty)
                }
            }
            .navigationTitle("新增股票")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    PortfolioView()
}