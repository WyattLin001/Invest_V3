// 修改圖片來源設定示例

import SwiftUI
import PhotosUI

// 1. 修改 SettingsView.swift 中的圖片選擇器
// 當前代碼：
.photosPicker(isPresented: $showImagePicker, selection: $selectedPhotoItem, matching: .images)

// 修改選項：

// A. 只允許拍照，不允許從相片庫選擇
.photosPicker(
    isPresented: $showImagePicker, 
    selection: $selectedPhotoItem, 
    matching: .images,
    photoLibrary: .shared()  // 可以改為其他選項
)

// B. 限制圖片格式
.photosPicker(
    isPresented: $showImagePicker, 
    selection: $selectedPhotoItem, 
    matching: .any(of: [.images, .not(.screenshots)]) // 排除截圖
)

// C. 限制圖片大小或數量
.photosPicker(
    isPresented: $showImagePicker, 
    selection: $selectedPhotoItem, 
    maxSelectionCount: 1,  // 只能選一張
    matching: .images
)

// 2. 如果要使用相機而不是相片庫，可以使用 UIImagePickerController
struct CameraView: UIViewControllerRepresentable {
    @Binding var selectedImage: UIImage?
    @Environment(\.presentationMode) var presentationMode
    
    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.delegate = context.coordinator
        picker.sourceType = .camera  // 強制使用相機
        picker.allowsEditing = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        
        init(_ parent: CameraView) {
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

// 3. 添加網路圖片來源
struct NetworkImagePicker: View {
    @State private var imageURL: String = ""
    @Binding var selectedImage: UIImage?
    
    var body: some View {
        VStack {
            TextField("輸入圖片網址", text: $imageURL)
                .textFieldStyle(.roundedBorder)
            
            Button("載入圖片") {
                loadImageFromURL()
            }
            .disabled(imageURL.isEmpty)
        }
    }
    
    private func loadImageFromURL() {
        guard let url = URL(string: imageURL) else { return }
        
        URLSession.shared.dataTask(with: url) { data, response, error in
            guard let data = data, let image = UIImage(data: data) else { return }
            
            DispatchQueue.main.async {
                self.selectedImage = image
            }
        }.resume()
    }
}

// 4. 預設頭像系統
struct DefaultAvatarPicker: View {
    let defaultAvatars = [
        "person.crop.circle.fill",
        "person.crop.circle.badge.plus",
        "person.crop.circle.badge.checkmark",
        "person.2.crop.circle.stack.fill"
    ]
    
    @Binding var selectedAvatar: String?
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4)) {
            ForEach(defaultAvatars, id: \.self) { avatar in
                Button(action: {
                    selectedAvatar = avatar
                }) {
                    Image(systemName: avatar)
                        .font(.system(size: 30))
                        .foregroundColor(selectedAvatar == avatar ? .blue : .gray)
                        .frame(width: 60, height: 60)
                        .background(Color.gray.opacity(0.1))
                        .clipShape(Circle())
                }
            }
        }
    }
}