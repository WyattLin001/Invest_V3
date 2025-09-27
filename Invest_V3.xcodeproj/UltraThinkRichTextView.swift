import SwiftUI
import UIKit
import PhotosUI

// MARK: - 終極修復版 RichTextView - Ultra Think 解決方案
struct UltraThinkRichTextView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UltraCustomTextView()
        textView.delegate = context.coordinator
        
        // 基本配置
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = UIColor.systemBackground
        textView.textColor = UIColor.label
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = false
        
        // 🎯 核心修復 1: 極簡的文本容器配置
        textView.textContainerInset = .zero  // 完全移除內邊距
        textView.textContainer.lineFragmentPadding = 0
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.maximumNumberOfLines = 0
        
        // 🎯 核心修復 2: 禁用所有自動調整功能
        textView.adjustsFontForContentSizeCategory = false
        
        // 🎯 核心修復 3: 設置固定的行高
        if #available(iOS 16.0, *) {
            textView.textContainer.lineBreakStrategy = .standard
        }
        
        textView.inputAccessoryView = createSimpleToolbar(coordinator: context.coordinator)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
        
        // 🎯 核心修復 4: 立即設定正確的容器尺寸
        if uiView.bounds.width > 0 {
            uiView.textContainer.size = CGSize(
                width: uiView.bounds.width,
                height: CGFloat.greatestFiniteMagnitude
            )
        }
    }
    
    func makeCoordinator() -> UltraCoordinator {
        return UltraCoordinator(self)
    }
    
    private func createSimpleToolbar(coordinator: UltraCoordinator) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        let photoButton = UIBarButtonItem(
            image: UIImage(systemName: "photo"),
            style: .plain,
            target: coordinator,
            action: #selector(coordinator.insertPhoto)
        )
        
        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: coordinator,
            action: #selector(coordinator.dismissKeyboard)
        )
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        toolbar.setItems([photoButton, flexSpace, doneButton], animated: false)
        return toolbar
    }
    
    // MARK: - Ultra Coordinator
    class UltraCoordinator: NSObject, UITextViewDelegate {
        var parent: UltraThinkRichTextView
        weak var textView: UITextView?
        private var imageCounter = 0
        
        init(_ parent: UltraThinkRichTextView) {
            self.parent = parent
            super.init()
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertImageWithAttribution),
                name: NSNotification.Name("InsertImageWithAttribution"),
                object: nil
            )
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        @objc private func handleInsertImageWithAttribution(_ notification: Foundation.Notification) {
            guard let data = notification.object as? [String: Any],
                  let image = data["image"] as? UIImage,
                  let imageId = data["imageId"] as? String else { return }
            
            let attribution = data["attribution"] as? ImageAttribution
            insertImageUltraSimple(image: image, imageId: imageId, attribution: attribution)
        }
        
        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            parent.attributedText = textView.attributedText
        }
        
        // 🎯 核心修復 5: 極簡的圖片插入方法
        private func insertImageUltraSimple(image: UIImage, imageId: String, attribution: ImageAttribution?) {
            guard let textView = textView else { return }
            
            imageCounter += 1
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 創建圖片附件 - 使用固定尺寸避免計算錯誤
            let attachment = NSTextAttachment()
            let fixedWidth: CGFloat = 300  // 固定寬度
            let aspectRatio = image.size.height / image.size.width
            let fixedHeight = fixedWidth * aspectRatio
            
            attachment.image = image
            attachment.bounds = CGRect(x: 0, y: 0, width: fixedWidth, height: fixedHeight)
            
            // 創建圖片字符串 - 使用最基本的屬性
            let imageString = NSAttributedString(attachment: attachment)
            
            // 創建標註 - 使用最基本的屬性
            let finalAttribution = attribution ?? ImageAttribution(source: .custom, customText: "iPhone")
            let captionText = "圖片\(imageCounter) - \(finalAttribution.displayText)"
            
            let captionString = NSAttributedString(
                string: captionText,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.systemGray
                ]
            )
            
            // 🎯 核心修復 6: 使用最簡單的插入邏輯
            let insertionPoint = selectedRange.location
            
            // 如果不在開頭，先加一個換行
            if insertionPoint > 0 {
                mutableText.insert(NSAttributedString(string: "\n"), at: insertionPoint)
                mutableText.insert(imageString, at: insertionPoint + 1)
                mutableText.insert(NSAttributedString(string: "\n"), at: insertionPoint + 2)
                mutableText.insert(captionString, at: insertionPoint + 3)
                mutableText.insert(NSAttributedString(string: "\n"), at: insertionPoint + 4)
                textView.selectedRange = NSRange(location: insertionPoint + 5, length: 0)
            } else {
                mutableText.insert(imageString, at: 0)
                mutableText.insert(NSAttributedString(string: "\n"), at: 1)
                mutableText.insert(captionString, at: 2)
                mutableText.insert(NSAttributedString(string: "\n"), at: 3)
                textView.selectedRange = NSRange(location: 4, length: 0)
            }
            
            textView.attributedText = mutableText
            
            print("🎯 Ultra Think: 插入圖片完成，尺寸: \(fixedWidth)x\(fixedHeight)")
        }
        
        @objc func insertPhoto() {
            NotificationCenter.default.post(name: NSNotification.Name("ShowPhotoPicker"), object: nil)
        }
        
        @objc func dismissKeyboard() {
            textView?.resignFirstResponder()
        }
    }
}

// MARK: - Ultra Custom TextView
class UltraCustomTextView: UITextView {
    
    override var intrinsicContentSize: CGSize {
        // 🎯 核心修復 7: 簡化尺寸計算
        let size = sizeThatFits(CGSize(width: bounds.width, height: .greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: max(50, size.height))
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 🎯 核心修復 8: 確保文本容器設置正確
        textContainer.lineFragmentPadding = 0
        textContainerInset = .zero
        
        invalidateIntrinsicContentSize()
    }
}

#Preview {
    UltraThinkRichTextView(attributedText: .constant(NSAttributedString(string: "Test")))
}