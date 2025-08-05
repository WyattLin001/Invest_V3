//
//  EditUserIDView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/4.
//  用戶ID編輯頁面
//

import SwiftUI

struct EditUserIDView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var newUserID = ""
    @State private var isChecking = false
    @State private var isAvailable: Bool? = nil
    @State private var errorMessage = ""
    @State private var showingSaveAlert = false
    
    let currentUserID: String
    let onSave: (String) -> Void
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // 說明區塊
                VStack(spacing: 12) {
                    Image(systemName: "person.badge.key")
                        .font(.system(size: 40))
                        .foregroundColor(.brandGreen)
                    
                    Text("設定用戶ID")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("設定一個獨特的用戶ID，其他用戶可以通過此ID找到並添加您為好友")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 20)
                
                // 輸入區塊
                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("當前用戶ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            Text(currentUserID)
                                .font(.body)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                            
                            Image(systemName: "lock.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("新用戶ID")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        HStack {
                            TextField("輸入新的用戶ID", text: $newUserID)
                                .textFieldStyle(.roundedBorder)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                                .onChange(of: newUserID) { oldValue, newValue in
                                    // 重置檢查狀態
                                    isAvailable = nil
                                    errorMessage = ""
                                    
                                    // 延遲檢查可用性
                                    Task {
                                        try await Task.sleep(nanoseconds: 500_000_000) // 0.5秒
                                        if newValue == newUserID && !newValue.isEmpty && newValue != currentUserID {
                                            await checkAvailability()
                                        }
                                    }
                                }
                            
                            if isChecking {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else if let available = isAvailable {
                                Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle.fill")
                                    .foregroundColor(available ? .green : .red)
                            }
                        }
                        
                        // 狀態訊息
                        if !errorMessage.isEmpty {
                            Text(errorMessage)
                                .font(.caption)
                                .foregroundColor(.red)
                        } else if let available = isAvailable {
                            Text(available ? "✓ 此ID可用" : "✗ 此ID已被使用")
                                .font(.caption)
                                .foregroundColor(available ? .green : .red)
                        }
                    }
                    
                    // 規則說明
                    VStack(alignment: .leading, spacing: 4) {
                        Text("用戶ID規則：")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                        
                        ForEach(idRules, id: \.self) { rule in
                            HStack(alignment: .top, spacing: 4) {
                                Text("•")
                                    .foregroundColor(.secondary)
                                Text(rule)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(8)
                }
                
                Spacer()
                
                // 保存按鈕
                Button(action: {
                    showingSaveAlert = true
                }) {
                    Text("保存變更")
                        .font(.headline)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(saveButtonColor)
                        .cornerRadius(12)
                }
                .disabled(!canSave)
                
            }
            .padding(.horizontal, 20)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            newUserID = currentUserID
        }
        .alert("確認變更", isPresented: $showingSaveAlert) {
            Button("取消", role: .cancel) { }
            Button("確認") {
                onSave(newUserID)
                dismiss()
            }
        } message: {
            Text("確定要將用戶ID更改為「\(newUserID)」嗎？\n\n變更後，其他用戶需要使用新的ID來找到您。")
        }
    }
    
    private var idRules: [String] {
        [
            "長度為3-20個字符",
            "只能包含字母、數字和底線",
            "不能以數字開頭",
            "不區分大小寫"
        ]
    }
    
    private var canSave: Bool {
        guard !newUserID.isEmpty,
              newUserID != currentUserID,
              isValidUserID(newUserID),
              let available = isAvailable,
              available else {
            return false
        }
        return true
    }
    
    private var saveButtonColor: Color {
        canSave ? .brandGreen : .gray
    }
    
    private func isValidUserID(_ id: String) -> Bool {
        // 檢查長度
        guard id.count >= 3 && id.count <= 20 else { return false }
        
        // 檢查字符（字母、數字、底線）
        let allowedCharacterSet = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_"))
        guard id.unicodeScalars.allSatisfy({ allowedCharacterSet.contains($0) }) else { return false }
        
        // 不能以數字開頭
        guard let firstChar = id.first, !firstChar.isNumber else { return false }
        
        return true
    }
    
    private func checkAvailability() async {
        guard !newUserID.isEmpty, isValidUserID(newUserID) else {
            errorMessage = "請輸入有效的用戶ID"
            isAvailable = false
            return
        }
        
        isChecking = true
        
        do {
            // 模擬API檢查（實際實現需要調用SupabaseService）
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1秒模擬
            
            // 這裡應該調用真實的API檢查
            let available = await SupabaseService.shared.checkUserIDAvailability(newUserID)
            
            await MainActor.run {
                isAvailable = available
                if !available {
                    errorMessage = "此用戶ID已被使用，請嘗試其他ID"
                }
            }
        } catch {
            await MainActor.run {
                errorMessage = "檢查可用性時發生錯誤"
                isAvailable = false
            }
        }
        
        isChecking = false
    }
}

#Preview {
    EditUserIDView(
        currentUserID: "USER_12345678",
        onSave: { newID in
            print("New user ID: \(newID)")
        }
    )
}