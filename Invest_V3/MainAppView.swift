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
            // 設定初始狀態
            if authService.isAuthenticated {
                // 已登入時，卡片在底部隱藏
                authCardOffset = UIScreen.main.bounds.height
            } else {
                // 未登入時，卡片在屏幕底部準備上升
                authCardOffset = UIScreen.main.bounds.height * 0.8
                
                // 延遲一點讓卡片上升到等待位置
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    withAnimation(.spring(response: 0.8, dampingFraction: 0.9)) {
                        authCardOffset = 0 // 上升到正常位置
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserSignedIn"))) { _ in
            print("📱 收到登入成功通知，卡片向下滑動消失")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                authCardOffset = UIScreen.main.bounds.height // 下降消失
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserLoggedOut"))) { _ in
            print("📱 收到登出通知，卡片從底部向上滑動到等待位置")
            // 首先讓卡片在底部
            authCardOffset = UIScreen.main.bounds.height * 0.8
            
            // 然後向上滑動到等待位置
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                authCardOffset = 0 // 上升到等待位置
            }
        }
        .toast(message: toastMessage, isShowing: $showConnectionToast)
    }
    
    private func checkSupabaseConnection() {
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
