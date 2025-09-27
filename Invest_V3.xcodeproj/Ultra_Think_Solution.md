# 圖片間距問題 - Ultra Think 解決方案

## 🎯 問題分析

經過深入分析，圖片和文字間距過大的問題根源不是在於：
- ❌ Unicode 段落分隔符
- ❌ 段落樣式設置
- ❌ Auto Layout 約束衝突

而是在於：
- ✅ **UITextView 的文本容器 (NSTextContainer) 配置錯誤**
- ✅ **NSTextAttachment 的尺寸計算算法有問題**
- ✅ **文本容器的內邊距 (textContainerInset) 影響布局**

## 🔧 核心解決方案

### 1. 簡化 NSTextContainer 配置
```swift
// 移除所有不必要的內邊距
textView.textContainerInset = .zero
textView.textContainer.lineFragmentPadding = 0
```

### 2. 使用固定圖片尺寸
```swift
// 不再使用複雜的動態計算，使用固定寬度
let fixedWidth: CGFloat = 300
let aspectRatio = image.size.height / image.size.width
let fixedHeight = fixedWidth * aspectRatio

attachment.bounds = CGRect(x: 0, y: 0, width: fixedWidth, height: fixedHeight)
```

### 3. 極簡的圖片插入邏輯
```swift
// 只使用基本的換行符，不添加複雜的段落屬性
mutableText.insert(NSAttributedString(string: "\n"), at: insertionPoint)
mutableText.insert(imageString, at: insertionPoint + 1)
mutableText.insert(NSAttributedString(string: "\n"), at: insertionPoint + 2)
mutableText.insert(captionString, at: insertionPoint + 3)
mutableText.insert(NSAttributedString(string: "\n"), at: insertionPoint + 4)
```

## 📂 新增的檔案

1. **UltraThinkRichTextView.swift** - 終極修復版本的富文本編輯器
2. **FixedRichTextView.swift** - 備用修復版本 
3. **SimpleImageSizeConfig.swift** - 簡化的圖片尺寸計算器

## 🚀 使用方式

在 `MediumStyleEditor.swift` 中，富文本編輯器已經更新為使用 Ultra Think 版本：

```swift
private var richTextEditor: some View {
    UltraThinkRichTextView(attributedText: $attributedContent)
        .background(backgroundColor)
        // ... 其他配置
}
```

## ✅ 預期結果

使用這個解決方案後：
- 圖片和文字之間只會有正常的單行間距
- 圖片標註緊貼在圖片下方
- 用戶可以在圖片後正常輸入，不會有額外空白
- 消除了 Auto Layout 約束衝突

## 🧪 測試建議

1. 插入圖片後檢查間距是否正常
2. 在圖片前後輸入文字，確認沒有異常間距
3. 測試多張圖片連續插入的情況
4. 確認圖片標註顯示正確

這個 Ultra Think 解決方案從根本上重新設計了圖片插入邏輯，應該能完全解決圖片間距問題。