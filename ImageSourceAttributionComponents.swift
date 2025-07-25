// ImageSourceAttributionComponents.swift
// 圖片來源標註組件

import SwiftUI
import PhotosUI

// MARK: - 圖片來源標註模型
struct ImageAttribution {
    let source: ImageSource
    let customText: String?
    
    enum ImageSource: String, CaseIterable, Identifiable {
        case author = "作者拍攝"
        case internet = "網路圖片"
        case stock = "素材庫"
        case screenshot = "截圖"
        case social = "社群媒體"
        case news = "新聞媒體"
        case company = "公司提供"
        case custom = "自定義"
        
        var id: String { rawValue }
        
        var icon: String {
            switch self {
            case .author: return "camera.fill"
            case .internet: return "globe"
            case .stock: return "photo.stack"
            case .screenshot: return "rectangle.on.rectangle"
            case .social: return "person.2.fill"  
            case .news: return "newspaper"
            case .company: return "building.2"
            case .custom: return "pencil"
            }
        }
        
        var description: String {
            switch self {
            case .author: return "由作者親自拍攝"
            case .internet: return "來源於網際網路"
            case .stock: return "來源於圖片素材庫"
            case .screenshot: return "螢幕截圖"
            case .social: return "來源於社群媒體平台"
            case .news: return "來源於新聞媒體"
            case .company: return "由公司或機構提供"
            case .custom: return "自定義來源說明"
            }
        }
    }
    
    var displayText: String {
        switch source {
        case .custom:
            return customText ?? "自定義來源"
        default:
            return source.rawValue
        }
    }
    
    var fullAttribution: String {
        return "來源：\(displayText)"
    }
}

// MARK: - 圖片來源選擇器
struct ImageSourceAttributionPicker: View {
    @Binding var selectedAttribution: ImageAttribution?
    @Environment(\.presentationMode) var presentationMode
    
    @State private var selectedSource: ImageAttribution.ImageSource = .author
    @State private var customSourceText = ""
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 來源選擇區域
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(ImageAttribution.ImageSource.allCases) { source in
                            SourceOptionCard(
                                source: source,
                                isSelected: selectedSource == source,
                                onSelect: { selectedSource = source }
                            )
                        }
                    }
                    .padding()
                }
                
                // 自定義來源輸入
                if selectedSource == .custom {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("自定義來源")
                            .font(.headline)
                            .padding(.horizontal)
                        
                        TextField("請輸入圖片來源", text: $customSourceText)
                            .textFieldStyle(.roundedBorder)
                            .padding(.horizontal)
                    }
                    .padding(.bottom)
                    .background(Color(.systemGray6))
                }
                
                // 預覽區域
                VStack(alignment: .leading, spacing: 8) {
                    Text("預覽")
                        .font(.headline)
                        .padding(.horizontal)
                    
                    Text(previewText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                        .padding(.bottom)
                }
                .background(Color(.systemGray6))
            }
            .navigationTitle("選擇圖片來源")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: Button("確定") {
                    confirmSelection()
                }
                .disabled(selectedSource == .custom && customSourceText.isEmpty)
            )
        }
    }
    
    private var previewText: String {
        let attribution = ImageAttribution(
            source: selectedSource,
            customText: selectedSource == .custom ? customSourceText : nil
        )
        return attribution.fullAttribution
    }
    
    private func confirmSelection() {
        selectedAttribution = ImageAttribution(
            source: selectedSource,
            customText: selectedSource == .custom ? customSourceText : nil
        )
        presentationMode.wrappedValue.dismiss()
    }
}

// MARK: - 來源選項卡片
struct SourceOptionCard: View {
    let source: ImageAttribution.ImageSource
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                Image(systemName: source.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : Color.primary)
                
                Text(source.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isSelected ? .white : Color.primary)
                    .multilineTextAlignment(.center)
                
