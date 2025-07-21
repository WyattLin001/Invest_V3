import Foundation
import Supabase

@MainActor
class AuthenticationService: ObservableObject {
    static let shared = AuthenticationService()
    
    @Published var session: Session?
    @Published var currentUserProfile: UserProfile?
    @Published var isLoading = false
    @Published var error: String?

    var isAuthenticated: Bool {
        return session != nil
    }
    
    // 為了兼容性，添加 currentUser 屬性
    var currentUser: UserProfile? {
        return currentUserProfile
    }

    private var client: SupabaseClient {
        SupabaseManager.shared.client
    }

    private init() {
        Task {
            do {
                try await SupabaseManager.shared.initialize()
                for await state in self.client.auth.authStateChanges {
                    self.session = state.session
                    if let user = state.session?.user {
                        await self.fetchUserProfile(for: user)
                    } else {
                        self.currentUserProfile = nil
                    }
                }
            } catch {
                print("❌ AuthenticationService 初始化失敗: \(error.localizedDescription)")
                self.error = SupabaseError.from(error).localizedDescription
            }
        }
    }

    // MARK: - 標準用戶註冊
    func registerUser(email: String, password: String, username: String, displayName: String) async throws {
        guard !email.isEmpty, !password.isEmpty, !username.isEmpty else {
            let error = SupabaseError.invalidInput("所有必填欄位")
            self.error = error.localizedDescription
            throw error
        }
        
        // 確保 Supabase 已初始化
        try SupabaseManager.shared.ensureInitialized()
        
        isLoading = true
        defer { isLoading = false }
        error = nil

        do {
            // 1. 在 Supabase Auth 中註冊用戶
            let authResponse = try await client.auth.signUp(
                email: email,
                password: password
            )

            // signUp 成功後，user 物件是非可選的，直接賦值即可
            let user = authResponse.user
            
            print("✅ Supabase Auth user created with id: \(user.id)")

            // 2. 創建 UserProfile
            let profile = UserProfile(
                id: UUID(uuidString: user.id.uuidString) ?? UUID(),
                email: email,
                username: username,
                displayName: displayName,
                avatarUrl: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // 3. 創建用於資料庫的結構體（使用 String ID）
            struct UserProfileInsert: Codable {
                let id: String
                let email: String
                let username: String
                let display_name: String
                let avatar_url: String?
                let created_at: String
                let updated_at: String
            }
            
            let dbProfile = UserProfileInsert(
                id: user.id.uuidString,
                email: email,
                username: username,
                display_name: displayName,
                avatar_url: nil,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // 將 Profile 插入資料庫
            try await client
                .from("user_profiles")
                .insert(dbProfile)
                .execute()

            print("✅ User profile created for \(username)")
            
            // 手動登入以觸發 session 更新並自動跳轉到主頁面
            try await signIn(email: email, password: password)
            print("✅ 註冊成功，正在跳轉到首頁...")
            
        } catch {
            print("❌ 註冊失敗: \(error.localizedDescription)")
            let supabaseError = SupabaseError.from(error)
            self.error = supabaseError.localizedDescription
            throw supabaseError
        }
    }

    // MARK: - 標準用戶登入
    func signIn(email: String, password: String) async throws {
        guard !email.isEmpty, !password.isEmpty else {
            let error = SupabaseError.invalidInput("Email 和密碼")
            self.error = error.localizedDescription
            throw error
        }
        
        // 確保 Supabase 已初始化
        try SupabaseManager.shared.ensureInitialized()
        
        isLoading = true
        defer { isLoading = false }
        error = nil
        
        do {
            try await client.auth.signIn(email: email, password: password)
            print("✅ 登入成功: \(email)")
            
            // 登入成功後發送通知確保立即跳轉
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("UserSignedIn"), object: nil)
            }
        } catch {
            print("❌ 登入失敗: \(error.localizedDescription)")
            let supabaseError = SupabaseError.from(error)
            self.error = supabaseError.localizedDescription
            throw supabaseError
        }
    }

    // MARK: - 登出
    func signOut() async {
        isLoading = true
        defer { isLoading = false }
        error = nil
        
        do {
            // 確保 Supabase 已初始化
            try SupabaseManager.shared.ensureInitialized()
            
            try await client.auth.signOut()
            
            // 清除本地用戶資料
            self.currentUserProfile = nil
            UserDefaults.standard.removeObject(forKey: "current_user")
            
            print("✅ 用戶登出，跳轉到登入畫面")
            
            // 發送通知確保跳轉到登入畫面
            await MainActor.run {
                NotificationCenter.default.post(name: NSNotification.Name("UserLoggedOut"), object: nil)
            }
        } catch {
            print("❌ 登出失敗: \(error.localizedDescription)")
            let supabaseError = SupabaseError.from(error)
            self.error = supabaseError.localizedDescription
        }
    }
    
