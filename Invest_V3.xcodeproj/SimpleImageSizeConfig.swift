import UIKit

// MARK: - 簡化的圖片尺寸配置
/// 專門修復圖片間距問題的尺寸計算器
struct SimpleImageSizeConfig {
    
    /// 計算圖片的最佳顯示尺寸 - 避免間距問題
    static func calculateImageSize(for image: UIImage, containerWidth: CGFloat) -> CGSize {
        let imageSize = image.size
        let maxWidth = containerWidth - 32 // 左右各16pt邊距
        let availableWidth = max(200, maxWidth) // 最小寬度200pt
        
        // 如果原始圖片寬度小於可用寬度，直接使用原始尺寸
        if imageSize.width <= availableWidth {
            return imageSize
        }
        
        // 按比例縮放
        let scale = availableWidth / imageSize.width
        let newHeight = imageSize.height * scale
        
        // 限制最大高度為500pt，避免過長的圖片
        let maxHeight: CGFloat = 500
        if newHeight > maxHeight {
            let heightScale = maxHeight / imageSize.height
            return CGSize(width: imageSize.width * heightScale, height: maxHeight)
        }
        
        return CGSize(width: availableWidth, height: newHeight)
    }
    
    /// 為 NSTextAttachment 配置圖片
    static func configureAttachment(_ attachment: NSTextAttachment, image: UIImage, containerWidth: CGFloat) {
        let displaySize = calculateImageSize(for: image, containerWidth: containerWidth)
        
        // 直接設置圖片和邊界
        attachment.image = image
        attachment.bounds = CGRect(origin: .zero, size: displaySize)
        
        print("🔧 簡化配置: 原始(\(image.size)) -> 顯示(\(displaySize))")
    }
}