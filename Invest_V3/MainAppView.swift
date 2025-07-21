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
    @State private var authCardVisible = true
    
    var body: some View {
        ZStack {
            // 主應用內容 - 始終存在但只有在認證時才可見
            if authService.isAuthenticated {
                ContentView()
                    .environmentObject(authService)
                    .onAppear {
                        print("✅ 用戶已認證，顯示首頁")
                    }
            }
            
            // 認證卡片 - 通過offset控制位置
            if authCardVisible || !authService.isAuthenticated {
                AuthenticationView()
                    .environmentObject(authService)
                    .offset(y: authCardOffset)
                    .onAppear {
                        print("📱 認證卡片準備就緒")
                        // 初始位置調整
                        if authService.isAuthenticated {
                            // 如果已經登入，卡片應該在屏幕下方隱藏
                            authCardOffset = UIScreen.main.bounds.height
                            authCardVisible = false
                        } else {
                            // 未登入時，卡片在正常位置
                            authCardOffset = 0
                            authCardVisible = true
                        }
                    }
            }
        }
        .onAppear(perform: checkSupabaseConnection)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserSignedIn"))) { _ in
            print("📱 收到登入成功通知，卡片向下滑動消失")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                authCardOffset = UIScreen.main.bounds.height // 向下滑動到屏幕外
            }
            // 動畫完成後隱藏卡片
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                authCardVisible = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserLoggedOut"))) { _ in
            print("📱 收到登出通知，卡片向上滑動到等待位置")
            // 先顯示卡片
            authCardVisible = true
            
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                authCardOffset = 0 // 向上滑動到正常位置（等待登入）
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