    // MARK: - 獲取用戶資料
    func fetchUserProfile(for user: User) async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let profiles: [UserProfile] = try await client
                .from("user_profiles")
                .select()
                .eq("id", value: user.id)
                .limit(1)
                .execute()
                .value
            
            if let profile = profiles.first {
                self.currentUserProfile = profile
                
                // 將用戶資料保存到 UserDefaults 供 SupabaseService 使用
                if let data = try? JSONEncoder().encode(profile) {
                    UserDefaults.standard.set(data, forKey: "current_user")
                }
                
                print("👤 用戶: \(profile.username) (ID: \(profile.id.uuidString.prefix(8))...)")
            } else {
                print("⚠️ 未找到用戶 \(user.id) 的個人資料，嘗試創建...")
                // 為現有用戶創建 profile
                await createMissingUserProfile(for: user)
            }
        } catch {
            print("❌ 獲取用戶資料失敗: \(error.localizedDescription)")
            // 清除 UserDefaults 中的舊資料
            UserDefaults.standard.removeObject(forKey: "current_user")
        }
    }
    
    // MARK: - 為現有用戶創建缺失的 Profile
    private func createMissingUserProfile(for user: User) async {
        do {
            // 從 email 提取用戶名
            let email = user.email ?? "unknown@example.com"
            let username = String(email.split(separator: "@").first ?? "unknown")
            let displayName = username.capitalized
            
            let profile = UserProfile(
                id: UUID(uuidString: user.id.uuidString) ?? UUID(),
                email: email,
                username: username,
                displayName: displayName,
                avatarUrl: nil,
                createdAt: Date(),
                updatedAt: Date()
            )
            
            // 創建用於資料庫的結構體（使用 String ID）
            struct UserProfileInsert: Codable {
                let id: String
                let email: String
                let username: String
                let display_name: String
                let avatar_url: String?
                let created_at: String
                let updated_at: String
            }
            
            let dbProfile = UserProfileInsert(
                id: user.id.uuidString,
                email: email,
                username: username,
                display_name: displayName,
                avatar_url: nil,
                created_at: ISO8601DateFormatter().string(from: Date()),
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // 插入到 user_profiles 表格
            try await client
                .from("user_profiles")
                .insert(dbProfile)
                .execute()
            
            // 設置為當前用戶
            self.currentUserProfile = profile
            
            // 保存到 UserDefaults
            if let data = try? JSONEncoder().encode(profile) {
                UserDefaults.standard.set(data, forKey: "current_user")
            }
            
            print("✅ 已為用戶 \(username) 創建缺失的 Profile")
            
        } catch {
            print("❌ 創建用戶 Profile 失敗: \(error.localizedDescription)")
            self.error = "無法創建用戶資料: \(error.localizedDescription)"
        }
    }

    // MARK: - 更新用戶資料
    func updateUserProfile(displayName: String, avatarUrl: String? = nil) async throws {
        
        isLoading = true
        defer { isLoading = false }
        error = nil
        
        do {
            // 1. 從 Supabase Auth 獲取當前登入的 User
            guard let user = try? await client.auth.user() else {
                throw SupabaseError.notAuthenticated
            }
            
            // 2. 獲取對應的 UserProfile
            guard var profileToUpdate = currentUserProfile, profileToUpdate.id == user.id else {
                throw SupabaseError.userNotFound
            }

            // 3. 更新本地 profile 物件
            profileToUpdate.displayName = displayName
            profileToUpdate.avatarUrl = avatarUrl ?? profileToUpdate.avatarUrl
            profileToUpdate.updatedAt = Date()
            
            // 4. 將更新後的 profile 寫回資料庫
            try await client
                .from("user_profiles")
                .update(profileToUpdate)
                .eq("id", value: user.id)
                .execute()

            // 5. 更新本地發布的屬性以刷新 UI
            self.currentUserProfile = profileToUpdate
            print("✅ 用戶資料更新成功")

        } catch {
            self.error = error.localizedDescription
            print("❌ 更新失敗: \(error)")
            throw error
        }
    }
}

// MARK: - Legacy AuthError 已移除
// 現在統一使用 SupabaseError 進行錯誤處理
