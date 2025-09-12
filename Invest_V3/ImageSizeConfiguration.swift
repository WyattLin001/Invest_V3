import UIKit

// MARK: - 圖片尺寸配置
/// 統一管理編輯器和預覽中的圖片尺寸，確保一致性
struct ImageSizeConfiguration {
    
    // MARK: - 靜態配置
    /// 圖片最大寬度計算
    /// 動態計算可用寬度，考慮實際的文字容器邊距
    static func calculateMaxImageWidth(containerWidth: CGFloat, textContainerInsets: UIEdgeInsets = UIEdgeInsets(top: 16, left: 0, bottom: 8, right: 0)) -> CGFloat {
        // 考慮文字容器的左右邊距和額外的安全邊距
        let safeMargin: CGFloat = 32 // 左右各16px的安全邊距
        let availableWidth = containerWidth - textContainerInsets.left - textContainerInsets.right - safeMargin
        return max(200, availableWidth) // 最小寬度200px
    }
    
    /// 備用的靜態最大寬度（當無法取得容器寬度時使用）
    static let fallbackImageMaxWidth: CGFloat = {
        return UIScreen.main.bounds.width - 64
    }()
    
    /// 計算圖片顯示尺寸
    /// - Parameters:
    ///   - originalImage: 原始圖片
    ///   - containerWidth: 容器寬度（可選，如果提供會使用動態計算）
    ///   - textContainerInsets: 文字容器邊距
    /// - Returns: 適應螢幕的顯示尺寸
    static func calculateDisplaySize(for originalImage: UIImage, containerWidth: CGFloat? = nil, textContainerInsets: UIEdgeInsets = UIEdgeInsets(top: 16, left: 0, bottom: 8, right: 0)) -> CGSize {
        let aspectRatio = originalImage.size.height / originalImage.size.width
        
        // 使用動態計算的最大寬度或備用寬度
        let maxWidth: CGFloat
        if let containerWidth = containerWidth {
            maxWidth = calculateMaxImageWidth(containerWidth: containerWidth, textContainerInsets: textContainerInsets)
        } else {
            maxWidth = fallbackImageMaxWidth
        }
        
        // 確保圖片不會太大也不會太小
        let displayWidth = min(maxWidth, max(200, originalImage.size.width))
        let displayHeight = displayWidth * aspectRatio
        
        return CGSize(width: displayWidth, height: displayHeight)
    }
    
    /// 備用方法：使用舊的靜態計算方式
    static func calculateDisplaySize(for originalImage: UIImage) -> CGSize {
        return calculateDisplaySize(for: originalImage, containerWidth: nil)
    }
    
    /// 為 NSTextAttachment 設置統一的圖片尺寸
    /// - Parameters:
    ///   - attachment: NSTextAttachment 對象
    ///   - image: 要設置的圖片
    ///   - containerWidth: 容器寬度（可選）
    ///   - textContainerInsets: 文字容器邊距
    static func configureAttachment(_ attachment: NSTextAttachment, with image: UIImage, containerWidth: CGFloat? = nil, textContainerInsets: UIEdgeInsets = UIEdgeInsets(top: 16, left: 0, bottom: 8, right: 0)) {
        let displaySize = calculateDisplaySize(for: image, containerWidth: containerWidth, textContainerInsets: textContainerInsets)
        
        // 創建適當尺寸的圖片，並確保立即可用
        let resizedImage = resizeImageForDisplay(image, targetSize: displaySize)
        
        // 設置圖片和bounds - 確保圖片已完全準備好
        attachment.image = resizedImage
        attachment.bounds = CGRect(origin: .zero, size: displaySize)
        
        // 強制設置圖片內容模式和顯示屬性
        if #available(iOS 13.0, *) {
            attachment.lineLayoutPadding = 0
        }
        
        // 確保圖片處於可顯示狀態
        if let cgImage = resizedImage.cgImage {
            // 強制解碼圖片以確保立即可用
            let context = CGContext(
                data: nil,
                width: Int(displaySize.width),
                height: Int(displaySize.height),
                bitsPerComponent: 8,
                bytesPerRow: 0,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            )
            if let context = context {
                context.draw(cgImage, in: CGRect(origin: .zero, size: displaySize))
                if let decodedImage = context.makeImage() {
                    attachment.image = UIImage(cgImage: decodedImage)
                }
            }
        }
        
        // 調試信息
        print("🖼️ 配置圖片附件 - 原始尺寸: \(image.size), 顯示尺寸: \(displaySize), 容器寬度: \(containerWidth ?? 0), 圖片已設置: \(attachment.image != nil)")
    }
    
    /// 備用方法：使用舊的配置方式
    static func configureAttachment(_ attachment: NSTextAttachment, with image: UIImage) {
        configureAttachment(attachment, with: image, containerWidth: nil)
    }
    
    /// 調整圖片尺寸以適應顯示需求
    /// - Parameters:
    ///   - image: 原始圖片
    ///   - targetSize: 目標尺寸
    /// - Returns: 調整後的圖片
    private static func resizeImageForDisplay(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: targetSize)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
    
    /// 調試用：打印圖片尺寸信息
    /// - Parameters:
    ///   - originalSize: 原始尺寸
    ///   - displaySize: 顯示尺寸
    ///   - context: 調用上下文（如 "編輯器" 或 "預覽"）
    static func logSizeInfo(originalSize: CGSize, displaySize: CGSize, context: String) {
        print("📐 \(context) 圖片尺寸 - 原始: \(originalSize), 顯示: \(displaySize)")
    }
}