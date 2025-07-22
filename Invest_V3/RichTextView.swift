import SwiftUI
import UIKit
import PhotosUI

// MARK: - RichTextView (Medium/Notion 風格)
struct RichTextView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = UIColor.systemBackground
        textView.textColor = UIColor.label
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = true
        textView.textContainerInset = UIEdgeInsets(top: 20, left: 16, bottom: 20, right: 16)
        textView.adjustsFontForContentSizeCategory = true
        
        // 修復：同步設置工具列，立即可用
        textView.inputAccessoryView = self.createToolbar(for: textView, coordinator: context.coordinator)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        return coordinator
    }
    
    // MARK: - Apple-like 工具列
    private func createToolbar(for textView: UITextView, coordinator: Coordinator) -> UIToolbar {
        let toolbar = UIToolbar()
        
        // 關鍵修復：讓系統自動處理約束，避免手動設置
        toolbar.sizeToFit()
        toolbar.isTranslucent = true
        toolbar.backgroundColor = UIColor.systemBackground
        toolbar.tintColor = UIColor.label
        
        // 工具列按鈕 - 使用 flexibleSpace 進行均勻分布
        let buttons = [
            createToolbarButton(systemName: "textformat.size.larger", action: #selector(coordinator.insertH1), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            createToolbarButton(systemName: "textformat.size", action: #selector(coordinator.insertH2), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            createToolbarButton(systemName: "textformat.size.smaller", action: #selector(coordinator.insertH3), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            createToolbarButton(systemName: "bold", action: #selector(coordinator.toggleBold), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            createToolbarButton(systemName: "photo", action: #selector(coordinator.insertPhoto), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            createToolbarButton(systemName: "minus", action: #selector(coordinator.insertDivider), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            UIBarButtonItem(barButtonSystemItem: .done, target: coordinator, action: #selector(coordinator.dismissKeyboard))
        ]
        
        toolbar.setItems(buttons, animated: false)
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
            
        }
        
        @objc private func handleInsertImage(_ notification: Foundation.Notification) {
            if let image = notification.object as? UIImage {
                insertImagePlaceholder(image: image)
            }
        }
        
        
        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            
            // 防抖動更新
            DispatchQueue.main.async {
                self.parent.attributedText = textView.attributedText
            }
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
        
        
        func insertImagePlaceholder(image: UIImage) {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 創建 attachment 並設置統一的圖片尺寸
            let attachment = NSTextAttachment()
            ImageSizeConfiguration.configureAttachment(attachment, with: image)
            
            // 調試信息
            ImageSizeConfiguration.logSizeInfo(
                originalSize: image.size,
                displaySize: attachment.bounds.size,
                context: "編輯器"
            )
            
            // 插入圖片
            let attachmentString = NSAttributedString(attachment: attachment)
            let newlineString = NSAttributedString(string: "\n")
            
            let insertionIndex = selectedRange.location + selectedRange.length

            mutableText.insert(newlineString, at: insertionIndex)
            mutableText.insert(attachmentString, at: insertionIndex + 1)
            mutableText.insert(newlineString, at: insertionIndex + 2)

            textView.attributedText = mutableText
            textView.selectedRange = NSRange(location: insertionIndex + 3, length: 0)
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
} 