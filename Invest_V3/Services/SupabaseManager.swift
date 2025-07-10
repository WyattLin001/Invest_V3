//
//  SupabaseManager.swift
//  Invest_V2
//
//  Created by 林家麒 on 2025/7/9.
//
import Supabase
import Foundation

@MainActor
class SupabaseManager {
    static let shared = SupabaseManager()

    private(set) var client: SupabaseClient!
    
    // 用於追踪初始化狀態
    private var isInitialized = false

    func initialize() async {
        guard !isInitialized else { return }
        
        let url = URL(string: "https://wujlbjrouqcpnifbakmw.supabase.co")!
        let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MTMxNjcsImV4cCI6MjA2NzM4OTE2N30.2-l82gsxWDLMj3gUnSpj8sHddMLtX-JgqrbnY5c_9bg"

        // 配置客戶端
        self.client = SupabaseClient(
            supabaseURL: url,
            supabaseKey: anonKey
        )
        
        // 添加自定義錯誤處理
        await client.auth.onAuthStateChange { event, session in
            Task { @MainActor in
                if let session = session {
                    print("✅ Auth State Changed: \(event), Session: \(session.accessToken)")
                } else {
                    print("ℹ️ Auth State Changed: \(event), No session")
                }
            }
        }
        
        isInitialized = true
        print("✅ Supabase 初始化成功")
    }
    
    // 清理資源
    func cleanup() {
        // 在需要時清理資源，例如應用退出時
        client = nil
        isInitialized = false
    }
}


