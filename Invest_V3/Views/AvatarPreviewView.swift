//
//  AvatarPreviewView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/5.
//  頭像大圖預覽視圖 - 支援縮放、手勢和分享功能
//

import SwiftUI

struct AvatarPreviewView: View {
    let image: UIImage
    let userName: String
    
    @Environment(\.dismiss) private var dismiss
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastScale: CGFloat = 1.0
    @State private var lastOffset: CGSize = .zero
    @State private var showShareSheet = false
    
    // 縮放限制
    private let minScale: CGFloat = 1.0
    private let maxScale: CGFloat = 4.0
    
    var body: some View {
        NavigationView {
            ZStack {
                // 背景
                Color.black
                    .ignoresSafeArea(.all)
                
                // 頭像圖片
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .scaleEffect(scale)
                    .offset(offset)
                    .clipped()
                    .gesture(
                        SimultaneousGesture(
                            magnificationGesture,
                            panGesture
                        )
                    )
                    .onTapGesture(count: 2) {
                        // 雙擊重置縮放
                        withAnimation(.easeInOut(duration: 0.3)) {
                            resetZoom()
                        }
                    }
                
                // 操作按鈕覆蓋層
                VStack {
                    Spacer()
                    
                    HStack(spacing: 30) {
                        // 重置縮放按鈕
                        if scale != 1.0 || offset != .zero {
                            Button(action: {
                                withAnimation(.easeInOut(duration: 0.3)) {
                                    resetZoom()
                                }
                            }) {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.title2)
                                    .foregroundColor(.white)
                                    .padding(12)
                                    .background(Color.black.opacity(0.6))
                                    .clipShape(Circle())
                            }
                        }
                        
                        Spacer()
                        
                        // 分享按鈕
                        Button(action: {
                            showShareSheet = true
                        }) {
                            Image(systemName: "square.and.arrow.up")
                                .font(.title2)
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, 30)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .principal) {
                    Text("\(userName) 的頭像")
                        .foregroundColor(.white)
                        .font(.headline)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .statusBarHidden()
        }
        .sheet(isPresented: $showShareSheet) {
            ShareSheet(activityItems: [image])
        }
    }
    
    // MARK: - 手勢
    
    private var magnificationGesture: some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let newScale = lastScale * value
                scale = min(max(newScale, minScale), maxScale)
            }
            .onEnded { _ in
                lastScale = scale
                
                // 如果縮放過小，自動重置
                if scale < minScale {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = minScale
                        lastScale = minScale
                    }
                }
                
                // 如果縮放過大，限制到最大值
                if scale > maxScale {
                    withAnimation(.easeOut(duration: 0.2)) {
                        scale = maxScale
                        lastScale = maxScale
                    }
                }
            }
    }
    
    private var panGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // 只有在縮放時才允許拖拽
                if scale > 1.0 {
                    offset = CGSize(
                        width: lastOffset.width + value.translation.width,
                        height: lastOffset.height + value.translation.height
                    )
                }
            }
            .onEnded { _ in
                lastOffset = offset
                
                // 邊界檢查，防止圖片拖拽出可視範圍
                constrainOffset()
            }
    }
    
    // MARK: - 輔助方法
    
    private func resetZoom() {
        scale = 1.0
        offset = .zero
        lastScale = 1.0
        lastOffset = .zero
    }
    
    private func constrainOffset() {
        // 計算圖片在當前縮放下的實際尺寸
        let screenSize = UIScreen.main.bounds.size
        let imageSize = image.size
        
        // 計算縮放後的圖片尺寸
        let scaledWidth = min(screenSize.width, imageSize.width * scale)
        let scaledHeight = min(screenSize.height, imageSize.height * scale)
        
        // 計算最大允許的偏移量
        let maxOffsetX = max(0, (scaledWidth - screenSize.width) / 2)
        let maxOffsetY = max(0, (scaledHeight - screenSize.height) / 2)
        
        // 約束偏移量
        let constrainedOffset = CGSize(
            width: min(max(offset.width, -maxOffsetX), maxOffsetX),
            height: min(max(offset.height, -maxOffsetY), maxOffsetY)
        )
        
        if constrainedOffset != offset {
            withAnimation(.easeOut(duration: 0.2)) {
                offset = constrainedOffset
                lastOffset = constrainedOffset
            }
        }
    }
}

// MARK: - 分享功能
struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(
            activityItems: activityItems,
            applicationActivities: nil
        )
        
        // iPad 需要設置 popover
        if let popover = controller.popoverPresentationController {
            popover.sourceView = UIApplication.shared.windows.first
            popover.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }
        
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - 預覽
#Preview {
    AvatarPreviewView(
        image: UIImage(systemName: "person.crop.circle.fill") ?? UIImage(),
        userName: "投資達人"
    )
}