import SwiftUI

/// 初始化排名系統測試資料的視圖
/// 這個視圖用於開發和測試階段，用來清理和創建新的排名測試資料
struct InitializeRankingsDataView: View {
    @State private var isInitializing = false
    @State private var showResult = false
    @State private var resultMessage = ""
    @State private var isSuccess = false
    
    private let supabaseService = SupabaseService.shared
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Spacer()
                
                // 標題和說明
                VStack(spacing: 16) {
                    Image(systemName: "crown.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.brandPrimary)
                    
                    Text("初始化排名系統")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("清理舊的測試資料並創建新的排名用戶資料")
                        .font(.body)
                        .foregroundColor(.gray600)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                // 用戶交易績效設定
                VStack(alignment: .leading, spacing: 12) {
                    Text("將為以下用戶創建交易績效：")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        userPerformanceRow(
                            name: "Wyatt Lin",
                            userId: "1a91110c-4420-4212-9929-06c5b54c585b",
                            returnRate: 10.0,
                            status: "準備創建"
                        )
                    }
                    .padding(.leading, 16)
                    
                    Text("將會創建的資料：")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("• 投資回報率: 10.0%")
                        Text("• 總資產: 110萬 TWD")
                        Text("• 總獲利: 10萬 TWD")
                        Text("• 完整30天績效快照")
                    }
                    .font(.caption)
                    .foregroundColor(.gray600)
                    .padding(.leading, 16)
                }
                .padding()
                .background(Color.gray100)
                .cornerRadius(12)
                
                Spacer()
                
                // 初始化按鈕
                Button(action: initializeData) {
                    HStack {
                        if isInitializing {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                        
                        Text(isInitializing ? "初始化中..." : "開始初始化")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(isInitializing ? Color.gray400 : Color.brandPrimary)
                    .cornerRadius(12)
                }
                .disabled(isInitializing)
                
                // 警告提示
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    
                    Text("此操作將清除所有現有的交易用戶資料")
                        .font(.footnote)
                        .foregroundColor(.orange)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
                
                Spacer()
            }
            .padding()
            .navigationTitle("資料初始化")
            .navigationBarTitleDisplayMode(.inline)
            .alert("初始化結果", isPresented: $showResult) {
                Button("確定") { }
            } message: {
                Text(resultMessage)
            }
        }
    }
    
    /// 用戶績效行視圖
    private func userPerformanceRow(name: String, userId: String, returnRate: Double, status: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // 用戶圖標
                ZStack {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.caption)
                        .foregroundColor(.white)
                }
                
                // 用戶資訊
                VStack(alignment: .leading, spacing: 2) {
                    Text(name)
                        .font(.body)
                        .fontWeight(.semibold)
                    
                    Text("回報率: +\(String(format: "%.1f", returnRate))%")
                        .font(.caption)
                        .foregroundColor(.brandGreen)
                        .fontWeight(.medium)
                }
                
                Spacer()
                
                // 狀態
                Text(status)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.blue)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(8)
            }
            
            // 用戶ID
            Text("ID: \(userId)")
                .font(.caption2)
                .foregroundColor(.gray500)
                .padding(.leading, 40)
        }
        .padding(.vertical, 4)
    }
    
    /// 排名顏色
    private func rankColor(for rank: Int) -> Color {
        switch rank {
        case 1: return Color(hex: "#FFD700") // 金色
        case 2: return Color(hex: "#C0C0C0") // 銀色
        case 3: return Color(hex: "#CD7F32") // 銅色
        default: return .brandPrimary
        }
    }
    
    /// 初始化資料
    private func initializeData() {
        isInitializing = true
        
        Task {
            do {
                // 為當前用戶創建交易績效
                await MainActor.run {
                    resultMessage = "正在為用戶創建交易績效資料..."
                }
                
                // 為用戶 1a91110c-4420-4212-9929-06c5b54c585b 創建 10% 回報率
                try await supabaseService.createUserTradingPerformance(
                    userId: "1a91110c-4420-4212-9929-06c5b54c585b",
                    returnRate: 10.0
                )
                
                await MainActor.run {
                    isSuccess = true
                    resultMessage = """
                    ✅ 用戶交易績效已成功創建！
                    
                    📈 已為用戶創建：
                    • 用戶ID: 1a91110c-4420-4212-9929-06c5b54c585b
                    • 投資回報率: 10.0%
                    • 總資產: 110萬 TWD
                    • 總獲利: 10萬 TWD
                    • 現金餘額: 33萬 TWD
                    
                    🎯 用戶現在會出現在排行榜上！
                    
                    📊 包含完整30天績效快照資料
                    """
                    showResult = true
                    isInitializing = false
                }
                
            } catch {
                await MainActor.run {
                    isSuccess = false
                    resultMessage = "❌ 創建交易績效失敗：\(error.localizedDescription)"
                    showResult = true
                    isInitializing = false
                }
            }
        }
    }
}

#Preview {
    InitializeRankingsDataView()
}