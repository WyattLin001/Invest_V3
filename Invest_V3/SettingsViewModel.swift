import SwiftUI
import Foundation
import PhotosUI


@MainActor
class SettingsViewModel: ObservableObject {
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showImagePicker = false
    @Published var showQRCodeFullScreen = false
    @Published var qrCodeImage: UIImage?
    @Published var profileImage: UIImage?
    @Published var nickname = "投資新手"
    
    // 頭像相關狀態
    @Published var isUploadingAvatar = false
    @Published var uploadProgress: Double = 0.0
    @Published var isLoadingAvatar = false
    // 好友系統
    @Published var friends: [UserProfile] = []
    
    // 設定選項
    @Published var notificationsEnabled = true
    @Published var marketUpdatesEnabled = true
    @Published var chatNotificationsEnabled = true
    @Published var investmentNotificationsEnabled = true
    @Published var isSubscribed = false // 新增訂閱狀態
    
    // 用戶 ID - 從當前用戶獲取或使用預設值
    var userId: String {
        if let currentUser = supabaseService.getCurrentUser() {
            return currentUser.username
        }
        return "USER_\(UUID().uuidString.prefix(8))"
    }
    
    private let supabaseService = SupabaseService.shared
    private let avatarCacheService = AvatarCacheService.shared
    
    // MARK: - 初始化資料
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 載入用戶資料
            try await loadUserProfile()
            generateQRCode()
            
            // 載入通知設定
            await loadNotificationSettings()
            
