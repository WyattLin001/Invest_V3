// 圖片來源使用示例
// 展示如何在不同場景中使用新的圖片來源組件

import SwiftUI
import PhotosUI

// MARK: - 示例1: 在設定頁面使用完整的圖片來源選擇器
struct SettingsViewExample: View {
    @State private var profileImage: UIImage?
    @State private var errorMessage: String?
    
    var body: some View {
        VStack(spacing: 20) {
            // 頭像顯示
            if let image = profileImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.blue.gradient)
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text("無頭像")
                            .foregroundColor(.white)
                    )
            }
            
            // 圖片來源選擇器
            ImageSourcePicker(selectedImage: $profileImage)
            
            // 錯誤訊息顯示
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
        .padding()
    }
}

// MARK: - 示例2: 只使用相機功能
struct CameraOnlyExample: View {
    @State private var capturedImage: UIImage?
    @State private var showCamera = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = capturedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        Text("未拍攝照片")
                            .foregroundColor(.secondary)
                    )
            }
            
            Button("拍照") {
                showCamera = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .sheet(isPresented: $showCamera) {
            CameraOnlyPicker(selectedImage: $capturedImage)
        }
    }
}

// MARK: - 示例3: 網路圖片載入器
struct NetworkImageExample: View {
    @State private var networkImage: UIImage?
    @State private var showNetworkPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = networkImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        VStack {
                            Image(systemName: "network")
                                .font(.system(size: 40))
                            Text("從網路載入圖片")
                        }
                        .foregroundColor(.secondary)
                    )
            }
            
            Button("從網路載入") {
                showNetworkPicker = true
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .sheet(isPresented: $showNetworkPicker) {
            NetworkImagePicker(selectedImage: $networkImage)
        }
    }
}

// MARK: - 示例4: 預設頭像選擇器
struct DefaultAvatarExample: View {
    @State private var selectedAvatar: UIImage?
    @State private var selectedIcon: String?
    @State private var showAvatarPicker = false
    
    var body: some View {
        VStack(spacing: 20) {
            if let avatar = selectedAvatar {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                    )
            }
            
            Button("選擇預設頭像") {
                showAvatarPicker = true
            }
            .buttonStyle(.borderedProminent)
            
            if let icon = selectedIcon {
                Text("已選擇: \(icon)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .sheet(isPresented: $showAvatarPicker) {
            DefaultAvatarPicker(
                selectedAvatarIcon: $selectedIcon,
                selectedImage: $selectedAvatar
            )
        }
    }
}

// MARK: - 示例5: 首字母頭像生成
struct InitialsAvatarExample: View {
    @State private var userName = "投資達人"
    @State private var generatedAvatar: UIImage?
    
    var body: some View {
        VStack(spacing: 20) {
            if let avatar = generatedAvatar {
                Image(uiImage: avatar)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 120, height: 120)
                    .overlay(
                        Text("頭像")
                            .foregroundColor(.secondary)
                    )
            }
            
            TextField("輸入姓名", text: $userName)
                .textFieldStyle(.roundedBorder)
            
            Button("生成首字母頭像") {
                generatedAvatar = InitialsAvatarGenerator.generateAvatar(name: userName)
            }
            .buttonStyle(.borderedProminent)
            .disabled(userName.isEmpty)
        }
        .padding()
    }
}

// MARK: - 示例6: 圖片驗證展示
struct ImageValidationExample: View {
    @State private var selectedImage: UIImage?
    @State private var validationMessage: String?
    @State private var showPhotoPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    
    var body: some View {
        VStack(spacing: 20) {
            if let image = selectedImage {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 200)
                    .cornerRadius(12)
            } else {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 200)
                    .overlay(
                        Text("選擇圖片以測試驗證")
                            .foregroundColor(.secondary)
                    )
            }
            
            Button("選擇圖片") {
                showPhotoPicker = true
            }
            .buttonStyle(.borderedProminent)
            
            if let message = validationMessage {
                Text(message)
                    .foregroundColor(message.contains("通過") ? .green : .red)
                    .font(.caption)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let newItem = newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    
                    await MainActor.run {
                        self.selectedImage = image
                        
                        // 驗證圖片
                        let result = ImageValidator.validateImage(image)
                        self.validationMessage = result.isValid ? 
                            "✅ 驗證通過！圖片符合要求。" : 
                            "❌ \(result.errorMessage ?? "驗證失敗")"
                    }
                }
            }
        }
    }
}

// MARK: - 完整示例應用
struct ImageSourceDemoApp: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            SettingsViewExample()
                .tabItem {
                    Image(systemName: "gearshape")
                    Text("完整選擇器")
                }
                .tag(0)
            
            CameraOnlyExample()
                .tabItem {
                    Image(systemName: "camera")
                    Text("相機")
                }
                .tag(1)
            
            NetworkImageExample()
                .tabItem {
                    Image(systemName: "network")
                    Text("網路圖片")
                }
                .tag(2)
            
            DefaultAvatarExample()
                .tabItem {
                    Image(systemName: "person.crop.circle")
                    Text("預設頭像")
                }
                .tag(3)
            
            InitialsAvatarExample()
                .tabItem {
                    Image(systemName: "textformat.abc")
                    Text("首字母")
                }
                .tag(4)
            
            ImageValidationExample()
                .tabItem {
                    Image(systemName: "checkmark.shield")
                    Text("驗證")
                }
                .tag(5)
        }
    }
}

// MARK: - Preview
#Preview {
    ImageSourceDemoApp()
}