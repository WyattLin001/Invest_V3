import SwiftUI

struct TradingAppView: View {
    @ObservedObject private var tradingService = TradingService.shared
    @State private var showConnectionToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        Group {
            if isUserLoggedIn {
                // 用戶已登入，顯示主要交易介面
                TradingMainView()
                    .environmentObject(tradingService)
            } else {
                // 用戶未登入，顯示認證頁面
                TradingAuthView()
                    .environmentObject(tradingService)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: isUserLoggedIn)
        .onAppear {
            checkAuthStatus()
            testBackendConnection()
        }
        .toast(message: toastMessage, isShowing: $showConnectionToast)
    }
    
    private var isUserLoggedIn: Bool {
        return tradingService.currentUser != nil
    }
    
    private func checkAuthStatus() {
        Task {
            await tradingService.checkAuthStatus()
        }
    }
    
    private func testBackendConnection() {
        Task {
            do {
                // 測試後端健康檢查
                let url = URL(string: "http://localhost:5001/health")!
                let (data, _) = try await URLSession.shared.data(from: url)
                let response = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                
                if let status = response?["status"] as? String, status == "healthy" {
                    await MainActor.run {
                        self.toastMessage = "✅ 後端服務已連線"
                        self.showConnectionToast = true
                    }
                } else {
                    throw URLError(.badServerResponse)
                }
            } catch {
                await MainActor.run {
                    self.toastMessage = "⚠️ 後端服務連線失敗"
                    self.showConnectionToast = true
                }
            }
        }
    }
}

// Toast 功能已在 ToastView.swift 中定義

#Preview {
    TradingAppView()
}