import SwiftUI
import UIKit
import PhotosUI

// MARK: - RichTextView (Medium/Notion 風格)
struct RichTextView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    @State private var showTablePicker = false
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = UIColor.systemBackground
        textView.textColor = UIColor.label
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        
        // 設置工具列
        textView.inputAccessoryView = createToolbar(for: textView, coordinator: context.coordinator)
        
        // 支援 Dynamic Type
        textView.adjustsFontForContentSizeCategory = true
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        
        // 添加通知監聽器
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("InsertImage"),
            object: nil,
            queue: .main
        ) { notification in
            if let image = notification.object as? UIImage {
                coordinator.insertImagePlaceholder(image: image)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("InsertTable"),
            object: nil,
            queue: .main
        ) { notification in
            if let tableInfo = notification.object as? [String: Int],
               let rows = tableInfo["rows"],
               let cols = tableInfo["cols"] {
                coordinator.insertTablePlaceholder(rows: rows, cols: cols)
            }
        }
        
        return coordinator
    }
    
    // MARK: - Apple-like 工具列
    private func createToolbar(for textView: UITextView, coordinator: Coordinator) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.translatesAutoresizingMaskIntoConstraints = false
        toolbar.backgroundColor = UIColor.systemBackground
        toolbar.tintColor = UIColor.label
        
        // 設置固定高度避免約束衝突
        toolbar.frame = CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 44)
        toolbar.autoresizingMask = [.flexibleWidth]
        
        // 工具列按鈕
        let h1Button = createToolbarButton(
            systemName: "textformat.size.larger",
            action: #selector(coordinator.insertH1),
            coordinator: coordinator
        )
        
        let h2Button = createToolbarButton(
            systemName: "textformat.size",
            action: #selector(coordinator.insertH2),
            coordinator: coordinator
        )
        
        let h3Button = createToolbarButton(
            systemName: "textformat.size.smaller",
            action: #selector(coordinator.insertH3),
            coordinator: coordinator
        )
        
        let boldButton = createToolbarButton(
            systemName: "bold",
            action: #selector(coordinator.toggleBold),
            coordinator: coordinator
        )
        
        // 移除斜體按鈕以避免約束問題
        
        let photoButton = createToolbarButton(
            systemName: "photo",
            action: #selector(coordinator.insertPhoto),
            coordinator: coordinator
        )
        
        let tableButton = createToolbarButton(
            systemName: "tablecells",
            action: #selector(coordinator.insertTable),
            coordinator: coordinator
        )
        
        let dividerButton = createToolbarButton(
            systemName: "minus",
            action: #selector(coordinator.insertDivider),
            coordinator: coordinator
        )
        
        // 彈性空間
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // 完成按鈕（靠右對齊）
        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: coordinator,
            action: #selector(coordinator.dismissKeyboard)
        )
        
        toolbar.setItems([
            h1Button, h2Button, h3Button,
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil),
            boldButton,
            UIBarButtonItem(barButtonSystemItem: .fixedSpace, target: nil, action: nil),
            photoButton, tableButton, dividerButton,
            flexSpace,
            doneButton
        ], animated: false)
        
        // 設置固定間距
        if let fixedSpace = toolbar.items?[3] {
            fixedSpace.width = 12
        }
        if let fixedSpace2 = toolbar.items?[5] {
            fixedSpace2.width = 12
        }
        
        return toolbar
    }
    
    private func createToolbarButton(systemName: String, action: Selector, coordinator: Coordinator) -> UIBarButtonItem {
        let button = UIBarButtonItem(
            image: UIImage(systemName: systemName),
            style: .plain,
            target: coordinator,
            action: action
        )
        return button
    }
    
    // MARK: - Coordinator
    class Coordinator: NSObject, UITextViewDelegate {
        var parent: RichTextView
        weak var textView: UITextView?
        
        init(_ parent: RichTextView) {
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
                selector: #selector(handleInsertImage),
                name: NSNotification.Name("InsertImage"),
                object: nil
            )
            
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertTable),
                name: NSNotification.Name("InsertTable"),
                object: nil
            )
        }
        
        @objc private func handleInsertImage(_ notification: Notification) {
            if let image = notification.object as? UIImage {
                insertImagePlaceholder(image: image)
            }
        }
        
        @objc private func handleInsertTable(_ notification: Notification) {
            if let data = notification.object as? [String: Int],
               let rows = data["rows"], let cols = data["cols"] {
                insertTablePlaceholder(rows: rows, cols: cols)
            }
        }
        
        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            parent.attributedText = textView.attributedText
        }
        
        // MARK: - 標題樣式
        @objc func insertH1() {
            applyHeadingStyle(level: 1, fontSize: 28)
        }
        
        @objc func insertH2() {
            applyHeadingStyle(level: 2, fontSize: 22)
        }
        
        @objc func insertH3() {
            applyHeadingStyle(level: 3, fontSize: 18)
        }
        
        private func applyHeadingStyle(level: Int, fontSize: CGFloat) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if selectedRange.length == 0 {
                // 無選取：插入佔位文字
                let placeholder = "標題 \(level)"
                let headingAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: fontSize),
                    .foregroundColor: UIColor.label
                ]
                
                let headingString = NSAttributedString(string: placeholder, attributes: headingAttributes)
                mutableText.insert(headingString, at: selectedRange.location)
                
                textView.attributedText = mutableText
                textView.selectedRange = NSRange(location: selectedRange.location, length: placeholder.count)
            } else {
                // 有選取：套用樣式
                let headingAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: fontSize),
                    .foregroundColor: UIColor.label
                ]
                
                mutableText.addAttributes(headingAttributes, range: selectedRange)
                textView.attributedText = mutableText
            }
        }
        
        // MARK: - 文字樣式
        @objc func toggleBold() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if selectedRange.length == 0 {
                // 插入粗體佔位文字
                let placeholder = "粗體文字"
                let boldAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.boldSystemFont(ofSize: 17),
                    .foregroundColor: UIColor.label
                ]
                
                let boldString = NSAttributedString(string: placeholder, attributes: boldAttributes)
                mutableText.insert(boldString, at: selectedRange.location)
                
                textView.attributedText = mutableText
                textView.selectedRange = NSRange(location: selectedRange.location, length: placeholder.count)
            } else {
                // 切換粗體樣式
                mutableText.enumerateAttribute(.font, in: selectedRange) { value, range, _ in
                    if let font = value as? UIFont {
                        let newFont = font.isBold ? font.removingBold() : font.addingBold()
                        mutableText.addAttribute(.font, value: newFont, range: range)
                    }
                }
                textView.attributedText = mutableText
            }
        }
        
        // MARK: - 分隔線
        @objc func insertDivider() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 插入分隔線
            let dividerText = "\n" + String(repeating: "─", count: 20) + "\n"
            let dividerAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.systemGray,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    return style
                }()
            ]
            
            // 正常段落樣式（分隔線後的文字）
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .left  // 左對齊
                    return style
                }()
            ]
            
            let dividerString = NSAttributedString(string: dividerText, attributes: dividerAttributes)
            let normalString = NSAttributedString(string: "", attributes: normalAttributes)
            
            mutableText.insert(dividerString, at: selectedRange.location)
            mutableText.insert(normalString, at: selectedRange.location + dividerText.count)
            
            textView.attributedText = mutableText
            textView.selectedRange = NSRange(location: selectedRange.location + dividerText.count, length: 0)
            
            // 設置輸入屬性為正常樣式，確保後續輸入的文字是正常格式
            textView.typingAttributes = normalAttributes
        }
        
        // MARK: - 圖片插入
        @objc func insertPhoto() {
            NotificationCenter.default.post(name: NSNotification.Name("ShowPhotoPicker"), object: nil)
        }
        
        // MARK: - 表格插入
        @objc func insertTable() {
            NotificationCenter.default.post(name: NSNotification.Name("ShowTablePicker"), object: nil)
        }
        
        func insertTablePlaceholder(rows: Int, cols: Int) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 創建表格佔位符
            let attachment = NSTextAttachment()
            let placeholderSize = CGSize(width: textView.frame.width - 32, height: 44)
            
            // 創建表格佔位圖像
            let renderer = UIGraphicsImageRenderer(size: placeholderSize)
            let placeholderImage = renderer.image { context in
                let cgContext = context.cgContext
                
                // 背景
                cgContext.setFillColor(UIColor.systemGray6.cgColor)
                cgContext.fill(CGRect(origin: .zero, size: placeholderSize))
                
                // 邊框
                cgContext.setStrokeColor(UIColor.systemGray3.cgColor)
                cgContext.setLineWidth(1.0)
                let borderRect = CGRect(x: 0.5, y: 0.5, width: placeholderSize.width - 1, height: placeholderSize.height - 1)
                cgContext.stroke(borderRect)
                
                // 表格圖標
                let iconSize: CGFloat = 16
                let iconRect = CGRect(x: 12, y: (placeholderSize.height - iconSize) / 2, 
                                    width: iconSize, height: iconSize)
                
                cgContext.setStrokeColor(UIColor.systemBlue.cgColor)
                cgContext.setLineWidth(1.0)
                
                // 外框
                cgContext.stroke(CGRect(x: iconRect.minX, y: iconRect.minY, 
                                      width: iconSize, height: iconSize))
                // 垂直線
                cgContext.stroke(CGRect(x: iconRect.minX + iconSize/3, y: iconRect.minY, 
                                      width: 0, height: iconSize))
                // 水平線
                cgContext.stroke(CGRect(x: iconRect.minX, y: iconRect.minY + iconSize/3, 
                                      width: iconSize, height: 0))
                
                // 文字
                let text = "Tap to edit table"
                let textAttributes: [NSAttributedString.Key: Any] = [
                    .font: UIFont.systemFont(ofSize: 14),
                    .foregroundColor: UIColor.systemGray
                ]
                
                let textRect = CGRect(x: iconRect.maxX + 8, y: 0, 
                                    width: placeholderSize.width - iconRect.maxX - 16, 
                                    height: placeholderSize.height)
                text.draw(in: textRect, withAttributes: textAttributes)
            }
            
            attachment.image = placeholderImage
            attachment.bounds = CGRect(origin: .zero, size: placeholderSize)
            
            // 插入 attachment
            let attachmentString = NSAttributedString(attachment: attachment)
            let newlineString = NSAttributedString(string: "\n")
            
            mutableText.insert(newlineString, at: selectedRange.location)
            mutableText.insert(attachmentString, at: selectedRange.location + 1)
            mutableText.insert(newlineString, at: selectedRange.location + 2)
            
            textView.attributedText = mutableText
            textView.selectedRange = NSRange(location: selectedRange.location + 3, length: 0)
        }
        
        func insertImagePlaceholder(image: UIImage) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 計算圖片顯示尺寸（保持比例，寬度適應螢幕）
            let maxWidth = textView.frame.width - 32
            let aspectRatio = image.size.height / image.size.width
            let displaySize = CGSize(width: maxWidth, height: maxWidth * aspectRatio)
            
            // 創建 attachment
            let attachment = NSTextAttachment()
            attachment.image = image
            attachment.bounds = CGRect(origin: .zero, size: displaySize)
            
            // 插入圖片
            let attachmentString = NSAttributedString(attachment: attachment)
            let newlineString = NSAttributedString(string: "\n")
            
            mutableText.insert(newlineString, at: selectedRange.location)
            mutableText.insert(attachmentString, at: selectedRange.location + 1)
            mutableText.insert(newlineString, at: selectedRange.location + 2)
            
            textView.attributedText = mutableText
            textView.selectedRange = NSRange(location: selectedRange.location + 3, length: 0)
        }
        
        @objc func dismissKeyboard() {
            textView?.resignFirstResponder()
        }
    }
}

// MARK: - UIFont 擴展
extension UIFont {
    var isBold: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitBold)
    }
    
    var isItalic: Bool {
        return fontDescriptor.symbolicTraits.contains(.traitItalic)
    }
    
    func addingBold() -> UIFont {
        let traits = fontDescriptor.symbolicTraits.union(.traitBold)
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func removingBold() -> UIFont {
        let traits = fontDescriptor.symbolicTraits.subtracting(.traitBold)
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { return self }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func addingItalic() -> UIFont {
        let traits = fontDescriptor.symbolicTraits.union(.traitItalic)
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { 
            // 如果系統字體不支援斜體，使用 Georgia 或其他支援斜體的字體
            return UIFont(name: "Georgia-Italic", size: pointSize) ?? 
                   UIFont.italicSystemFont(ofSize: pointSize)
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
    
    func removingItalic() -> UIFont {
        let traits = fontDescriptor.symbolicTraits.subtracting(.traitItalic)
        guard let descriptor = fontDescriptor.withSymbolicTraits(traits) else { 
            // 返回普通字體
            return UIFont.systemFont(ofSize: pointSize)
        }
        return UIFont(descriptor: descriptor, size: pointSize)
    }
} 