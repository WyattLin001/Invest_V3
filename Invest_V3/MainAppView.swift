//
//  MainAppView.swift
//  Invest_V2
//
//  Created by 林家麒 on 2025/7/9.
//
import SwiftUI

struct MainAppView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var showConnectionToast = false
    @State private var toastMessage = ""
    
    // 移除不再需要的動畫狀態
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // 已登入：顯示主應用
                ContentView()
                    .environmentObject(authService)
                    .onAppear {
                        print("✅ 用戶已認證，顯示首頁")
                    }
            } else {
                // 未登入：顯示認證畫面
                AuthenticationView()
                    .environmentObject(authService)
            }
        }
        .onAppear {
            checkSupabaseConnection()
        }
        .toast(message: toastMessage, isShowing: $showConnectionToast)
    }
    
    private func checkSupabaseConnection() {
        // Preview 安全檢查
        #if DEBUG
        if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
            print("🔍 Preview 模式：跳過 Supabase 連線檢查")
            return
        }
        #endif
        
        Task {
            do {
                // 確保 Supabase 已初始化
                try await SupabaseManager.shared.initialize()
                
                // 嘗試一個簡單的 health check 查詢
                _ = try await SupabaseService.shared.client.from("user_profiles").select().limit(1).execute()
                
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
