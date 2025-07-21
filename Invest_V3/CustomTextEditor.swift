import SwiftUI
import UIKit

// MARK: - CustomTextEditor (完全禁用系統輸入輔助工具欄)
struct CustomTextEditor: UIViewRepresentable {
    @Binding var text: String
    
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
        
        // 延遲獲得焦點，確保在視圖完全載入後
        DispatchQueue.main.async {
            textView.becomeFirstResponder()
        }
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            uiView.text = text
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
            parent.text = textView.text
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
}