            // 載入好友列表
            await loadFriends()
            
        } catch {
            errorMessage = "載入資料失敗: \(error.localizedDescription)"
            print("SettingsViewModel loadData error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - 載入用戶資料
    private func loadUserProfile() async throws {
        do {
            // 獲取當前用戶
            guard let currentUser = supabaseService.getCurrentUser() else {
                print("⚠️ [SettingsViewModel] 用戶未登入，使用預設資料")
                // 使用預設資料作為備選
                self.userProfile = UserProfile(
                    id: UUID(),
                    email: "user@example.com",
                    username: "investor123",
                    displayName: "投資達人",
                    avatarUrl: nil,
                    bio: "熱愛投資的新手",
                    userId: UUID().uuidString,
                    createdAt: Date(),
                    updatedAt: Date()
                )
                return
            }
            
            // 從 Supabase 獲取完整的用戶資料
            let userProfileService = UserProfileService.shared
            // 使用 currentUser.id (UUID) 而不是 currentUser.userId (String)
            let fetchedProfile = try await userProfileService.getUserProfile(id: currentUser.id)
            
            await MainActor.run {
                self.userProfile = fetchedProfile
                
                // 如果有頭像URL，嘗試載入頭像
                if let avatarUrlString = fetchedProfile.avatarUrl,
                   let avatarUrl = URL(string: avatarUrlString) {
                    Task {
                        await self.loadAvatarFromURL(avatarUrl)
                    }
                }
            }
            
            print("✅ [SettingsViewModel] 成功載入用戶資料: \(fetchedProfile.displayName)")
            
        } catch {
            print("⚠️ [SettingsViewModel] 載入用戶資料失敗: \(error)")
            // 使用預設資料作為備選
            self.userProfile = UserProfile(
                id: UUID(),
                email: "user@example.com",
                username: "investor123",
                displayName: "投資達人",
                avatarUrl: nil,
                bio: "熱愛投資的新手",
                userId: UUID().uuidString,
                createdAt: Date(),
                updatedAt: Date()
            )
            throw error
        }
    }
    
    // MARK: - 生成 QR Code
    private func generateQRCode() {
        guard let userProfile = userProfile else { return }
        
        let qrString = "investv3://user/\(userProfile.id.uuidString)"
        
        let data = qrString.data(using: String.Encoding.ascii)
        guard let qrFilter = CIFilter(name: "CIQRCodeGenerator") else { return }
        
        qrFilter.setValue(data, forKey: "inputMessage")
        guard let qrImage = qrFilter.outputImage else { return }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledQrImage = qrImage.transformed(by: transform)
        
        let context = CIContext()
        guard let cgImage = context.createCGImage(scaledQrImage, from: scaledQrImage.extent) else { return }
        
        self.qrCodeImage = UIImage(cgImage: cgImage)
    }
    
    // MARK: - 從URL載入頭像
    private func loadAvatarFromURL(_ url: URL) async {
        await MainActor.run {
            self.isLoadingAvatar = true
        }
        
        // 使用快取服務載入頭像
        avatarCacheService.loadAvatar(from: url) { [weak self] image in
            DispatchQueue.main.async {
                self?.profileImage = image
                self?.isLoadingAvatar = false
                
                if image != nil {
                    print("✅ [SettingsViewModel] 成功載入頭像（透過快取服務）")
                } else {
                    print("❌ [SettingsViewModel] 載入頭像失敗")
                }
            }
        }
    }
    
    // MARK: - 處理選中的圖片
    func processSelectedImage(_ image: UIImage) async {
        await MainActor.run {
            self.isUploadingAvatar = true
            self.uploadProgress = 0.0
            self.errorMessage = nil
        }
        
        do {
            // 驗證圖片
            await MainActor.run { self.uploadProgress = 0.1 }
            let validationResult = ImageValidator.validateImage(image)
            guard validationResult.isValid else {
                await MainActor.run {
                    self.errorMessage = validationResult.errorMessage
                    self.isUploadingAvatar = false
                    self.uploadProgress = 0.0
                }
                return
            }
            
            // 裁切並調整圖片大小到 512x512
            await MainActor.run { self.uploadProgress = 0.3 }
            let processedImage = await resizeAndCropImage(image, to: CGSize(width: 512, height: 512))
            
            // 更新 UI
            await MainActor.run {
                self.profileImage = processedImage
                self.uploadProgress = 0.5
            }
            
            // 上傳到後端
            await updateAvatar(image: processedImage)
            
        } catch {
            await MainActor.run {
                self.errorMessage = "處理圖片時發生錯誤: \(error.localizedDescription)"
                self.isUploadingAvatar = false
                self.uploadProgress = 0.0
                print("❌ [SettingsViewModel] 圖片處理失敗: \(error)")
            }
        }
    }
    
    // MARK: - 從 PhotosPicker 載入並處理圖片
    func loadAndProcessImage(from item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                errorMessage = "無法載入選取的圖片"
                return
            }
            
            // 裁切並調整圖片大小到 512x512
            let processedImage = await resizeAndCropImage(image, to: CGSize(width: 512, height: 512))
            
            // 更新 UI
            self.profileImage = processedImage
            
            // 上傳到後端
            await updateAvatar(image: processedImage)
            
        } catch {
            errorMessage = "處理圖片時發生錯誤: \(error.localizedDescription)"
            print("❌ [SettingsViewModel] 圖片處理失敗: \(error)")
        }
    }
    
    // MARK: - 裁切和調整圖片大小
    private func resizeAndCropImage(_ image: UIImage, to size: CGSize) async -> UIImage {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let renderer = UIGraphicsImageRenderer(size: size)
                let resizedImage = renderer.image { context in
                    // 計算裁切區域（保持中央正方形區域）
                    let aspectRatio = image.size.width / image.size.height
                    let targetRect: CGRect
                    
                    if aspectRatio > 1 {
                        // 寬圖：裁切左右
                        let cropWidth = image.size.height
                        let cropX = (image.size.width - cropWidth) / 2
                        let cropRect = CGRect(x: cropX, y: 0, width: cropWidth, height: image.size.height)
                        
                        if let croppedCGImage = image.cgImage?.cropping(to: cropRect) {
                            let croppedImage = UIImage(cgImage: croppedCGImage)
                            croppedImage.draw(in: CGRect(origin: .zero, size: size))
                        } else {
                            image.draw(in: CGRect(origin: .zero, size: size))
                        }
                    } else if aspectRatio < 1 {
                        // 高圖：裁切上下
                        let cropHeight = image.size.width
                        let cropY = (image.size.height - cropHeight) / 2
                        let cropRect = CGRect(x: 0, y: cropY, width: image.size.width, height: cropHeight)
                        
                        if let croppedCGImage = image.cgImage?.cropping(to: cropRect) {
                            let croppedImage = UIImage(cgImage: croppedCGImage)
                            croppedImage.draw(in: CGRect(origin: .zero, size: size))
                        } else {
                            image.draw(in: CGRect(origin: .zero, size: size))
                        }
                    } else {
                        // 正方形：直接縮放
                        image.draw(in: CGRect(origin: .zero, size: size))
                    }
                }
                
                DispatchQueue.main.async {
                    continuation.resume(returning: resizedImage)
                }
            }
        }
    }
    
    // MARK: - 更新頭像
    func updateAvatar(image: UIImage) async {
        do {
            // 轉換圖片為 JPEG 格式 (品質 0.8)
            await MainActor.run { self.uploadProgress = 0.6 }
            guard let imageData = image.jpegData(compressionQuality: 0.8) else {
                await MainActor.run {
                    self.errorMessage = "無法轉換圖片格式"
                    self.isUploadingAvatar = false
                    self.uploadProgress = 0.0
                }
                return
            }
            
            print("✅ [SettingsViewModel] 頭像已處理，大小: \(imageData.count) bytes")
            print("✅ [SettingsViewModel] 圖片尺寸: \(image.size)")
            
            // 實際上傳到 Supabase Storage
            await MainActor.run { self.uploadProgress = 0.8 }
            do {
                let fileName = "avatar_\(userId)_\(Date().timeIntervalSince1970).jpg"
                let avatarUrl = try await supabaseService.uploadAvatar(imageData, fileName: fileName)
                
                await MainActor.run { self.uploadProgress = 0.9 }
                await updateUserProfileAvatar(avatarUrl: avatarUrl)
                
                await MainActor.run {
                    self.uploadProgress = 1.0
                    self.isUploadingAvatar = false
                }
                
                print("✅ [SettingsViewModel] 頭像上傳成功: \(avatarUrl)")
            } catch {
                print("⚠️ [SettingsViewModel] 頭像上傳失敗，僅保存本地: \(error)")
                await MainActor.run {
                    self.errorMessage = "頭像上傳失敗: \(error.localizedDescription)"
                    self.isUploadingAvatar = false
                    self.uploadProgress = 0.0
                }
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = "更新頭像失敗: \(error.localizedDescription)"
                self.isUploadingAvatar = false
                self.uploadProgress = 0.0
            }
            print("❌ [SettingsViewModel] 頭像上傳失敗: \(error)")
        }
    }
    
    // MARK: - 更新用戶頭像URL
    private func updateUserProfileAvatar(avatarUrl: String) async {
        do {
            // 確保有用戶資料
            guard let currentProfile = userProfile else {
                await MainActor.run {
                    self.errorMessage = "用戶資料不存在，無法更新頭像"
                }
                return
            }
            
            // 實際更新到 Supabase user_profiles 表
            let userProfileService = UserProfileService.shared
            let updatedProfile = try await userProfileService.updateUserProfile(
                id: currentProfile.id,
                username: nil,
                displayName: nil,
                avatarUrl: avatarUrl
            )
            
            // 更新本地用戶資料
            await MainActor.run {
                self.userProfile = updatedProfile
            }
            
            print("✅ [SettingsViewModel] 用戶頭像URL已更新: \(avatarUrl)")
            print("✅ [SettingsViewModel] 後端同步成功")
            
        } catch {
            await MainActor.run {
                self.errorMessage = "更新用戶頭像失敗: \(error.localizedDescription)"
            }
            print("❌ [SettingsViewModel] 頭像URL更新失敗: \(error)")
        }
    }
    
    // MARK: - 更新個人資料
    func updateProfile(displayName: String, bio: String) async {
        do {
            // 實際實現會更新到 Supabase
            self.userProfile?.displayName = displayName
            self.userProfile?.bio = bio
            
            print("更新個人資料")
            
        } catch {
            errorMessage = "更新個人資料失敗: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 登出
    func signOut() async {
        do {
            // 實際實現會調用 AuthenticationService
            print("登出")
            
        } catch {
            errorMessage = "登出失敗: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 切換通知設定
    func toggleNotifications(_ enabled: Bool) {
        notificationsEnabled = enabled
        Task {
            await syncNotificationSettings()
        }
    }
    
    func toggleMarketUpdates(_ enabled: Bool) {
        marketUpdatesEnabled = enabled
        Task {
            await syncNotificationSettings()
        }
    }
    
    func toggleChatNotifications(_ enabled: Bool) {
        chatNotificationsEnabled = enabled
        Task {
            await syncNotificationSettings()
        }
    }
    
    func toggleInvestmentNotifications(_ enabled: Bool) {
        investmentNotificationsEnabled = enabled
        Task {
            await syncNotificationSettings()
        }
    }
    
    // MARK: - 同步通知設定到後端
    private func syncNotificationSettings() async {
        do {
            guard let user = try? await supabaseService.client.auth.user() else {
                print("⚠️ [SettingsViewModel] 用戶未登入，將設定保存到本地")
                saveNotificationSettingsLocally()
                return
            }
            
            // 創建可編碼的結構體
            struct NotificationSettingsInsert: Codable {
                let user_id: String
                let push_notifications_enabled: Bool
                let market_updates_enabled: Bool
                let chat_notifications_enabled: Bool
                let investment_notifications_enabled: Bool
                let ranking_updates_enabled: Bool
                let host_messages_enabled: Bool
                let stock_price_alerts_enabled: Bool
                let updated_at: String
            }
            
            let notificationSettings = NotificationSettingsInsert(
                user_id: user.id.uuidString,
                push_notifications_enabled: notificationsEnabled,
                market_updates_enabled: marketUpdatesEnabled,
                chat_notifications_enabled: chatNotificationsEnabled,
                investment_notifications_enabled: investmentNotificationsEnabled,
                ranking_updates_enabled: true,
                host_messages_enabled: true,
                stock_price_alerts_enabled: true,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            // 上傳到 Supabase (使用 upsert 來處理插入或更新)
            try await supabaseService.client
                .from("notification_settings")
                .upsert(notificationSettings)
                .execute()
            
            print("✅ [SettingsViewModel] 通知設定已同步到後端")
            
            // 同時保存到本地作為備份
            saveNotificationSettingsLocally()
            
        } catch {
            errorMessage = "同步通知設定失敗: \(error.localizedDescription)"
            print("❌ [SettingsViewModel] 通知設定同步失敗: \(error)")
            
            // 失敗時保存到本地
            saveNotificationSettingsLocally()
        }
    }
    
    // MARK: - 本地保存通知設定
    private func saveNotificationSettingsLocally() {
        let settings = [
            "notifications_enabled": notificationsEnabled,
            "market_updates_enabled": marketUpdatesEnabled,
            "chat_notifications_enabled": chatNotificationsEnabled,
            "investment_notifications_enabled": investmentNotificationsEnabled
        ]
        
        UserDefaults.standard.set(settings, forKey: "notification_settings")
        print("✅ [SettingsViewModel] 通知設定已保存到本地")
    }
    
    // MARK: - 載入通知設定
    private func loadNotificationSettings() async {
        do {
            guard let user = try? await supabaseService.client.auth.user() else {
                // 用戶未登入，從本地載入
                loadNotificationSettingsLocally()
                return
            }
            
            // 從 Supabase 載入設定 (使用新的表格結構)
            let result = try await supabaseService.client
                .from("notification_settings")
                .select("push_notifications_enabled, market_updates_enabled, chat_notifications_enabled, investment_notifications_enabled, ranking_updates_enabled, host_messages_enabled, stock_price_alerts_enabled")
                .eq("user_id", value: user.id.uuidString)
                .limit(1)
                .execute()
            
            // 手動解析 JSON 響應 - 直接使用 Data
            do {
                let decoder = JSONDecoder()
                let settingsArray = try decoder.decode([[String: Bool]].self, from: result.data)
                
                if let setting = settingsArray.first {
                    // 更新本地狀態
                    await MainActor.run {
                        self.notificationsEnabled = setting["push_notifications_enabled"] ?? true
                        self.marketUpdatesEnabled = setting["market_updates_enabled"] ?? true
                        self.chatNotificationsEnabled = setting["chat_notifications_enabled"] ?? true
                        self.investmentNotificationsEnabled = setting["investment_notifications_enabled"] ?? true
                    }
                    
                    print("✅ [SettingsViewModel] 已從後端載入通知設定")
                } else {
                    // 後端沒有設定，使用本地設定或預設值
                    loadNotificationSettingsLocally()
                }
            } catch {
                print("❌ [SettingsViewModel] JSON 解析失敗: \(error)")
                loadNotificationSettingsLocally()
            }
            
        } catch {
            print("❌ [SettingsViewModel] 載入通知設定失敗: \(error)")
            print("ℹ️ [SettingsViewModel] 使用預設通知設定")
            loadNotificationSettingsLocally()
        }
    }
    
    // MARK: - 本地載入通知設定
    private func loadNotificationSettingsLocally() {
        if let settings = UserDefaults.standard.dictionary(forKey: "notification_settings") {
            notificationsEnabled = settings["notifications_enabled"] as? Bool ?? true
            marketUpdatesEnabled = settings["market_updates_enabled"] as? Bool ?? true
            chatNotificationsEnabled = settings["chat_notifications_enabled"] as? Bool ?? true
            investmentNotificationsEnabled = settings["investment_notifications_enabled"] as? Bool ?? true
            
            print("✅ [SettingsViewModel] 已從本地載入通知設定")
        } else {
            // 使用預設值
            print("ℹ️ [SettingsViewModel] 使用預設通知設定")
        }
    }
    
    // MARK: - 好友系統方法
    
    /// 載入好友列表
    private func loadFriends() async {
        do {
            let friendsList = try await supabaseService.fetchFriendList()
            await MainActor.run {
                self.friends = friendsList
            }
            print("✅ [SettingsViewModel] 已載入 \(friendsList.count) 位好友")
        } catch {
            print("❌ [SettingsViewModel] 載入好友列表失敗: \(error)")
            await MainActor.run {
                self.friends = []
            }
        }
    }
    
    /// 刷新好友列表
    func refreshFriends() async {
        await loadFriends()
    }
    
} 
