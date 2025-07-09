//
//  MainAppView.swift
//  Invest_V2
//
//  Created by 林家麒 on 2025/7/9.
//
import SwiftUI

struct MainAppView: View {
    @StateObject private var authService = AuthenticationService()
    @State private var showConnectionToast = false
    @State private var toastMessage = ""
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // 用戶已登入，顯示主應用程式內容
                ContentView()
                    .environmentObject(authService)
            } else {
                // 用戶未登入，顯示登入畫面
                AuthenticationView()
                    .environmentObject(authService)
            }
        }
        .animation(.easeInOut(duration: 0.3), value: authService.isAuthenticated)
        .onAppear(perform: checkSupabaseConnection)
        .toast(message: toastMessage, isShowing: $showConnectionToast)
    }
    
    private func checkSupabaseConnection() {
        Task {
            do {
                // 嘗試一個簡單的 health check 查詢
                _ = try await SupabaseService.shared.client.database.from("user_profiles").select().limit(1).execute()
                
                // 連線成功
                await MainActor.run {
                    self.toastMessage = "✅ 已連線"
                    self.showConnectionToast = true
                }
            } catch {
                // 連線失敗
                await MainActor.run {
                    self.toastMessage = "❌ 連線失敗: \(error.localizedDescription)"
                    self.showConnectionToast = true
                }
            }
        }
    }
}

#Preview {
    MainAppView()
}