                Text(source.description)
                    .font(.caption2)
                    .foregroundColor(isSelected ? .white.opacity(0.8) : Color.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color.blue : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 帶來源標註的圖片選擇器
struct ImagePickerWithAttribution: View {
    @Binding var selectedImage: UIImage?
    @Binding var imageAttribution: ImageAttribution?
    
    @State private var showImagePicker = false
    @State private var showAttributionPicker = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var tempImage: UIImage?
    
    var body: some View {
        VStack(spacing: 16) {
            // 圖片選擇按鈕
            Button("選擇圖片") {
                showImagePicker = true
            }
            .buttonStyle(.borderedProminent)
            
            // 顯示選中的圖片
            if let image = selectedImage {
                VStack(spacing: 8) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 200)
                        .cornerRadius(8)
                    
                    // 顯示圖片來源
                    if let attribution = imageAttribution {
                        HStack {
                            Image(systemName: attribution.source.icon)
                                .foregroundColor(.secondary)
                            Text(attribution.fullAttribution)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()
                            Button("修改") {
                                showAttributionPicker = true
                            }
                            .font(.caption)
                        }
                        .padding(.horizontal)
                    } else {
                        Button("添加來源標註") {
                            showAttributionPicker = true
                        }
                        .font(.caption)
                        .foregroundColor(.blue)
                    }
                }
            }
        }
        .photosPicker(
            isPresented: $showImagePicker,
            selection: $selectedPhotoItem,
            matching: .images
        )
        .onChange(of: selectedPhotoItem) { newItem in
            Task {
                if let newItem = newItem,
                   let data = try? await newItem.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run {
                        self.tempImage = image
                        self.showAttributionPicker = true
                    }
                }
            }
        }
        .sheet(isPresented: $showAttributionPicker) {
            ImageSourceAttributionPicker(selectedAttribution: Binding(
                get: { imageAttribution },
                set: { attribution in
                    imageAttribution = attribution
                    if let tempImage = tempImage {
                        selectedImage = tempImage
                        self.tempImage = nil
                    }
                }
            ))
        }
    }
}

// MARK: - 圖片信息管理器
class ImageAttributionManager {
    static let shared = ImageAttributionManager()
    
    private var imageAttributions: [String: ImageAttribution] = [:]
    
    private init() {}
    
    func setAttribution(for imageId: String, attribution: ImageAttribution) {
        imageAttributions[imageId] = attribution
    }
    
    func getAttribution(for imageId: String) -> ImageAttribution? {
        return imageAttributions[imageId]
    }
    
    func removeAttribution(for imageId: String) {
        imageAttributions.removeValue(forKey: imageId)
    }
    
    func generateMarkdownWithAttribution(imageUrl: String, imageId: String) -> String {
        if let attribution = getAttribution(for: imageId) {
            return """
            ![](\(imageUrl))
            
            *\(attribution.fullAttribution)*
            """
        } else {
            return "![](\(imageUrl))"
        }
    }
}

// MARK: - 擴展的圖片插入工具
struct EnhancedImageInserter {
    static func insertImageWithAttribution(
        imageUrl: String,
        attribution: ImageAttribution?,
        altText: String = ""
    ) -> String {
        let imageMarkdown = "![\(altText)](\(imageUrl))"
        
        if let attribution = attribution {
            return """
            \(imageMarkdown)
            
            *\(attribution.fullAttribution)*
            
            ---
            """
        } else {
            return imageMarkdown
        }
    }
    
    static func generateAttributionHTML(attribution: ImageAttribution) -> String {
        return """
        <div class="image-attribution" style="margin-top: 4px; margin-bottom: 12px;">
            <small style="color: #666; font-style: italic;">
                <i class="icon-\(attribution.source.icon)"></i>
                \(attribution.fullAttribution)
            </small>
        </div>
        """
    }
}

// MARK: - 快速來源選擇器
struct QuickSourcePicker: View {
    @Binding var selectedAttribution: ImageAttribution?
    
    private let quickSources: [ImageAttribution.ImageSource] = [
        .author, .internet, .stock, .screenshot
    ]
    
    var body: some View {
        HStack(spacing: 8) {
            Text("來源:")
                .font(.caption)
                .foregroundColor(.secondary)
            
            ForEach(quickSources, id: \.self) { source in
                Button(action: {
                    selectedAttribution = ImageAttribution(source: source, customText: nil)
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: source.icon)
                            .font(.caption)
                        Text(source.rawValue)
                            .font(.caption)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selectedAttribution?.source == source ? Color.blue : Color(.systemGray5))
                    )
                    .foregroundColor(selectedAttribution?.source == source ? .white : .primary)
                }
                .buttonStyle(PlainButtonStyle())
            }
            
            Spacer()
        }
    }
}

// MARK: - 使用示例
struct ImageSourceAttributionExample: View {
    @State private var selectedImage: UIImage?
    @State private var imageAttribution: ImageAttribution?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("圖片來源標註示例")
                .font(.title2)
                .fontWeight(.semibold)
            
            ImagePickerWithAttribution(
                selectedImage: $selectedImage,
                imageAttribution: $imageAttribution
            )
            
            if selectedImage != nil {
                QuickSourcePicker(selectedAttribution: $imageAttribution)
            }
            
            Spacer()
        }
        .padding()
        .navigationTitle("圖片標註")
    }
}