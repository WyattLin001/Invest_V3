import UIKit

// MARK: - 圖片尺寸配置
/// 統一管理編輯器和預覽中的圖片尺寸，確保一致性
struct ImageSizeConfiguration {
    
    // MARK: - 靜態配置
    /// 圖片最大寬度計算
    /// 使用螢幕寬度減去左右邊距（32px each side = 64px total）
    static let imageMaxWidth: CGFloat = {
        return UIScreen.main.bounds.width - 64
    }()
    
    /// 計算圖片顯示尺寸
    /// - Parameter originalImage: 原始圖片
    /// - Returns: 適應螢幕的顯示尺寸
    static func calculateDisplaySize(for originalImage: UIImage) -> CGSize {
        let aspectRatio = originalImage.size.height / originalImage.size.width
        let displayWidth = min(imageMaxWidth, originalImage.size.width)
        let displayHeight = displayWidth * aspectRatio
        
        return CGSize(width: displayWidth, height: displayHeight)
    }
    
    /// 為 NSTextAttachment 設置統一的圖片尺寸
    /// - Parameters:
    ///   - attachment: NSTextAttachment 對象
    ///   - image: 要設置的圖片
    static func configureAttachment(_ attachment: NSTextAttachment, with image: UIImage) {
        attachment.image = image
        let displaySize = calculateDisplaySize(for: image)
        attachment.bounds = CGRect(origin: .zero, size: displaySize)
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