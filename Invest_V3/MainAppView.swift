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
    
    // Card View動畫控制
    @State private var authCardOffset: CGFloat = 0
    
    var body: some View {
        ZStack {
            // 主應用內容 - 當用戶登入時顯示
            if authService.isAuthenticated {
                ContentView()
                    .environmentObject(authService)
                    .onAppear {
                        print("✅ 用戶已認證，顯示首頁")
                    }
            }
            
            // 認證卡片 - 始終存在，通過offset控制位置
            AuthenticationView()
                .environmentObject(authService)
                .offset(y: authCardOffset)
                .opacity(authService.isAuthenticated ? 0 : 1)
        }
        .onAppear {
            checkSupabaseConnection()
            // 簡化初始狀態設定 - 避免動畫衝突
            if authService.isAuthenticated {
                // 已登入時，卡片隱藏
                authCardOffset = 1000
            } else {
                // 未登入時，卡片顯示
                authCardOffset = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserSignedIn"))) { _ in
            print("📱 收到登入成功通知，卡片隱藏")
            withAnimation(.easeOut(duration: 0.3)) {
                authCardOffset = 1000 // 簡單隱藏
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserLoggedOut"))) { _ in
            print("📱 收到登出通知，卡片顯示")
            withAnimation(.easeIn(duration: 0.3)) {
                authCardOffset = 0 // 簡單顯示
            }
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
