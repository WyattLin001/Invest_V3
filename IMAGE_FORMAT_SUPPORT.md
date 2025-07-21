# 📷 圖片格式支援說明

## ✅ 支援的圖片格式

您的 Invest_V3 應用現在支援以下圖片格式：

### 常用格式
- **JPEG** (.jpg, .jpeg) - 最常用的相片格式
- **PNG** (.png) - 透明背景支援，適合圖標和截圖
- **GIF** (.gif) - 動畫圖片支援

### 進階格式
- **WebP** (.webp) - Google 開發的高效壓縮格式
- **TIFF** (.tiff) - 高品質專業圖片格式
- **BMP** (.bmp) - Windows 標準位圖格式
- **HEIC** (.heic) - iPhone 現代相片格式

## 🔍 格式檢測機制

應用使用雙重檢測機制確保圖片品質：

### 1. 檔案副檔名檢查
- 檢查檔案名稱的副檔名
- 確保符合支援的格式列表

### 2. 檔案頭驗證
- 檢查檔案的實際二進制頭部
- 防止惡意檔案偽裝成圖片

## ❌ 不支援的格式與提醒

### 不支援的格式
- **影片檔案**: .mp4, .mov, .avi 等
- **文件檔案**: .pdf, .doc, .txt 等
- **其他檔案**: .zip, .exe 等

### 錯誤提醒機制
當用戶選擇不支援的格式時：
```
❌ 不支援的圖片格式。支援格式：jpg, jpeg, png, gif, webp, tiff, bmp, heic
```

## 🔧 技術實現

### 格式檢測代碼
```swift
// 檢查檔案副檔名
let supportedFormats = ["jpg", "jpeg", "png", "gif", "webp", "tiff", "bmp", "heic"]

// 檢查檔案頭（二進制檢測）
private func isValidImageData(_ data: Data) -> Bool {
    // 檢查 JPEG, PNG, GIF, WebP, TIFF, BMP, HEIC 的檔案頭
}
```

### 內容類型自動檢測
上傳時會自動檢測正確的 MIME 類型：
- JPEG → `image/jpeg`
- PNG → `image/png`
- GIF → `image/gif`
- WebP → `image/webp`
- TIFF → `image/tiff`
- BMP → `image/bmp`
- HEIC → `image/heic`

## 📱 iOS 整合

### PhotosPicker 設定
```swift
.photosPicker(
    isPresented: $showPhotoPicker,
    selection: $selectedPhotosPickerItems,
    maxSelectionCount: 1,
    matching: .any(of: [.images, .not(.videos)])
)
```

### 錯誤處理
- 即時格式驗證
- 友善的錯誤訊息
- 自動清理無效選擇

## 🔄 Supabase 整合

### 儲存桶設定
- 儲存桶名稱：`article-images`
- 支援所有圖片格式的 SQL 政策
- 自動內容類型檢測

### 上傳優化
- 自動檢測正確的 Content-Type
- 支援多格式並行上傳
- 錯誤恢復機制

## 🎯 使用建議

### 建議格式優先順序
1. **JPEG** - 相片和一般圖片
2. **PNG** - 需要透明背景的圖片
3. **WebP** - 需要小檔案的情況
4. **HEIC** - iPhone 用戶的現代格式

### 檔案大小建議
- 建議單張圖片不超過 10MB
- 系統會自動壓縮 JPEG 到 80% 品質
- 大檔案會影響上傳速度

## 🐛 故障排除

### 常見問題
1. **「無法載入圖片數據」** - 檔案可能損壞
2. **「不支援的圖片格式」** - 檢查檔案格式是否在支援列表中
3. **「無法處理此圖片」** - 圖片檔案可能內部損壞

### 解決方案
- 嘗試使用其他圖片
- 確認圖片未損壞
- 使用建議的格式重新保存圖片

這個完整的格式支援系統確保您的用戶能夠上傳各種常見的圖片格式，同時保持應用的安全性和穩定性！