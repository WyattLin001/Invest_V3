import SwiftUI
import UIKit
import PhotosUI

// MARK: - RichTextView (Medium/Notion 風格)
struct RichTextView: UIViewRepresentable {
    @Binding var attributedText: NSAttributedString
    @State private var selectedImages: [PhotosPickerItem] = []
    @State private var showPhotoPicker = false
    
    func makeUIView(context: Context) -> UITextView {
        let textView = CustomTextView()
        textView.delegate = context.coordinator
        textView.font = UIFont.systemFont(ofSize: 17)
        textView.backgroundColor = UIColor.systemBackground
        textView.textColor = UIColor.label
        textView.allowsEditingTextAttributes = true
        textView.isScrollEnabled = false
        textView.textContainerInset = UIEdgeInsets(top: 16, left: 0, bottom: 8, right: 0)
        textView.textContainer.lineFragmentPadding = 0
        
        // 關鍵修復：確保文字不會溢出容器
        textView.textContainer.widthTracksTextView = true
        textView.textContainer.maximumNumberOfLines = 0
        textView.textContainer.lineBreakMode = .byWordWrapping
        textView.textContainer.size = CGSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        
        textView.adjustsFontForContentSizeCategory = true
        
        // 修復：同步設置工具列，立即可用
        textView.inputAccessoryView = self.createToolbar(for: textView, coordinator: context.coordinator)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.attributedText != attributedText {
            uiView.attributedText = attributedText
        }
        
        // 關鍵修復：確保 textContainer 寬度約束到 SwiftUI 容器
        DispatchQueue.main.async {
            if uiView.bounds.width > 0 {
                // 設定文字容器的最大寬度，避免文字溢出
                let availableWidth = uiView.bounds.width - uiView.textContainerInset.left - uiView.textContainerInset.right
                uiView.textContainer.size.width = availableWidth
                uiView.textContainer.maximumNumberOfLines = 0
                uiView.textContainer.lineBreakMode = .byWordWrapping
                
                // 強制重新佈局
                uiView.layoutManager.ensureLayout(for: uiView.textContainer)
                uiView.setNeedsLayout()
                uiView.layoutIfNeeded()
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        let coordinator = Coordinator(self)
        return coordinator
    }
    
    // 暴露重置圖片計數器的方法
    func resetImageCounter() {
        // 通過 NotificationCenter 來通知重置
        NotificationCenter.default.post(name: NSNotification.Name("ResetImageCounter"), object: nil)
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
            createToolbarButton(systemName: "list.number", action: #selector(coordinator.insertNumberedList), coordinator: coordinator),
            UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil),
            createToolbarButton(systemName: "list.bullet", action: #selector(coordinator.insertBulletList), coordinator: coordinator),
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
        private var imageCounter = 0
        
        // 重置圖片計數器（當文檔被清空或重新開始時）
        func resetImageCounter() {
            imageCounter = 0
        }
        
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
            
            // 添加帶來源標註的圖片插入通知
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleInsertImageWithAttribution),
                name: NSNotification.Name("InsertImageWithAttribution"),
                object: nil
            )
            
            // 添加重置圖片計數器通知
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleResetImageCounter),
                name: NSNotification.Name("ResetImageCounter"),
                object: nil
            )
        }
        
        @objc private func handleInsertImage(_ notification: Foundation.Notification) {
            if let image = notification.object as? UIImage {
                insertImagePlaceholder(image: image)
            }
        }
        
        @objc private func handleInsertImageWithAttribution(_ notification: Foundation.Notification) {
            guard let data = notification.object as? [String: Any],
                  let image = data["image"] as? UIImage,
                  let imageId = data["imageId"] as? String else { return }
            
            let attribution = data["attribution"] as? ImageAttribution
            insertImageWithCaptionPlaceholder(image: image, imageId: imageId, attribution: attribution)
        }
        
        @objc private func handleResetImageCounter(_ notification: Foundation.Notification) {
            resetImageCounter()
        }
        
        
        func textViewDidChange(_ textView: UITextView) {
            self.textView = textView
            
            // 簡單的防抖動更新
            DispatchQueue.main.async {
                self.parent.attributedText = textView.attributedText
            }
        }
        
        // MARK: - 自動列表續行功能
        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
            // 檢測是否按下 Enter 鍵
            if text == "\n" {
                return handleEnterKeyPress(textView: textView, at: range)
            }
            return true
        }
        
        private func handleEnterKeyPress(textView: UITextView, at range: NSRange) -> Bool {
            let currentText = textView.attributedText.string
            
            // 獲取當前行的內容
            let currentLine = getCurrentLine(text: currentText, at: range.location)
            let currentLineRange = getCurrentLineRange(text: currentText, at: range.location)
            
            // 檢查是否為列表項目
            if let listType = detectListType(line: currentLine) {
                return processListContinuation(
                    textView: textView,
                    listType: listType,
                    currentLine: currentLine,
                    currentLineRange: currentLineRange,
                    insertionPoint: range.location
                )
            }
            
            // 不是列表項目，允許正常換行
            return true
        }
        
        private func getCurrentLine(text: String, at position: Int) -> String {
            let lines = text.components(separatedBy: .newlines)
            var currentPosition = 0
            
            for line in lines {
                let lineEndPosition = currentPosition + line.count
                if position <= lineEndPosition {
                    return line
                }
                currentPosition = lineEndPosition + 1 // +1 for newline character
            }
            
            return lines.last ?? ""
        }
        
        private func getCurrentLineRange(text: String, at position: Int) -> NSRange {
            let nsText = text as NSString
            let lineRange = nsText.lineRange(for: NSRange(location: position, length: 0))
            return lineRange
        }
        
        private func detectListType(line: String) -> ListType? {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // 檢測編號列表：1. 2. 3. 等
            if let match = trimmedLine.range(of: "^(\\d+)\\. ", options: .regularExpression) {
                let numberPart = String(trimmedLine[..<match.upperBound]).dropLast(2) // 移除 ". "
                if let number = Int(numberPart) {
                    return .numbered(current: number)
                }
            }
            
            // 檢測項目符號列表：•
            if trimmedLine.hasPrefix("• ") {
                return .bullet
            }
            
            return nil
        }
        
        private enum ListType {
            case numbered(current: Int)
            case bullet
        }
        
        private func processListContinuation(
            textView: UITextView,
            listType: ListType,
            currentLine: String,
            currentLineRange: NSRange,
            insertionPoint: Int
        ) -> Bool {
            // 檢查是否為空列表項目（只有列表標記沒有內容）
            let trimmedLine = currentLine.trimmingCharacters(in: .whitespaces)
            let isEmptyListItem = checkIfEmptyListItem(line: trimmedLine, listType: listType)
            
            if isEmptyListItem {
                // 空列表項目，退出列表模式
                exitListMode(textView: textView, currentLineRange: currentLineRange)
                return false // 防止添加額外的換行
            }
            
            // 非空列表項目，創建下一個列表項目
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 插入換行符
            mutableText.insert(NSAttributedString(string: "\n"), at: insertionPoint)
            
            // 根據列表類型創建下一個項目
            let nextListItem = createNextListItem(listType: listType)
            let listAttributes = getListAttributes()
            
            let nextItemAttributedString = NSAttributedString(string: nextListItem, attributes: listAttributes)
            mutableText.insert(nextItemAttributedString, at: insertionPoint + 1)
            
            // 更新 textView
            textView.attributedText = mutableText
            
            // 設置游標位置到新列表項目的末尾
            let newCursorPosition = insertionPoint + 1 + nextListItem.count
            textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
            
            // 設置輸入屬性為列表樣式
            textView.typingAttributes = listAttributes
            
            return false // 我們已經處理了換行，防止系統再次添加
        }
        
        private func checkIfEmptyListItem(line: String, listType: ListType) -> Bool {
            switch listType {
            case .numbered:
                // 檢查是否只有編號和點號，沒有其他內容
                return line.range(of: "^\\d+\\. *$", options: .regularExpression) != nil
            case .bullet:
                // 檢查是否只有項目符號，沒有其他內容
                return line == "•" || line == "• "
            }
        }
        
        private func createNextListItem(listType: ListType) -> String {
            switch listType {
            case .numbered(let current):
                return "\(current + 1). "
            case .bullet:
                return "• "
            }
        }
        
        private func getListAttributes() -> [NSAttributedString.Key: Any] {
            return [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.firstLineHeadIndent = 0
                    style.headIndent = 24
                    return style
                }()
            ]
        }
        
        private func exitListMode(textView: UITextView, currentLineRange: NSRange) {
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 刪除當前的空列表項目
            mutableText.deleteCharacters(in: currentLineRange)
            
            // 插入換行符並重置為正常段落格式
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.firstLineHeadIndent = 0
                    style.headIndent = 0 // 重置縮排
                    return style
                }()
            ]
            
            let normalString = NSAttributedString(string: "\n", attributes: normalAttributes)
            mutableText.insert(normalString, at: currentLineRange.location)
            
            textView.attributedText = mutableText
            textView.selectedRange = NSRange(location: currentLineRange.location + 1, length: 0)
            textView.typingAttributes = normalAttributes
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
        
        // 創建圖片標籤（用於編輯器）
        private func createImageCaptionForEditor(imageIndex: Int, imageId: String, attribution: ImageAttribution?) -> NSAttributedString {
            let sourceText = attribution?.displayText ?? "未知"
            let captionText = "\n圖片\(imageIndex)[來源：\(sourceText)]"
            
            // 設置標籤樣式，與預覽模式一致
            let captionAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.systemGray2,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .center
                    style.paragraphSpacing = 4
                    style.paragraphSpacingBefore = 4
                    return style
                }()
            ]
            
            let captionString = NSMutableAttributedString(string: captionText, attributes: captionAttributes)
            
            // 添加一個左對齊的零寬度字符來重置樣式
            let resetAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 13, weight: .regular),
                .foregroundColor: UIColor.clear,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .left
                    return style
                }()
            ]
            let resetString = NSAttributedString(string: "\u{200B}", attributes: resetAttributes) // 零寬度空格
            captionString.append(resetString)
            
            return captionString
        }
        
        // 插入帶標籤的圖片
        func insertImageWithCaptionPlaceholder(image: UIImage, imageId: String, attribution: ImageAttribution?) {
            guard let textView = textView else { return }
            
            // 增加圖片計數器
            imageCounter += 1
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 創建 attachment 並設置統一的圖片尺寸
            let attachment = NSTextAttachment()
            ImageSizeConfiguration.configureAttachment(attachment, with: image)
            
            // 準備插入的內容
            let attachmentString = NSAttributedString(attachment: attachment)
            let imageCaption = createImageCaptionForEditor(imageIndex: imageCounter, imageId: imageId, attribution: attribution)
            let insertionIndex = selectedRange.location + selectedRange.length
            
            // 創建正常段落屬性（用於圖片後的換行）
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .left  // 明確設置左對齊
                    style.firstLineHeadIndent = 0
                    style.headIndent = 0
                    return style
                }()
            ]
            
            // 創建額外的左對齊重置文字
            let extraResetAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.alignment = .left
                    style.firstLineHeadIndent = 0
                    style.headIndent = 0
                    style.paragraphSpacing = 0
                    style.paragraphSpacingBefore = 0
                    return style
                }()
            ]
            
            // 插入圖片、標籤和必要的格式
            if insertionIndex > 0 && !textView.attributedText.string.hasSuffix("\n") {
                // 非開頭位置且前面沒有換行：添加前導換行 + 圖片 + 標籤 + 強制左對齊換行
                let beforeNewline = NSAttributedString(string: "\n")
                let resetAlignmentNewline = NSAttributedString(string: "\n\u{200B}", attributes: extraResetAttributes) // 零寬度空格確保左對齊
                
                mutableText.insert(beforeNewline, at: insertionIndex)
                mutableText.insert(attachmentString, at: insertionIndex + 1)
                mutableText.insert(imageCaption, at: insertionIndex + 2)
                mutableText.insert(resetAlignmentNewline, at: insertionIndex + 3)
                
                // 設置游標在左對齊換行符後面
                textView.selectedRange = NSRange(location: insertionIndex + 4, length: 0)
            } else {
                // 開頭位置或前面已有換行：只插入圖片 + 標籤 + 強制左對齊換行
                let resetAlignmentNewline = NSAttributedString(string: "\n\u{200B}", attributes: extraResetAttributes) // 零寬度空格確保左對齊
                
                mutableText.insert(attachmentString, at: insertionIndex)
                mutableText.insert(imageCaption, at: insertionIndex + 1)
                mutableText.insert(resetAlignmentNewline, at: insertionIndex + 2)
                
                // 設置游標在左對齊換行符後面
                textView.selectedRange = NSRange(location: insertionIndex + 3, length: 0)
            }
            
            // 更新文字內容
            textView.attributedText = mutableText
            
            // 設置後續輸入的屬性為正常格式（明確左對齊）
            textView.typingAttributes = extraResetAttributes
            
            // 強制觸發佈局更新，確保圖片和標籤立即顯示
            DispatchQueue.main.async {
                // 強制重新渲染文字內容
                textView.setNeedsDisplay()
                textView.invalidateIntrinsicContentSize()
                textView.setNeedsLayout()
                textView.layoutIfNeeded()
                
                // 強制重新繪製所有的 attachment
                textView.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length))
                textView.layoutManager.ensureLayout(for: textView.textContainer)
                
                // 觸發 SwiftUI 更新
                if let customTextView = textView as? CustomTextView {
                    customTextView.invalidateIntrinsicContentSize()
                }
            }
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
            
            // 準備插入的內容
            let attachmentString = NSAttributedString(attachment: attachment)
            let insertionIndex = selectedRange.location + selectedRange.length
            
            // 創建正常段落屬性（用於圖片後的換行）
            let normalAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.firstLineHeadIndent = 0
                    style.headIndent = 0
                    return style
                }()
            ]
            
            // 插入圖片和必要的格式
            if insertionIndex > 0 && !textView.attributedText.string.hasSuffix("\n") {
                // 非開頭位置且前面沒有換行：添加前導換行 + 圖片 + 後續換行
                let beforeNewline = NSAttributedString(string: "\n")
                let afterNewline = NSAttributedString(string: "\n", attributes: normalAttributes)
                
                mutableText.insert(beforeNewline, at: insertionIndex)
                mutableText.insert(attachmentString, at: insertionIndex + 1)
                mutableText.insert(afterNewline, at: insertionIndex + 2)
                
                // 設置游標在圖片後的換行符後面
                textView.selectedRange = NSRange(location: insertionIndex + 3, length: 0)
            } else {
                // 開頭位置或前面已有換行：只插入圖片 + 後續換行
                let afterNewline = NSAttributedString(string: "\n", attributes: normalAttributes)
                
                mutableText.insert(attachmentString, at: insertionIndex)
                mutableText.insert(afterNewline, at: insertionIndex + 1)
                
                // 設置游標在圖片後的換行符後面
                textView.selectedRange = NSRange(location: insertionIndex + 2, length: 0)
            }
            
            // 更新文字內容
            textView.attributedText = mutableText
            
            // 設置後續輸入的屬性為正常格式
            textView.typingAttributes = normalAttributes
            
            // 強制觸發佈局更新，確保圖片立即顯示
            DispatchQueue.main.async {
                // 強制重新渲染文字內容
                textView.setNeedsDisplay()
                textView.invalidateIntrinsicContentSize()
                textView.setNeedsLayout()
                textView.layoutIfNeeded()
                
                // 強制重新繪製所有的 attachment
                textView.layoutManager.invalidateDisplay(forCharacterRange: NSRange(location: 0, length: textView.textStorage.length))
                textView.layoutManager.ensureLayout(for: textView.textContainer)
                
                // 觸發 SwiftUI 更新
                if let customTextView = textView as? CustomTextView {
                    customTextView.invalidateIntrinsicContentSize()
                }
            }
        }
        
        // MARK: - 列表功能
        @objc func insertNumberedList() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 創建編號列表項目（只有編號和點號）
            let listItem = "1. "
            let listAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.firstLineHeadIndent = 0
                    style.headIndent = 24 // 縮排
                    return style
                }()
            ]
            
            let listString = NSAttributedString(string: listItem, attributes: listAttributes)
            
            // 直接插入列表標記
            mutableText.insert(listString, at: selectedRange.location)
            
            // 設置游標位置在列表標記後面
            let newCursorPosition = selectedRange.location + listItem.count
            textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
            
            textView.attributedText = mutableText
            textView.typingAttributes = listAttributes
        }
        
        @objc func insertBulletList() {
            guard let textView = textView else { return }
            
            let selectedRange = textView.selectedRange
            let mutableText = NSMutableAttributedString(attributedString: textView.attributedText)
            
            // 創建項目符號列表項目（只有項目符號）
            let listItem = "• "
            let listAttributes: [NSAttributedString.Key: Any] = [
                .font: UIFont.systemFont(ofSize: 17),
                .foregroundColor: UIColor.label,
                .paragraphStyle: {
                    let style = NSMutableParagraphStyle()
                    style.firstLineHeadIndent = 0
                    style.headIndent = 24 // 縮排
                    return style
                }()
            ]
            
            let listString = NSAttributedString(string: listItem, attributes: listAttributes)
            
            // 直接插入列表標記
            mutableText.insert(listString, at: selectedRange.location)
            
            // 設置游標位置在列表標記後面
            let newCursorPosition = selectedRange.location + listItem.count
            textView.selectedRange = NSRange(location: newCursorPosition, length: 0)
            
            textView.attributedText = mutableText
            textView.typingAttributes = listAttributes
        }

        @objc func dismissKeyboard() {
            textView?.resignFirstResponder()
        }
    }
}

// MARK: - Custom UITextView for better intrinsic content size
class CustomTextView: UITextView {
    override var intrinsicContentSize: CGSize {
        let textSize = sizeThatFits(CGSize(width: bounds.width, height: CGFloat.greatestFiniteMagnitude))
        return CGSize(width: UIView.noIntrinsicMetric, height: textSize.height)
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
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