import SwiftUI
import PhotosUI
import UIKit

@MainActor
class CreateGroupViewModel: ObservableObject {
    // MARK: - Published Properties
    @Published var groupName = ""
    @Published var groupRules = ""
    @Published var entryFee: Double = 0
    @Published var selectedAvatarImage: UIImage?
    
    // MARK: - Validation States
    @Published var groupNameError = ""
    @Published var groupRulesError = ""
    @Published var isFormValid = false
    
    // MARK: - UI States
    @Published var isCreating = false
    @Published var showError = false
    @Published var showSuccess = false
    @Published var errorMessage = ""
    @Published var showSuccessAnimation = false
    
    // MARK: - Host Information
    var hostName: String {
        return AuthenticationService.shared.currentUser?.displayName ?? "未知用戶"
    }
    
    private let supabaseService = SupabaseService.shared
    
    init() {
        validateForm()
    }
    
    // MARK: - Form Validation
    func validateForm() {
        validateGroupName()
        validateGroupRules()
        updateFormValidation()
    }
    
    private func validateGroupName() {
        groupNameError = ""
        
        if groupName.isEmpty {
            groupNameError = "請輸入群組名稱"
        } else if groupName.count < 2 {
            groupNameError = "群組名稱至少需要2個字元"
        } else if groupName.count > 30 {
            groupNameError = "群組名稱不能超過30個字元"
        }
    }
    
    private func validateGroupRules() {
        groupRulesError = ""
        
        if groupRules.isEmpty {
            groupRulesError = "請輸入群組規則"
        } else if groupRules.count < 10 {
            groupRulesError = "群組規則至少需要10個字元"
        } else if groupRules.count > 500 {
            groupRulesError = "群組規則不能超過500個字元"
        }
    }
    
    private func updateFormValidation() {
        isFormValid = groupNameError.isEmpty && 
                     groupRulesError.isEmpty && 
                     !groupName.isEmpty && 
                     !groupRules.isEmpty
    }
    
    // MARK: - Image Handling
    func loadSelectedImage(from photosPickerItem: PhotosPickerItem) async {
        do {
            if let data = try await photosPickerItem.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                self.selectedAvatarImage = uiImage
                print("✅ 成功載入群組頭像")
            }
        } catch {
            print("❌ 載入圖片失敗: \(error)")
            await showErrorMessage("載入圖片失敗，請重試")
        }
    }
    
    // MARK: - Group Creation
    func createGroup() async {
        guard isFormValid else { 
            await showErrorMessage("請完整填寫所有必填欄位")
            return 
        }
        
        isCreating = true
        
        do {
            // 檢查用戶登入狀態
            guard let currentUser = supabaseService.getCurrentUser() else {
                await showErrorMessage("請先登入後再創建群組")
                isCreating = false
                return
            }
            
            print("📝 開始創建群組: \(groupName), 主持人: \(currentUser.displayName)")
            
            // 檢查群組名稱是否重複
            if try await isGroupNameTaken(groupName) {
                await showErrorMessage("群組名稱已存在，請選擇其他名稱")
                isCreating = false
                return
            }
            
            // 創建群組
            let group = try await supabaseService.createInvestmentGroup(
                name: groupName,
                rules: groupRules,
                entryFee: Int(entryFee),
                category: "一般投資",
                avatarImage: selectedAvatarImage
            )
            
            print("✅ 群組創建成功: \(group.name), ID: \(group.id)")
            
            // 成功處理 - 直接進入聊天畫面
            await handleCreationSuccess(groupId: group.id)
            
        } catch {
            print("❌ 創建群組失敗: \(error)")
            await handleCreationError(error)
        }
        
        isCreating = false
    }
    
    // MARK: - Helper Methods
    private func isGroupNameTaken(_ name: String) async throws -> Bool {
        // 檢查是否有同名群組存在
        let existingGroups = try await supabaseService.fetchInvestmentGroups()
        return existingGroups.contains { $0.name.lowercased() == name.lowercased() }
    }
    
    private func handleCreationSuccess(groupId: UUID) async {
        print("🎉 準備進入新創建的群組聊天畫面: \(groupId)")
        
        // 顯示成功動畫
        showSuccessAnimation = true
        
        // 發送通知切換到聊天 Tab 並進入新群組
        NotificationCenter.default.post(
            name: NSNotification.Name("SwitchToChatTab"),
            object: groupId
        )
        
        // 通知 HomeView 刷新群組列表
        NotificationCenter.default.post(
            name: NSNotification.Name("RefreshGroupsList"),
            object: nil
        )
        
        // 短暫延遲後關閉創建群組畫面
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 秒
        showSuccess = true // 這會觸發關閉
    }
    
    private func handleCreationError(_ error: Error) async {
        let message: String
        
        if let supabaseError = error as? SupabaseError {
            switch supabaseError {
            case .notAuthenticated:
                message = "請先登入再創建群組"
            case .unknown(let description):
                message = description
            default:
                message = "創建群組失敗，請稍後再試"
            }
        } else {
            message = "創建群組失敗: \(error.localizedDescription)"
        }
        
        await showErrorMessage(message)
    }
    
    private func showErrorMessage(_ message: String) async {
        errorMessage = message
        showError = true
    }
    
    // MARK: - Computed Properties
    var entryFeeText: String {
        let fee = Int(entryFee)
        return fee == 0 ? "免費" : "\(fee) 代幣"
    }
    
    var entryFeeDescription: String {
        let fee = Int(entryFee)
        if fee == 0 {
            return "所有人都可以免費加入此群組"
        } else {
            return "加入此群組需要支付 \(fee) 代幣"
        }
    }
}

// MARK: - Preview Helper
extension CreateGroupViewModel {
    static var preview: CreateGroupViewModel {
        let viewModel = CreateGroupViewModel()
        viewModel.groupName = "測試投資群組"
        viewModel.groupRules = "這是一個測試群組的規則說明"
        viewModel.entryFee = 50
        return viewModel
    }
}