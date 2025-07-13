import SwiftUI
import Foundation

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
    @Published var friends: [Friend] = []
    
    // 設定選項
    @Published var notificationsEnabled = true
    @Published var marketUpdatesEnabled = true
    @Published var chatNotificationsEnabled = true
    @Published var investmentNotificationsEnabled = true
    @Published var isDarkMode = false
    @Published var darkModeEnabled = false
    @Published var selectedLanguage = "zh-Hant"
    @Published var isSubscribed = false // 新增訂閱狀態
    
    // 用戶 ID
    let userId = "USER_\(UUID().uuidString.prefix(8))"
    
    private let supabaseService = SupabaseService.shared
    
    // MARK: - 初始化資料
    func loadData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            // 載入用戶資料
            try await loadUserProfile()
            generateQRCode()
            
        } catch {
            errorMessage = "載入資料失敗: \(error.localizedDescription)"
            print("SettingsViewModel loadData error: \(error)")
        }
        
        isLoading = false
    }
    
    // MARK: - 載入用戶資料
    private func loadUserProfile() async throws {
        // 模擬資料，實際應該從 Supabase 獲取
        self.userProfile = UserProfile(
            id: UUID(),
            email: "user@example.com",
            username: "investor123",
            displayName: "投資達人",
            avatarUrl: nil,
            bio: "熱愛投資的新手",
            createdAt: Date(),
            updatedAt: Date()
        )
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
    
    // MARK: - 更新頭像
    func updateAvatar(image: UIImage) async {
        do {
            // 實際實現會上傳到 Supabase Storage
            print("更新頭像")
            
        } catch {
            errorMessage = "更新頭像失敗: \(error.localizedDescription)"
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
        // 實際實現會保存到 UserDefaults 或 Supabase
        print("通知設定: \(enabled)")
    }
    
    func toggleMarketUpdates(_ enabled: Bool) {
        marketUpdatesEnabled = enabled
        print("市場更新通知: \(enabled)")
    }
    
    func toggleChatNotifications(_ enabled: Bool) {
        chatNotificationsEnabled = enabled
        print("聊天通知: \(enabled)")
    }
    
    // MARK: - 切換深色模式
    func toggleDarkMode(_ enabled: Bool) {
        isDarkMode = enabled
        // 實際實現會更新系統外觀
        print("深色模式: \(enabled)")
    }
    
    // MARK: - 切換語言
    func changeLanguage(_ language: String) {
        selectedLanguage = language
        // 實際實現會更新應用語言
        print("語言設定: \(language)")
    }
}

// MARK: - 語言選項
struct LanguageOption: Identifiable {
    let id = UUID()
    let code: String
    let name: String
    
    static let options = [
        LanguageOption(code: "zh-Hant", name: "繁體中文"),
        LanguageOption(code: "en", name: "English")
    ]
} 