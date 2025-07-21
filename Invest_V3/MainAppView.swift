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
    @State private var isTransitioning = false
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                // 用戶已登入，顯示主應用程式內容（預設顯示首頁）
                ContentView()
                    .environmentObject(authService)
                    .onAppear {
                        print("✅ 用戶已認證，顯示首頁")
                    }
            } else {
                // 用戶未登入，顯示登入畫面
                AuthenticationView()
                    .environmentObject(authService)
                    .onAppear {
                        print("📱 顯示登入畫面")
                    }
            }
        }
        .transition(.asymmetric(
            insertion: .move(edge: .bottom).combined(with: .opacity),
            removal: .move(edge: .bottom).combined(with: .opacity)
        ))
        .animation(.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.2), value: authService.isAuthenticated)
        .onAppear(perform: checkSupabaseConnection)
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserSignedIn"))) { _ in
            print("📱 收到登入成功通知，登入卡片將向下滑動關閉")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isTransitioning = true
            }
            // 短暫延遲後重置過渡狀態
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isTransitioning = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserLoggedOut"))) { _ in
            print("📱 收到登出通知，登入卡片將從底部滑入")
            withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                isTransitioning = true
            }
            // 短暫延遲後重置過渡狀態
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                isTransitioning = false
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
