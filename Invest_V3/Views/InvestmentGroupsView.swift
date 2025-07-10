//
//  InvestmentGroupsView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct InvestmentGroupsView: View {
    @State private var groups = InvestmentGroup.sampleData
    @State private var searchText = ""
    @State private var selectedCategory = "全部"
    
    private let categories = ["全部", "科技股", "價值投資", "加密貨幣", "ETF", "債券"]
    
    var filteredGroups: [InvestmentGroup] {
        var filtered = groups
        
        if selectedCategory != "全部" {
            filtered = filtered.filter { $0.category == selectedCategory }
        }
        
        if !searchText.isEmpty {
            filtered = filtered.filter { 
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.host.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return filtered
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    
                    TextField("搜尋投資群組...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                .padding(.top)
                
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
                .padding(.vertical)
                
                // Groups List
                ScrollView {
                    LazyVStack(spacing: 16) {
                        ForEach(filteredGroups) { group in
                            InvestmentGroupCard(group: group)
                        }
                    }
                    .padding()
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("投資群組")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Create new group
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
    }
}

struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(isSelected ? Color.blue : Color(.systemGray6))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(20)
        }
    }
}

struct InvestmentGroupCard: View {
    let group: InvestmentGroup
    
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
                    
                    Text("\(group.memberCount) 成員")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Performance
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("報酬率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Image(systemName: group.returnRate >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                            .foregroundColor(group.returnRate >= 0 ? .green : .red)
                        
                        Text("\(group.returnRate >= 0 ? "+" : "")\(group.returnRate, specifier: "%.1f")%")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(group.returnRate >= 0 ? .green : .red)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("入群費用")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text(group.entryFee)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
            
            // Action Buttons
            HStack(spacing: 12) {
                Button {
                    // Join group action
                } label: {
                    Text("加入群組")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(10)
                }
                
                Button {
                    // View details action
                } label: {
                    Text("查看詳情")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(10)
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
    InvestmentGroupsView()
}