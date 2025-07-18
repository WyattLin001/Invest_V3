import SwiftUI
import PhotosUI
import UIKit

struct GroupAvatarPicker: View {
    @Binding var selectedImage: UIImage?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingPredefinedAvatars = false
    
    // 預設頭像選項
    private let predefinedAvatars = [
        "chart.line.uptrend.xyaxis",
        "dollarsign.circle.fill",
        "building.columns.fill",
        "lightbulb.fill",
        "star.fill",
        "crown.fill",
        "leaf.fill",
        "bitcoinsign.circle.fill"
    ]
    
    var body: some View {
        VStack(spacing: 16) {
            // 當前頭像顯示
            avatarDisplay
            
            // 選擇按鈕
            actionButtons
        }
        .onChange(of: selectedPhoto) { newValue in
            if let newValue = newValue {
                Task {
                    await loadSelectedPhoto(from: newValue)
                }
            }
        }
        .sheet(isPresented: $showingPredefinedAvatars) {
            predefinedAvatarSheet
        }
    }
    
    // MARK: - Avatar Display
    private var avatarDisplay: some View {
        ZStack {
            Circle()
                .fill(Color.gray200)
                .frame(width: 120, height: 120)
            
            if let selectedImage = selectedImage {
                Image(uiImage: selectedImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 120, height: 120)
                    .clipShape(Circle())
                    .scaleEffect(1.0)
                    .transition(.scale.combined(with: .opacity))
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "person.2.circle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.gray400)
                    
                    Text("群組頭像")
                        .font(.caption)
                        .foregroundColor(.gray400)
                }
                .transition(.opacity.combined(with: .scale))
            }
            
            // 編輯指示器
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Circle()
                        .fill(Color.brandPrimary)
                        .frame(width: 32, height: 32)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.system(size: 14))
                                .foregroundColor(.white)
                        )
                        .offset(x: -4, y: -4)
                }
            }
        }
        .frame(width: 120, height: 120)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
            // 從相簿選擇
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                HStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                    Text("從相簿選擇")
                }
                .font(.body.weight(.medium))
                .foregroundColor(.brandPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.brandPrimary.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 選擇預設頭像
            Button(action: {
                showingPredefinedAvatars = true
            }) {
                HStack(spacing: 8) {
                    Image(systemName: "face.smiling.fill")
                    Text("選擇預設圖示")
                }
                .font(.body.weight(.medium))
                .foregroundColor(.brandSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(Color.brandSecondary.opacity(0.1))
                .cornerRadius(8)
            }
            
            // 移除頭像
            if selectedImage != nil {
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedImage = nil
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "trash.fill")
                        Text("移除頭像")
                    }
                    .font(.body.weight(.medium))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                }
            }
        }
    }
    
    // MARK: - Predefined Avatar Sheet
    private var predefinedAvatarSheet: some View {
        NavigationView {
            ScrollView {
                predefinedAvatarGrid
                    .padding()
            }
            .navigationTitle("選擇預設圖示")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                trailing: Button("取消") {
                    showingPredefinedAvatars = false
                }
            )
        }
    }
    
    private var predefinedAvatarGrid: some View {
        let columns = Array(repeating: GridItem(.flexible()), count: 4)
        
        return LazyVGrid(columns: columns, spacing: 16) {
            ForEach(predefinedAvatars, id: \.self) { iconName in
                predefinedAvatarButton(iconName: iconName)
            }
        }
    }
    
    private func predefinedAvatarButton(iconName: String) -> some View {
        Button(action: {
            selectPredefinedAvatar(iconName: iconName)
        }) {
            ZStack {
                Circle()
                    .fill(Color.brandPrimary.opacity(0.1))
                    .frame(width: 80, height: 80)
                
                Image(systemName: iconName)
                    .font(.system(size: 32))
                    .foregroundColor(.brandPrimary)
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    private func loadSelectedPhoto(from photosPickerItem: PhotosPickerItem) async {
        do {
            if let data = try await photosPickerItem.loadTransferable(type: Data.self),
               let uiImage = UIImage(data: data) {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.selectedImage = uiImage
                    }
                }
            }
        } catch {
            print("❌ 載入圖片失敗: \(error)")
        }
    }
    
    private func selectPredefinedAvatar(iconName: String) {
        let image = createImageFromSystemIcon(iconName: iconName)
        withAnimation(.easeInOut(duration: 0.3)) {
            selectedImage = image
        }
        showingPredefinedAvatars = false
    }
    
    private func createImageFromSystemIcon(iconName: String) -> UIImage {
        let config = UIImage.SymbolConfiguration(pointSize: 60, weight: .medium)
        let image = UIImage(systemName: iconName, withConfiguration: config) ?? UIImage()
        
        // 創建有背景色的圖片
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 120, height: 120))
        return renderer.image { context in
            // 繪製背景圓圈
            UIColor.systemBlue.withAlphaComponent(0.1).setFill()
            let rect = CGRect(x: 0, y: 0, width: 120, height: 120)
            context.cgContext.fillEllipse(in: rect)
            
            // 繪製圖示
            UIColor.systemBlue.setFill()
            let iconRect = CGRect(x: 30, y: 30, width: 60, height: 60)
            image.draw(in: iconRect)
        }
    }
}

#Preview {
    struct PreviewWrapper: View {
        @State private var selectedImage: UIImage?
        
        var body: some View {
            VStack {
                GroupAvatarPicker(selectedImage: $selectedImage)
                
                if let selectedImage = selectedImage {
                    Text("已選擇頭像")
                        .foregroundColor(.green)
                } else {
                    Text("未選擇頭像")
                        .foregroundColor(.gray)
                }
            }
            .padding()
        }
    }
    
    return PreviewWrapper()
}