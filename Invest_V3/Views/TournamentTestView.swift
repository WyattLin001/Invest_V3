//
//  TournamentTestView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/31.
//  錦標賽功能全面測試界面

import SwiftUI
import Foundation

// MARK: - 主測試控制面板
struct TournamentTestView: View {
    @StateObject private var testRunner = TournamentTestRunner()
    @State private var showResults = false
    @State private var selectedTestLayer: TestLayer = .all
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 測試控制台標題
                headerSection
                
                // 測試層級選擇器
                testLayerSelector
                
                // 測試內容
                ScrollView {
                    LazyVStack(spacing: 16) {
                        if selectedTestLayer == .all || selectedTestLayer == .foundation {
                            foundationTestSection
                        }
                        
                        if selectedTestLayer == .all || selectedTestLayer == .service {
                            serviceTestSection
                        }
                        
                        if selectedTestLayer == .all || selectedTestLayer == .business {
                            businessLogicTestSection
                        }
                        
                        if selectedTestLayer == .all || selectedTestLayer == .integration {
                            integrationTestSection
                        }
                        
                        if selectedTestLayer == .all || selectedTestLayer == .ui {
                            uiTestSection
                        }
                        
                        // 全面測試按鈕
                        fullTestSection
                    }
                    .padding(.horizontal)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("錦標賽測試控制台")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("清除結果") {
                        testRunner.clearResults()
                        showResults = false
                    }
                }
            }
            .sheet(isPresented: $showResults) {
                TestResultsView(testRunner: testRunner)
            }
        }
        .onReceive(testRunner.$hasResults) { hasResults in
            if hasResults {
                showResults = true
            }
        }
    }
    
    // MARK: - 頭部區域
    private var headerSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "trophy.fill")
                    .font(.title)
                    .foregroundColor(.orange)
                
                VStack(alignment: .leading) {
                    Text("錦標賽功能測試")
                        .font(.headline)
                        .fontWeight(.bold)
                    
                    Text("五層架構全面驗證系統")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing) {
                    Text("覆蓋率")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(Int(testRunner.coveragePercentage))%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(testRunner.coveragePercentage > 80 ? .green : .orange)
                }
            }
            
            // 進度條
            ProgressView(value: testRunner.coveragePercentage, total: 100)
                .progressViewStyle(LinearProgressViewStyle(tint: testRunner.coveragePercentage > 80 ? .green : .orange))
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .padding(.horizontal)
        .padding(.top)
    }
    
    // MARK: - 測試層級選擇器
    private var testLayerSelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(TestLayer.allCases, id: \.self) { layer in
                    Button(action: {
                        selectedTestLayer = layer
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: layer.iconName)
                                .font(.caption)
                            
                            Text(layer.displayName)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(selectedTestLayer == layer ? 
                                     layer.accentColor : Color(.systemGray5))
                        )
                        .foregroundColor(selectedTestLayer == layer ? .white : .primary)
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
    }
    
    // MARK: - 第一層：基礎模型測試
    private var foundationTestSection: some View {
        TestSectionView(
            title: "第一層：基礎模型測試",
            subtitle: "驗證資料結構完整性和計算邏輯",
            iconName: "cube.fill",
            accentColor: .blue,
            tests: [
                TestItemModel(
                    title: "常數配置測試",
                    description: "驗證系統配置常數和參數範圍",
                    iconName: "gearshape.fill",
                    action: { await testRunner.testConfiguration() }
                ),
                TestItemModel(
                    title: "Tournament 模型驗證",
                    description: "測試錦標賽基本屬性和計算邏輯",
                    iconName: "trophy",
                    action: { await testRunner.testTournamentModel() }
                ),
                TestItemModel(
                    title: "TournamentParticipant 測試",
                    description: "驗證參賽者指標計算正確性",
                    iconName: "person.fill",
                    action: { await testRunner.testParticipantModel() }
                ),
                TestItemModel(
                    title: "投資組合模型測試",
                    description: "檢查投資組合價值和持股計算",
                    iconName: "chart.pie.fill",
                    action: { await testRunner.testPortfolioModel() }
                ),
                TestItemModel(
                    title: "績效指標模型測試",
                    description: "驗證回報率、夏普比率等計算",
                    iconName: "chart.line.uptrend.xyaxis",
                    action: { await testRunner.testPerformanceMetrics() }
                )
            ],
            testRunner: testRunner
        )
    }
    
    // MARK: - 第二層：服務層測試
    private var serviceTestSection: some View {
        TestSectionView(
            title: "第二層：服務層測試",
            subtitle: "確保API調用和資料處理穩定性",
            iconName: "server.rack",
            accentColor: .green,
            tests: [
                TestItemModel(
                    title: "TournamentService API",
                    description: "測試錦標賽數據獲取和操作",
                    iconName: "network",
                    action: { await testRunner.testTournamentService() }
                ),
                TestItemModel(
                    title: "Supabase 整合測試",
                    description: "驗證即時數據同步功能",
                    iconName: "icloud.fill",
                    action: { await testRunner.testSupabaseIntegration() }
                ),
                TestItemModel(
                    title: "錯誤處理測試",
                    description: "模擬各種錯誤場景",
                    iconName: "exclamationmark.triangle.fill",
                    action: { await testRunner.testErrorHandling() }
                )
            ],
            testRunner: testRunner
        )
    }
    
    // MARK: - 第三層：業務邏輯測試
    private var businessLogicTestSection: some View {
        TestSectionView(
            title: "第三層：業務邏輯測試",
            subtitle: "驗證核心投資和交易邏輯",
            iconName: "brain.head.profile",
            accentColor: .purple,
            tests: [
                TestItemModel(
                    title: "投資組合管理器",
                    description: "測試交易執行和資金管理",
                    iconName: "briefcase.fill",
                    action: { await testRunner.testPortfolioManager() }
                ),
                TestItemModel(
                    title: "排名系統測試",
                    description: "驗證排序和變動檢測邏輯",
                    iconName: "list.number",
                    action: { await testRunner.testRankingSystem() }
                ),
                TestItemModel(
                    title: "風險控制測試",
                    description: "檢查風險限制和違規處理",
                    iconName: "shield.fill",
                    action: { await testRunner.testRiskControls() }
                )
            ],
            testRunner: testRunner
        )
    }
    
    // MARK: - 第四層：整合測試
    private var integrationTestSection: some View {
        TestSectionView(
            title: "第四層：整合測試",
            subtitle: "驗證完整使用者流程",
            iconName: "link.circle.fill",
            accentColor: .orange,
            tests: [
                TestItemModel(
                    title: "完整參賽流程",
                    description: "從報名到競賽結束的全流程",
                    iconName: "arrow.forward.circle.fill",
                    action: { await testRunner.testFullTournamentFlow() }
                ),
                TestItemModel(
                    title: "即時更新測試",
                    description: "驗證背景數據刷新機制",
                    iconName: "arrow.clockwise.circle.fill",
                    action: { await testRunner.testRealTimeUpdates() }
                ),
                TestItemModel(
                    title: "效能壓力測試",
                    description: "大數據量處理能力驗證",
                    iconName: "speedometer",
                    action: { await testRunner.testPerformanceStress() }
                )
            ],
            testRunner: testRunner
        )
    }
    
    // MARK: - 第五層：UI互動測試
    private var uiTestSection: some View {
        TestSectionView(
            title: "第五層：UI互動測試",
            subtitle: "確保用戶界面響應正確",
            iconName: "iphone",
            accentColor: .pink,
            tests: [
                TestItemModel(
                    title: "錦標賽選擇界面",
                    description: "測試篩選和搜尋功能",
                    iconName: "magnifyingglass",
                    action: { await testRunner.testTournamentSelection() }
                ),
                TestItemModel(
                    title: "排行榜顯示測試",
                    description: "驗證數據展示和互動",
                    iconName: "chart.bar.fill",
                    action: { await testRunner.testRankingsDisplay() }
                ),
                TestItemModel(
                    title: "投資組合查閱測試",
                    description: "驗證投資組合界面顯示和功能",
                    iconName: "chart.pie.fill",
                    action: { await testRunner.testPortfolioView() }
                ),
                TestItemModel(
                    title: "卡片組件測試",
                    description: "檢查卡片狀態和互動",
                    iconName: "rectangle.on.rectangle",
                    action: { await testRunner.testCardComponents() }
                )
            ],
            testRunner: testRunner
        )
    }
    
    // MARK: - 全面測試按鈕
    private var fullTestSection: some View {
        VStack(spacing: 16) {
            Button(action: {
                Task {
                    await testRunner.runFullTestSuite()
                }
            }) {
                HStack {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text("執行完整測試套件")
                            .font(.headline)
                            .fontWeight(.bold)
                        
                        Text("運行所有五層測試，生成完整報告")
                            .font(.caption)
                    }
                    
                    Spacer()
                    
                    if testRunner.isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
                .foregroundColor(.white)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [.blue, .purple]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .disabled(testRunner.isRunning)
            
            // 快速操作按鈕組
            HStack(spacing: 12) {
                Button("重置狀態") {
                    testRunner.resetTestState()
                }
                .buttonStyle(.bordered)
                
                Button("匯出報告") {
                    testRunner.exportTestReport()
                }
                .buttonStyle(.borderedProminent)
                
                Button("查看結果") {
                    showResults = true
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
}

// MARK: - 測試層級枚舉
enum TestLayer: CaseIterable {
    case all, foundation, service, business, integration, ui
    
    var displayName: String {
        switch self {
        case .all: return "全部"
        case .foundation: return "基礎模型"
        case .service: return "服務層"
        case .business: return "業務邏輯"
        case .integration: return "整合測試"
        case .ui: return "UI互動"
        }
    }
    
    var iconName: String {
        switch self {
        case .all: return "square.grid.3x3.fill"
        case .foundation: return "cube.fill"
        case .service: return "server.rack"
        case .business: return "brain.head.profile"
        case .integration: return "link.circle.fill"
        case .ui: return "iphone"
        }
    }
    
    var accentColor: Color {
        switch self {
        case .all: return .primary
        case .foundation: return .blue
        case .service: return .green
        case .business: return .purple
        case .integration: return .orange
        case .ui: return .pink
        }
    }
}

// MARK: - 測試項目模型
struct TestItemModel: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let iconName: String
    let action: () async -> Void
}

// MARK: - 預覽
struct TournamentTestView_Previews: PreviewProvider {
    static var previews: some View {
        TournamentTestView()
    }
}