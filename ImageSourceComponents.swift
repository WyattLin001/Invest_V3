// ImageSourceComponents.swift
// 圖片來源相關組件實現

import SwiftUI
import PhotosUI
import UIKit

// MARK: - 相機專用選擇器
struct CameraOnlyPicker: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera
        picker.allowsEditing = true
        picker.cameraDevice = .front // 預設前鏡頭，適合自拍
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraOnlyPicker
        
        init(_ parent: CameraOnlyPicker) {
            self.parent = parent
        }
        
        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            if let editedImage = info[.editedImage] as? UIImage {
                parent.selectedImage = editedImage
            } else if let originalImage = info[.originalImage] as? UIImage {
                parent.selectedImage = originalImage
            }
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}

// MARK: - 網路圖片選擇器
struct NetworkImagePicker: View {
    @State private var imageURL: String = ""
    @Binding var selectedImage: UIImage?
    @State private var isLoading = false
    @State private var errorMessage: String?
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("從網路載入圖片")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("圖片網址")
                        .font(.headline)
                    
                    TextField("https://example.com/image.jpg", text: $imageURL)
                        .textFieldStyle(.roundedBorder)
                        .keyboardType(.URL)
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                }
                
                if let errorMessage = errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                }
                
                Button("載入圖片") {
                    loadImageFromURL()
                }
                .buttonStyle(.borderedProminent)
                .disabled(imageURL.isEmpty || isLoading)
                
                if isLoading {
                    ProgressView("載入中...")
                        .padding()
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("網路圖片")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                }
            )
        }
    }
    
    private func loadImageFromURL() {
        guard !imageURL.isEmpty,
              let url = URL(string: imageURL),
              url.scheme?.hasPrefix("http") == true else {
            errorMessage = "請輸入有效的圖片網址"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = "載入失敗: \(error.localizedDescription)"
                    return
                }
                
                guard let data = data,
                      let image = UIImage(data: data) else {
                    self.errorMessage = "無法解析圖片，請確認網址正確"
                    return
                }
                
                // 檢查圖片大小
                let maxSizeInBytes = 10 * 1024 * 1024 // 10MB
                if data.count > maxSizeInBytes {
                    self.errorMessage = "圖片檔案過大，請選擇小於 10MB 的圖片"
                    return
                }
                
                self.selectedImage = image
                self.presentationMode.wrappedValue.dismiss()
            }
        }.resume()
    }
}

// MARK: - 預設頭像選擇器
struct DefaultAvatarPicker: View {
    @Binding var selectedAvatarIcon: String?
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    private let defaultAvatars = [
        ("person.crop.circle.fill", "個人"),
        ("person.crop.circle.badge.plus", "新用戶"),
        ("person.crop.circle.badge.checkmark", "認證用戶"),
        ("person.2.crop.circle.stack.fill", "團隊"),
        ("graduationcap.circle.fill", "學者"),
        ("briefcase.circle.fill", "專業"),
        ("chart.line.uptrend.xyaxis.circle.fill", "投資"),
        ("dollarsign.circle.fill", "理財"),
        ("star.circle.fill", "明星"),
        ("crown.fill", "VIP"),
        ("bolt.circle.fill", "活躍"),
        ("heart.circle.fill", "熱心")
    ]
    
    private let avatarColors: [Color] = [
        .blue, .green, .orange, .purple, .red, .yellow, .pink, .indigo
    ]
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    Text("選擇預設頭像")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(Array(defaultAvatars.enumerated()), id: \.offset) { index, avatar in
                            let (iconName, description) = avatar
                            let color = avatarColors[index % avatarColors.count]
                            
                            VStack(spacing: 8) {
                                Button(action: {
                                    selectAvatar(iconName: iconName, color: color)
                                }) {
                                    ZStack {
                                        Circle()
                                            .fill(color.gradient)
                                            .frame(width: 80, height: 80)
                                        
                                        Image(systemName: iconName)
                                            .font(.system(size: 32))
                                            .foregroundColor(.white)
                                        
                                        if selectedAvatarIcon == iconName {
                                            Circle()
                                                .stroke(Color.primary, lineWidth: 3)
                                                .frame(width: 80, height: 80)
                                        }
                                    }
                                }
                                
                                Text(description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("預設頭像")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("完成") {
                    presentationMode.wrappedValue.dismiss()
                }
                .disabled(selectedAvatarIcon == nil)
            )
        }
    }
    
    private func selectAvatar(iconName: String, color: Color) {
        selectedAvatarIcon = iconName
        
        // 生成頭像圖片
        let size = CGSize(width: 512, height: 512)
        let renderer = UIGraphicsImageRenderer(size: size)
        
        let avatarImage = renderer.image { context in
            // 填充背景色
            UIColor(color).setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 繪製圖標
            let image = UIImage(systemName: iconName)?
                .withConfiguration(UIImage.SymbolConfiguration(pointSize: 200, weight: .medium))
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            
            if let image = image {
                let imageRect = CGRect(
                    x: (size.width - image.size.width) / 2,
                    y: (size.height - image.size.height) / 2,
                    width: image.size.width,
                    height: image.size.height
                )
                image.draw(in: imageRect)
            }
        }
        
        selectedImage = avatarImage
    }
}

