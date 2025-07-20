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
                
                // 真實用戶註冊指引
                VStack(alignment: .leading, spacing: 12) {
                    Text("需要真實註冊的 5 個用戶帳號：")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        realUserRow(name: "test01", email: "test01@example.com", status: "待註冊")
                        realUserRow(name: "test02", email: "test02@example.com", status: "待註冊")
                        realUserRow(name: "test03", email: "test03@example.com", status: "待註冊")
                        realUserRow(name: "test04", email: "test04@example.com", status: "待註冊")
                        realUserRow(name: "test05", email: "test05@example.com", status: "待註冊")
                    }
                    .padding(.leading, 16)
                    
                    Text("註冊步驟：")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.top, 8)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("1. 每個人使用上述 email 進行真實註冊")
                        Text("2. 設定各自的密碼")
                        Text("3. 完成用戶資料設定")
                        Text("4. 開始進行真實交易投資")
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
    
    /// 測試用戶行視圖
    private func realUserRow(name: String, email: String, status: String) -> some View {
        HStack {
            // 用戶圖標
            ZStack {
                Circle()
                    .fill(Color.brandBlue)
                    .frame(width: 24, height: 24)
                
                Image(systemName: "person.fill")
                    .font(.caption)
                    .foregroundColor(.white)
            }
            
            // 用戶資訊
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.body)
                    .fontWeight(.medium)
                
                Text(email)
                    .font(.caption)
                    .foregroundColor(.gray600)
            }
            
            Spacer()
            
            // 狀態
            Text(status)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(8)
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
            // 模擬檢查過程
            await MainActor.run {
                resultMessage = "正在準備真實用戶註冊資訊..."
            }
            
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒
            
            await MainActor.run {
                isSuccess = true
                resultMessage = """
                ✅ 真實用戶註冊指引準備完成！
                
                請讓 5 個真實用戶分別註冊以下帳號：
                
                📧 用戶帳號：
                • test01@example.com
                • test02@example.com  
                • test03@example.com
                • test04@example.com
                • test05@example.com
                
                🔐 每個用戶需要：
                1. 使用對應 email 註冊真實帳號
                2. 設定個人密碼
                3. 完成用戶資料填寫
                4. 開始真實交易投資
                
                ⚠️ 這些將是真實用戶，不是假數據！
                """
                showResult = true
                isInitializing = false
            }
        }
    }
}

#Preview {
    InitializeRankingsDataView()
}