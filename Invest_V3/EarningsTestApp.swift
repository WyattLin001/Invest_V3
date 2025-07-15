import SwiftUI

// 獨立的測試應用，專門用於測試創作者收益功能
struct EarningsTestApp: View {
    var body: some View {
        AuthorEarningsView()
    }
}

// 如果你想在 Preview 中快速測試
struct EarningsTestApp_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 正常模式
            EarningsTestApp()
                .previewDisplayName("Normal")
            
            // 深色模式
            EarningsTestApp()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark Mode")
            
            // 載入狀態測試
            AuthorEarningsView()
                .onAppear {
                    // 模擬載入狀態
                }
                .previewDisplayName("Loading State")
        }
    }
}

// MARK: - 測試用的模擬數據視圖
struct EarningsTestWithMockData: View {
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("創作者收益測試")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("這裡可以測試不同的收益狀態")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                // 測試按鈕
                VStack(spacing: 16) {
                    NavigationLink("測試正常收益") {
                        AuthorEarningsView()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    NavigationLink("測試載入狀態") {
                        LoadingEarningsView()
                    }
                    .buttonStyle(.bordered)
                    
                    NavigationLink("測試錯誤狀態") {
                        ErrorEarningsView()
                    }
                    .buttonStyle(.bordered)
                }
                
                Spacer()
            }
            .padding()
        }
    }
}

// 載入狀態測試視圖
struct LoadingEarningsView: View {
    @StateObject private var viewModel = LoadingEarningsViewModel()
    
    var body: some View {
        AuthorEarningsView()
            .environmentObject(viewModel)
    }
}

// 錯誤狀態測試視圖
struct ErrorEarningsView: View {
    @StateObject private var viewModel = ErrorEarningsViewModel()
    
    var body: some View {
        AuthorEarningsView()
            .environmentObject(viewModel)
    }
}

// 測試用的 ViewModel - 載入狀態
class LoadingEarningsViewModel: AuthorEarningsViewModel {
    override init() {
        super.init()
        self.isLoading = true
    }
}

// 測試用的 ViewModel - 錯誤狀態
class ErrorEarningsViewModel: AuthorEarningsViewModel {
    override init() {
        super.init()
        self.hasError = true
    }
}