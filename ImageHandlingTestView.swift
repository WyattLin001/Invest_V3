import SwiftUI
import PhotosUI

// MARK: - 圖片處理測試視圖
struct ImageHandlingTestView: View {
    @State private var selectedImages: [UIImage] = []
    @State private var selectedPhotosPickerItems: [PhotosPickerItem] = []
    @State private var showImagePicker = false
    @State private var isProcessing = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("圖片處理測試")
                .font(.title)
                .fontWeight(.bold)
            
            // 已選擇的圖片顯示
            if !selectedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
                            VStack {
                                Image(uiImage: image)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 80, height: 80)
                                    .clipped()
                                    .cornerRadius(8)
                                
                                Text("圖片 \(index + 1)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
            }
            
            // 狀態顯示
            VStack {
                Text("已選擇圖片數量: \(selectedImages.count)")
                    .font(.headline)
                
                if isProcessing {
                    ProgressView("處理中...")
                        .progressViewStyle(CircularProgressViewStyle())
                }
            }
            
            // 添加圖片按鈕
            Button(action: {
                showImagePicker = true
            }) {
                HStack {
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 20))
                    Text("添加圖片")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(8)
            }
            
            // 清空按鈕
            if !selectedImages.isEmpty {
                Button(action: {
                    selectedImages.removeAll()
                }) {
                    Text("清空所有圖片")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.red)
                }
            }
            
            Spacer()
        }
        .padding()
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotosPickerItems,
            maxSelectionCount: 1,
            matching: .images
        )
        .onChange(of: selectedPhotosPickerItems) { _, newItems in
            loadSelectedImages(newItems)
        }
    }
    
    private func loadSelectedImages(_ items: [PhotosPickerItem]) {
        guard let item = items.first else { return }
        
        // 清空選擇以防止重複處理
        selectedPhotosPickerItems = []
        isProcessing = true
        
        item.loadTransferable(type: Data.self) { result in
            DispatchQueue.main.async {
                isProcessing = false
                
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        // 檢查是否已存在相同圖片，避免重複
                        if !selectedImages.contains(where: { existingImage in
                            existingImage.pngData() == image.pngData()
                        }) {
                            selectedImages.append(image)
                            print("✅ 圖片添加成功，總數: \(selectedImages.count)")
                        } else {
                            print("⚠️ 圖片已存在，跳過添加")
                        }
                    }
                case .failure(let error):
                    print("❌ 圖片載入失敗: \(error)")
                }
            }
        }
    }
}

// MARK: - 預覽
#Preview {
    ImageHandlingTestView()
}