// MARK: - 首字母頭像生成器
struct InitialsAvatarGenerator {
    static func generateAvatar(
        name: String,
        size: CGSize = CGSize(width: 512, height: 512),
        backgroundColor: UIColor? = nil
    ) -> UIImage {
        let initials = extractInitials(from: name)
        let bgColor = backgroundColor ?? generateColorFromName(name)
        
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            // 填充背景
            bgColor.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            
            // 繪製文字
            let fontSize = size.width * 0.35
            let font = UIFont.systemFont(ofSize: fontSize, weight: .medium)
            let attributes: [NSAttributedString.Key: Any] = [
                .font: font,
                .foregroundColor: UIColor.white
            ]
            
            let textSize = initials.size(withAttributes: attributes)
            let textRect = CGRect(
                x: (size.width - textSize.width) / 2,
                y: (size.height - textSize.height) / 2,
                width: textSize.width,
                height: textSize.height
            )
            
            initials.draw(in: textRect, withAttributes: attributes)
        }
    }
    
    private static func extractInitials(from name: String) -> String {
        let components = name.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
        
        if components.isEmpty {
            return "U"
        } else if components.count == 1 {
            return String(components[0].prefix(2)).uppercased()
        } else {
            let first = String(components[0].prefix(1))
            let last = String(components[1].prefix(1))
            return (first + last).uppercased()
        }
    }
    
    private static func generateColorFromName(_ name: String) -> UIColor {
        let colors: [UIColor] = [
            .systemBlue, .systemGreen, .systemOrange, .systemPurple,
            .systemRed, .systemYellow, .systemPink, .systemIndigo,
            .systemTeal, .systemMint, .systemCyan, .systemBrown
        ]
        
        let hash = abs(name.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - 圖片來源選擇器
struct ImageSourcePicker: View {
    @Binding var selectedImage: UIImage?
    @State private var showActionSheet = false
    @State private var showCamera = false
    @State private var showPhotoLibrary = false
    @State private var showNetworkPicker = false
    @State private var showDefaultAvatars = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedAvatarIcon: String?
    
    var body: some View {
        Button(action: {
            showActionSheet = true
        }) {
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                Text("選擇頭像")
            }
            .foregroundColor(.investGreen)
        }
        .confirmationDialog("選擇圖片來源", isPresented: $showActionSheet, titleVisibility: .visible) {
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button("拍照") {
                    showCamera = true
                }
            }
            
            Button("從相片庫選擇") {
                showPhotoLibrary = true
            }
            
            Button("從網路載入") {
                showNetworkPicker = true
            }
            
            Button("使用預設頭像") {
                showDefaultAvatars = true
            }
            
            Button("取消", role: .cancel) { }
        } message: {
            Text("請選擇頭像來源")
        }
        .sheet(isPresented: $showCamera) {
            CameraOnlyPicker(selectedImage: $selectedImage)
        }
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let newItem = newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    selectedImage = image
                }
            }
        }
        .sheet(isPresented: $showNetworkPicker) {
            NetworkImagePicker(selectedImage: $selectedImage)
        }
        .sheet(isPresented: $showDefaultAvatars) {
            DefaultAvatarPicker(
                selectedAvatarIcon: $selectedAvatarIcon,
                selectedImage: $selectedImage
            )
        }
    }
}

// MARK: - 圖片驗證工具
struct ImageValidator {
    static func validateImage(_ image: UIImage, maxSizeInMB: Double = 5.0) -> ValidationResult {
        // 檢查圖片是否存在
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return .invalid("無法處理圖片")
        }
        
        // 檢查檔案大小
        let maxSizeInBytes = Int(maxSizeInMB * 1024 * 1024)
        if imageData.count > maxSizeInBytes {
            return .invalid("圖片檔案過大，請選擇小於 \(Int(maxSizeInMB))MB 的圖片")
        }
        
        // 檢查圖片尺寸
        let maxDimension: CGFloat = 4096
        if image.size.width > maxDimension || image.size.height > maxDimension {
            return .invalid("圖片尺寸過大，請選擇小於 \(Int(maxDimension))x\(Int(maxDimension)) 的圖片")
        }
        
        // 檢查最小尺寸
        let minDimension: CGFloat = 100
        if image.size.width < minDimension || image.size.height < minDimension {
            return .invalid("圖片尺寸過小，請選擇大於 \(Int(minDimension))x\(Int(minDimension)) 的圖片")
        }
        
        return .valid
    }
    
    enum ValidationResult {
        case valid
        case invalid(String)
        
        var isValid: Bool {
            switch self {
            case .valid: return true
            case .invalid: return false
            }
        }
        
        var errorMessage: String? {
            switch self {
            case .valid: return nil
            case .invalid(let message): return message
            }
        }
    }
}