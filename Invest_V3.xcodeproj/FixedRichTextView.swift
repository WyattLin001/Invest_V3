import SwiftUI
import UIKit
import PhotosUI

// MARK: - 修復版 RichTextView - 解決圖片間距問題
struct FixedRichTextView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    
    func makeUIView(context: Context) -> UITextView {
        let textView = FixedCustomTextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = UIColor.systemBackground
        textView.textColor = UIColor.label
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = false
        
        // 關鍵修復 1: 重新設置文本容器的邊距
        textView.textContainerInset = UIEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        
        // 關鍵修復 2: 文本容器配置
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.size = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        
        // 關鍵修復 3: 禁用自動行高調整
        if #available(iOS 16.0, *) {
            textView.textContainer.lineBreakStrategy = .standard
        }
        
        textView.adjustsFontForContentSizeCategory = true
        textView.inputAccessoryView = createToolbar(for: textView, coordinator: context.coordinator)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
        
        // 關鍵修復 4: 立即重新計算所有圖片尺寸
        DispatchQueue.main.async {
            if uiView.bounds.width > 0 {
                let availableWidth = uiView.bounds.width - uiView.textContainerInset.left - uiView.textContainerInset.right
                uiView.textContainer.size.width = availableWidth
                
                // 立即重新計算圖片尺寸
                self.recalculateAllImageSizes(in: uiView)
                
                // 強制重新佈局
                uiView.layoutManager.ensureLayout(for: uiView.textContainer)
                uiView.setNeedsLayout()
                uiView.layoutIfNeeded()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    // 關鍵修復 5: 重新計算所有圖片尺寸的新算法
    private func recalculateAllImageSizes(in textView: UITextView) {
        let textStorage = textView.textStorage
        let fullRange = NSRange(location: 0, length: textStorage.length)
        
        textStorage.enumerateAttribute(.attachment, in: fullRange) { value, range, _ in
            if let attachment = value as? NSTextAttachment,
               let image = attachment.image {
                
                // 使用修復後的尺寸計算
                let maxWidth = textView.bounds.width - 32 // 左右邊距
                let newSize = calculateOptimalImageSize(for: image, maxWidth: maxWidth)
                
                // 只在尺寸確實變化時才更新
                if abs(attachment.bounds.size.width - newSize.width) > 1.0 ||
                   abs(attachment.bounds.size.height - newSize.height) > 1.0 {
                    attachment.bounds = CGRect(origin: .zero, size: newSize)
                }
            }
        }
    }
    
    // 關鍵修復 6: 新的圖片尺寸計算算法
    private func calculateOptimalImageSize(for image: UIImage, maxWidth: CGFloat) -> CGSize {
        let imageSize = image.size
        let availableWidth = max(200, maxWidth) // 最小寬度 200pt
        
        // 如果圖片寬度小於等於可用寬度，使用原始尺寸
        if imageSize.width <= availableWidth {
            return imageSize
        }
        
        // 需要縮放時，保持寬高比
        let scale = availableWidth / imageSize.width
        let newHeight = imageSize.height * scale
        
        // 限制最大高度避免過長的圖片
        let maxHeight: CGFloat = 600
        if newHeight > maxHeight {
            let heightScale = maxHeight / newHeight
            return CGSize(width: availableWidth * heightScale, height: maxHeight)
        }
        
        return CGSize(width: availableWidth, height: newHeight)
    }
    
    // MARK: - 工具列創建
    private func createToolbar(for textView: UITextView, coordinator: Coordinator) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.isTranslucent = true
        toolbar.backgroundColor = UIColor.systemBackground
        toolbar.tintColor = UIColor.label
        
        let buttons = [
            createToolbarButton(systemName: "textformat.size.larger", action: #selector(coordinator.insertH1), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            createToolbarButton(systemName: "bold", action: #selector(coordinator.toggleBold), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            createToolbarButton(systemName: "photo", action: #selector(coordinator.insertPhoto), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: coordinator, action: #selector(coordinator.dismissKeyboard))
        ]
        
        toolbar.setItems(buttons, animated: false)
        return toolbar
    }
    
    private func createToolbarButton(systemName: String, action: Selector, coordinator: Coordinator) -> UIBarButtonItem {
        return UIBarButtonItem(
            image: UIImage(systemName: systemName),
            style: .plain,
            target: coordinator,
            action: action
        )
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: FixedRichTextView
        weak var textView: UITextView?
        private var imageCounter = 0
        
        init(_ parent: FixedRichTextView) {
            self.parent = parent
            super.init()
            setupNotifications()
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        private func setupNotifications() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertImageWithAttribution),
                name: NSNotification.Name("InsertImageWithAttribution"),
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleResetImageCounter),
                name: NSNotification.Name("ResetImageCounter"),
                object: nil
            )
        }
        
        @objc private func handleInsertImageWithAttribution(_ notification: Foundation.Notification) {
            guard let data = notification.object as? [String: Any],
                  let image = data["image"] as? UIImage,
                  let imageId = data["imageId"] as? String else { return }
            
            let attribution = data["attribution"] as? ImageAttribution
            insertImageWithFixedSpacing(image: image, imageId: imageId, attribution: attribution)
        }
        
        @objc private func handleResetImageCounter(_ notification: Foundation.Notification) {
            imageCounter = 0
        }
        
        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            DispatchQueue.main.async {
                self.parent.attributedText = textView.attributedText
            }
        }
        
        // MARK: - 關鍵修復 7: 重新設計的圖片插入方法
        func insertImageWithFixedSpacing(image: UIImage, imageId: String, attribution: ImageAttribution?) {
            guard let textView = textView else { return }
            
            imageCounter += 1
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 創建圖片附件
            let attachment = NSTextAttachment()
            let maxWidth = textView.bounds.width - 32
            let imageSize = parent.calculateOptimalImageSize(for: image, maxWidth: maxWidth)
            
            attachment.image = image
            attachment.bounds = CGRect(origin: .zero, size: imageSize)
            
            // 創建圖片段落 - 使用最簡化的樣式
            let imageString = NSAttributedString(attachment: attachment)
            
            // 創建標註文字
            let finalAttribution = attribution ?? ImageAttribution(source: .custom, customText: "iPhone")
            let captionText = "圖片\(imageCounter)\n來源：\(finalAttribution.displayText)"
            
            let captionString = NSAttributedString(
                string: captionText,
                attributes: [
                    .font: UIFont.systemFont(ofSize: 13),
                    .foregroundColor: UIColor.systemGray2,
                    .paragraphStyle: {
                        let style = NSMutableParagraphStyle()
                        style.alignment = .center
                        style.paragraphSpacing = 4
                        style.paragraphSpacingBefore = 4
                        return style
                    }()
                ]
            )
            
            // 正常文字樣式
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label,
                .paragraphStyle: NSMutableParagraphStyle() // 使用默認的段落樣式
            ]
            
            let insertionIndex = selectedRange.location + selectedRange.length
            
            // 關鍵修復 8: 使用最簡單的插入方式
            if insertionIndex > 0 {
                mutableText.insert(NSAttributedString(string: "\n"), at: insertionIndex)
                mutableText.insert(imageString, at: insertionIndex + 1)
                mutableText.insert(NSAttributedString(string: "\n"), at: insertionIndex + 2)
                mutableText.insert(captionString, at: insertionIndex + 3)
                mutableText.insert(NSAttributedString(string: "\n\n", attributes: normalAttributes), at: insertionIndex + 4)
                textView.selectedRange = NSRange(location: insertionIndex + 6, length: 0)
            } else {
                mutableText.insert(imageString, at: 0)
                mutableText.insert(NSAttributedString(string: "\n"), at: 1)
                mutableText.insert(captionString, at: 2)
                mutableText.insert(NSAttributedString(string: "\n\n", attributes: normalAttributes), at: 3)
                textView.selectedRange = NSRange(location: 5, length: 0)
            }
            
            textView.attributedText = mutableText
            textView.typingAttributes = normalAttributes
            
            // 強制重新佈局
            DispatchQueue.main.async {
                textView.layoutManager.ensureLayout(for: textView.textContainer)
                textView.setNeedsDisplay()
                textView.layoutIfNeeded()
            }
        }
        
        // MARK: - 工具列動作
        @objc func insertH1() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            let headingAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.boldSystemFont(ofSize: 28),
                .foregroundColor: UIColor.label
            ]
            
            let headingString = NSAttributedString(string: "標題 1", attributes: headingAttributes)
            mutableText.insert(headingString, at: selectedRange.location)
            
            textView.attributedText = mutableText
            textView.selectedRange = NSRange(location: selectedRange.location, length: 3)
        }
        
        @objc func toggleBold() {
            guard let textView = textView else { return }
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if selectedRange.length == 0 {
                let boldString = NSAttributedString(
                    string: "粗體文字",
                    attributes: [
                        .font: UIFont.boldSystemFont(ofSize: 17),
                        .foregroundColor: UIColor.label
                    ]
                )
                mutableText.insert(boldString, at: selectedRange.location)
                textView.attributedText = mutableText
                textView.selectedRange = NSRange(location: selectedRange.location, length: 4)
            }
        }
        
        @objc func insertPhoto() {
            NotificationCenter.default.post(name: NSNotification.Name("ShowPhotoPicker"), object: nil)
        }
        
        @objc func dismissKeyboard() {
            textView?.resignFirstResponder()
        }
    }
}

// MARK: - 修復版自定義 UITextView
class FixedCustomTextView: UITextView {
    
    override var intrinsicContentSize: CGSize {
        let textSize = sizeThatFits(CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: textSize.height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // 關鍵修復 9: 每次佈局時都確保文本容器配置正確
        textContainer.lineFragmentPadding = 0
        textContainer.widthTracksTextView = true
        
        invalidateIntrinsicContentSize()
    }
    
    // 關鍵修復 10: 覆寫 sizeThatFits 確保正確的尺寸計算
    override func sizeThatFits(_ size: CGSize) -> CGSize {
        let targetSize = CGSize(width: size.width, height: CGFloat.greatestFiniteMagnitude)
        
        // 使用 layoutManager 計算準確的文本尺寸
        let boundingRect = layoutManager.usedRect(for: textContainer)
        let calculatedHeight = boundingRect.height + textContainerInset.top + textContainerInset.bottom
        
        return CGSize(width: size.width, height: max(50, calculatedHeight))
    }
}

// MARK: - 預覽用
#Preview {
    FixedRichTextView(attributedText: .constant(NSAttributedString(string: "測試文字")))
        .padding()
}