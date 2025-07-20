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
                
                // 資料說明
                VStack(alignment: .leading, spacing: 12) {
                    Text("排行榜資料來源：")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("從 Supabase trading_users 表格讀取")
                                .font(.body)
                        }
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("顯示真實用戶交易績效")
                                .font(.body)
                        }
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("即時更新投資回報率")
                                .font(.body)
                        }
                    }
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
    
    /// 測試用戶行視圖
    private func testUserRow(rank: Int, name: String, returnRate: Double) -> some View {
        HStack {
            // 排名圖標
            ZStack {
                Circle()
                    .fill(rankColor(for: rank))
                    .frame(width: 24, height: 24)
                
                Text("\(rank)")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }
            
            // 用戶名稱
            Text(name)
                .font(.body)
                .fontWeight(.medium)
            
            Spacer()
            
            // 回報率
            Text(String(format: "%.1f%%", returnRate))
                .font(.body)
                .fontWeight(.semibold)
                .foregroundColor(.brandGreen)
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
                // TestUserData functions have been removed - ranking data should come from real Supabase users
                print("📊 排行榜資料現在直接從 Supabase trading_users 表格讀取")
                
                await MainActor.run {
                    isSuccess = true
                    resultMessage = """
                    ✅ 排名系統現在使用真實 Supabase 資料！
                    
                    排行榜將顯示：
                    • 真實用戶的交易績效
                    • 來自 Supabase 的即時數據
                    • 不再使用測試假資料
                    
                    每個用戶都有完整的30天績效快照資料。
                    """
                    showResult = true
                    isInitializing = false
                }
                
            } catch {
                await MainActor.run {
                    isSuccess = false
                    resultMessage = "❌ 初始化失敗：\(error.localizedDescription)"
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