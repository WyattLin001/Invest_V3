//
//  SupabaseManager.swift
//  Invest_V3
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
    private var _isInitialized = false
    private var initializationTask: Task<Void, Error>?
    
    // 初始化狀態檢查
    var isInitialized: Bool {
        return _isInitialized && client != nil
    }
    
    private init() {}

    /// 執行初始化 - 只會執行一次，多次呼叫會等待同一個初始化任務完成
    func initialize() async throws {
        // 如果已經初始化，直接返回
        if isInitialized {
            return
        }
        
        // 如果正在初始化，等待該任務完成
        if let existingTask = initializationTask {
            try await existingTask.value
            return
        }
        
        // 創建新的初始化任務
        initializationTask = Task {
            try await performInitialization()
        }
        
        // 等待初始化完成
        try await initializationTask!.value
    }
    
    /// 實際執行初始化的私有方法
    private func performInitialization() async throws {
        guard !_isInitialized else { return }
        
        do {
            let url = URL(string: "https://wujlbjrouqcpnifbakmw.supabase.co")!
            let anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MTMxNjcsImV4cCI6MjA2NzM4OTE2N30.2-l82gsxWDLMj3gUnSpj8sHddMLtX-JgqrbnY5c_9bg"

            // 配置客戶端
            self.client = SupabaseClient(
                supabaseURL: url,
                supabaseKey: anonKey
            )
            
            // 添加認證狀態監聽
            await client.auth.onAuthStateChange { event, session in
                Task { @MainActor in
                    if let session = session {
                        print("✅ Auth State Changed: \(event)")
                    } else {
                        print("ℹ️ Auth State Changed: \(event), No session")
                    }
                }
            }
            
            _isInitialized = true
            initializationTask = nil
            print("✅ Supabase 初始化成功")
            
        } catch {
            _isInitialized = false
            initializationTask = nil
            print("❌ Supabase 初始化失敗: \(error.localizedDescription)")
            throw SupabaseError.initializationFailed(error.localizedDescription)
        }
    }
    
    /// 確保已初始化，如果沒有則拋出錯誤
    func ensureInitialized() throws {
        guard isInitialized else {
            throw SupabaseError.notInitialized
        }
    }
    
    /// 異步確保已初始化，如果沒有則等待初始化完成
    func ensureInitializedAsync() async throws {
        if !isInitialized {
            try await initialize()
        }
    }
    
    // 清理資源
    func cleanup() {
        // 在需要時清理資源，例如應用退出時
        client = nil
        _isInitialized = false
        initializationTask?.cancel()
        initializationTask = nil
    }
    
    // MARK: - 圖片上傳功能
    func uploadImage(
        data: Data,
        fileName: String,
        onProgress: @escaping (Double) -> Void = { _ in }
    ) async throws -> URL {
        // 確保已初始化
        try ensureInitialized()
        
        do {
            // 創建存儲路徑
            let path = "\(fileName)"
            
            // 上傳到 Supabase Storage
            let _ = try await client.storage
                .from("article-images")
                .upload(
                    path: path,
                    file: data,
                    options: FileOptions(
                        contentType: "image/jpeg"
                    )
                )
            
            // 獲取公開 URL
            let url = try client.storage
                .from("article-images")
                .getPublicURL(path: path)
            
            onProgress(1.0) // 完成
            return url
            
        } catch {
            throw SupabaseError.from(error)
        }
    }
}


