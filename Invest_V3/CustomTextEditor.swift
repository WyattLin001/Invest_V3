import SwiftUI
import UIKit

// MARK: - CustomTextEditor (完全禁用系統輸入輔助工具欄)
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    var placeholder: String = "開始寫作..."
    var onEditingChanged: ((Bool) -> Void)?
    var onTextChanged: ((String) -> Void)?
    
    func makeUIView(context: Context) -> UITextView {
        let textView = NoAccessoryTextView()
        textView.font = UIFont.systemFont(ofSize: 18)
        textView.backgroundColor = UIColor.clear
        textView.delegate = context.coordinator
        
        // 多重保護：完全禁用輸入輔助工具欄
        textView.inputAccessoryView = nil
        textView.autocorrectionType = .no
        textView.smartQuotesType = .no
        textView.smartDashesType = .no
        textView.smartInsertDeleteType = .no
        
        // 立即設置游標位置，讓編輯器可用
        textView.selectedRange = NSRange(location: textView.text.count, length: 0)
        
        // 設置佔位符
        textView.text = text.isEmpty ? placeholder : text
        textView.textColor = text.isEmpty ? UIColor.placeholderText : UIColor.label
        
        // 延遲獲得焦點，確保在視圖完全載入後
        DispatchQueue.main.async {
            if text.isEmpty {
                textView.becomeFirstResponder()
            }
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        // 只有當文本真的不同時才更新，避免游標跳動
        let currentText = text.isEmpty ? placeholder : text
        if uiView.text != currentText {
            let wasFirstResponder = uiView.isFirstResponder
            let selectedRange = uiView.selectedRange
            
            uiView.text = currentText
            uiView.textColor = text.isEmpty ? UIColor.placeholderText : UIColor.label
            
            if wasFirstResponder && !text.isEmpty {
                uiView.becomeFirstResponder()
                // 恢復游標位置
                uiView.selectedRange = selectedRange
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: CustomTextEditor
        
        init(_ parent: CustomTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            // 處理佔位符邏輯
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = UIColor.label
            }
            
            parent.text = textView.text
            parent.onTextChanged?(textView.text)
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            // 開始編輯時清除佔位符
            if textView.text == parent.placeholder {
                textView.text = ""
                textView.textColor = UIColor.label
            }
            parent.onEditingChanged?(true)
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            // 結束編輯時顯示佔位符
            if textView.text.isEmpty {
                textView.text = parent.placeholder
                textView.textColor = UIColor.placeholderText
            }
            parent.onEditingChanged?(false)
        }
    }
}

// MARK: - 自定義 UITextView 類別，完全禁用輸入配件
class NoAccessoryTextView: UITextView {
    
    override var inputAccessoryView: UIView? {
        get { return nil }
        set { }
    }
    
    override var inputView: UIView? {
        get { return nil }
        set { }
    }
    
    // 強制返回 nil 來禁用所有輸入配件
    override func canPerformAction(_ action: Selector, withSender sender: Any?) -> Bool {
        // 禁用特定的編輯操作，如表格插入等
        if action == #selector(toggleBoldface(_:)) ||
           action == #selector(toggleItalics(_:)) ||
           action == #selector(toggleUnderline(_:)) {
            return false
        }
        return super.canPerformAction(action, withSender: sender)
    }
    
    // 優化滾動行為
    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        super.scrollViewDidScroll(scrollView)
        // 可以在這裡添加自定義滾動邏輯
    }
    
    // 優化鍵盤響應
    override var keyboardAppearance: UIKeyboardAppearance {
        get {
            return traitCollection.userInterfaceStyle == .dark ? .dark : .light
        }
        set { }
    }
    
    // 自動調整行間距
    override func awakeFromNib() {
        super.awakeFromNib()
        setupTextView()
    }
    
    override init(frame: CGRect, textContainer: NSTextContainer?) {
        super.init(frame: frame, textContainer: textContainer)
        setupTextView()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupTextView()
    }
    
    private func setupTextView() {
        // 設置適當的行間距
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 4
        paragraphStyle.paragraphSpacing = 12
        
        self.typingAttributes = [
            .font: UIFont.systemFont(ofSize: 18),
            .foregroundColor: UIColor.label,
            .paragraphStyle: paragraphStyle
        ]
        
        // 設置更好的滾動體驗
        self.alwaysBounceVertical = true
        self.keyboardDismissMode = .onDrag
        
        // 提高觸摸敏感度
        self.delaysContentTouches = false
    }
}