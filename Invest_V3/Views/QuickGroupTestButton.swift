//
//  QuickGroupTestButton.swift
//  Invest_V3
//
//  快速群組系統測試按鈕
//  可以放置在任何界面用於快速測試
//

import SwiftUI

struct QuickGroupTestButton: View {
    @State private var showTestView = false
    @State private var testStatus: QuickTestStatus = .unknown
    @State private var isRunningTest = false
    
    var body: some View {
        Button {
            showTestView = true
        } label: {
            HStack(spacing: 12) {
                Image(systemName: testStatus.iconName)
                    .font(.title3)
                    .foregroundColor(testStatus.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text("群組系統測試")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(testStatus.message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isRunningTest {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(testStatus.backgroundColor)
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(testStatus.borderColor, lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(isPresented: $showTestView) {
            GroupSystemTestView()
        }
        .task {
            await runQuickCheck()
        }
    }
    
    private func runQuickCheck() async {
        isRunningTest = true
        testStatus = .testing
        
        do {
            // 快速檢查 Supabase 連接
            _ = try await SupabaseService.shared.fetchInvestmentGroups()
            testStatus = .success
        } catch {
            testStatus = .error
        }
        
        isRunningTest = false
    }
}

// MARK: - Inline Test Widget

struct InlineGroupTestWidget: View {
    @StateObject private var testManager = QuickTestManager()
    
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text("系統狀態")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Spacer()
                
                Button("詳細測試") {
                    testManager.showDetailedTest = true
                }
                .font(.caption)
                .foregroundColor(.blue)
            }
            
            HStack(spacing: 16) {
                StatusIndicator(
                    title: "數據庫",
                    status: testManager.databaseStatus
                )
                
                StatusIndicator(
                    title: "群組",
                    status: testManager.groupStatus
                )
                
                StatusIndicator(
                    title: "聊天",
                    status: testManager.chatStatus
                )
                
                Spacer()
                
                Button {
                    Task {
                        await testManager.runQuickCheck()
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.title3)
                        .foregroundColor(.blue)
                }
                .disabled(testManager.isRunning)
            }
        }
        .padding(16)
        .background(Color.systemSecondaryBackground)
        .cornerRadius(12)
        .task {
            await testManager.runQuickCheck()
        }
        .sheet(isPresented: $testManager.showDetailedTest) {
            GroupSystemTestView()
        }
    }
}

struct StatusIndicator: View {
    let title: String
    let status: QuickTestStatus
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: status.iconName)
                .font(.title3)
                .foregroundColor(status.color)
            
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 44)
    }
}

// MARK: - Quick Test Manager

@MainActor
class QuickTestManager: ObservableObject {
    @Published var databaseStatus: QuickTestStatus = .unknown
    @Published var groupStatus: QuickTestStatus = .unknown
    @Published var chatStatus: QuickTestStatus = .unknown
    @Published var isRunning = false
    @Published var showDetailedTest = false
    
    private let supabaseService = SupabaseService.shared
    
    func runQuickCheck() async {
        isRunning = true
        
        // 重置狀態
        databaseStatus = .testing
        groupStatus = .testing
        chatStatus = .testing
        
        // 測試數據庫連接
        do {
            _ = try await supabaseService.fetchInvestmentGroups()
            databaseStatus = .success
        } catch {
            databaseStatus = .error
        }
        
        // 測試群組功能
        do {
            let groups = try await supabaseService.fetchUserJoinedGroups()
            groupStatus = groups.isEmpty ? .warning : .success
        } catch {
            groupStatus = .error
        }
        
        // 測試聊天功能
        do {
            let userGroups = try await supabaseService.fetchUserJoinedGroups()
            if let firstGroup = userGroups.first {
                _ = try await supabaseService.fetchGroupDetails(groupId: firstGroup.id)
                chatStatus = .success
            } else {
                chatStatus = .warning
            }
        } catch {
            chatStatus = .error
        }
        
        isRunning = false
    }
}

// MARK: - Quick Test Status

enum QuickTestStatus {
    case success, error, warning, testing, unknown
    
    var color: Color {
        switch self {
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        case .testing: return .blue
        case .unknown: return .gray
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .success: return .green.opacity(0.1)
        case .error: return .red.opacity(0.1)
        case .warning: return .orange.opacity(0.1)
        case .testing: return .blue.opacity(0.1)
        case .unknown: return .gray.opacity(0.05)
        }
    }
    
    var borderColor: Color {
        switch self {
        case .success: return .green.opacity(0.3)
        case .error: return .red.opacity(0.3)
        case .warning: return .orange.opacity(0.3)
        case .testing: return .blue.opacity(0.3)
        case .unknown: return .gray.opacity(0.2)
        }
    }
    
    var iconName: String {
        switch self {
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .testing: return "clock.fill"
        case .unknown: return "questionmark.circle"
        }
    }
    
    var message: String {
        switch self {
        case .success: return "系統運行正常"
        case .error: return "系統異常"
        case .warning: return "部分功能受限"
        case .testing: return "檢測中..."
        case .unknown: return "未檢測"
        }
    }
}

// MARK: - Floating Test Button

struct FloatingGroupTestButton: View {
    @State private var showTestView = false
    @State private var isExpanded = false
    
    var body: some View {
        VStack {
            Spacer()
            
            HStack {
                Spacer()
                
                if isExpanded {
                    HStack(spacing: 12) {
                        Button("快速測試") {
                            showTestView = true
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.blue.opacity(0.1))
                        .foregroundColor(.blue)
                        .cornerRadius(8)
                        
                        Button {
                            withAnimation(.spring()) {
                                isExpanded.toggle()
                            }
                        } label: {
                            Image(systemName: "xmark")
                                .font(.title3)
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                                .background(Color.red)
                                .clipShape(Circle())
                        }
                    }
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                } else {
                    Button {
                        withAnimation(.spring()) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: "testtube.2")
                            .font(.title3)
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                            .background(Color.blue)
                            .clipShape(Circle())
                            .shadow(color: .black.opacity(0.2), radius: 4, x: 0, y: 2)
                    }
                }
            }
            .padding(.trailing, 20)
            .padding(.bottom, 100)
        }
        .sheet(isPresented: $showTestView) {
            GroupSystemTestView()
        }
    }
}

// MARK: - Preview

#Preview("Quick Test Button") {
    VStack {
        QuickGroupTestButton()
        
        Divider()
            .padding(.vertical)
        
        InlineGroupTestWidget()
        
        Spacer()
    }
    .padding()
}

#Preview("Floating Button") {
    ZStack {
        Color.gray.opacity(0.1)
            .ignoresSafeArea()
        
        FloatingGroupTestButton()
    }
}