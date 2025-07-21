# 📸 圖片上傳功能測試指南

## 測試步驟

### 1. 啟動應用程式

使用 Xcode 運行 Invest_V3 應用程式：
```bash
open Invest_V3.xcodeproj
# 在 Xcode 中按 Cmd+R 運行
```

### 2. 測試圖片上傳流程

#### A. 進入文章編輯器
1. 在應用中導航到文章編輯頁面（MediumStyleEditor）
2. 點擊編輯區域啟動富文本編輯器

#### B. 插入圖片
1. 點擊工具列中的相機圖示 📷
2. 從照片庫選擇圖片
3. 觀察圖片是否立即顯示在編輯器中

#### C. 發布文章並檢查日誌
1. 輸入標題和內容
2. 點擊「發佈」按鈕
3. **重要**: 查看 Xcode 控制台日誌

### 3. 預期的控制台日誌

#### ✅ 成功情況
```
📸 嘗試上傳圖片: [UUID].jpg，大小: [檔案大小] bytes
✅ 圖片上傳成功: https://wujlbjrouqcpnifbakmw.supabase.co/storage/v1/object/public/article_images/[UUID].jpg
```

#### ❌ 失敗情況
```
📸 嘗試上傳圖片: [UUID].jpg，大小: [檔案大小] bytes
❌ 圖片上傳失敗: [錯誤訊息]
```

### 4. 常見錯誤訊息及解決方案

#### A. "Bucket not found" 錯誤
**解決方案**: 前往 Supabase 控制台創建 `article_images` 儲存桶

#### B. "Access denied" 錯誤
**解決方案**: 檢查 Supabase 儲存桶權限政策設定

#### C. "User not authenticated" 錯誤
**解決方案**: 確認用戶已成功登入

#### D. "Network error" 錯誤
**解決方案**: 檢查網路連接和 Supabase URL 配置

### 5. 驗證圖片上傳成功

#### A. 在 Supabase 控制台檢查
1. 前往: https://supabase.com/dashboard/project/wujlbjrouqcpnifbakmw/storage/buckets
2. 進入 `article_images` 儲存桶
3. 確認上傳的圖片檔案存在

#### B. 在應用中檢查
1. 發布文章後，查看文章內容
2. 確認圖片正確顯示（不是「圖片上傳失敗」）
3. 檢查圖片 URL 是否為 Supabase 的正確格式

### 6. 調試提示

#### 在 MediumStyleEditor.swift 中新增的調試功能：
```swift
print("📸 嘗試上傳圖片: \(fileName)，大小: \(data.count) bytes")
print("✅ 圖片上傳成功: \(url)")
print("❌ 圖片上傳失敗: \(error.localizedDescription)")
```

#### 如果仍有問題，請檢查：
- [ ] Supabase 項目 ID 是否正確
- [ ] API 金鑰是否有效
- [ ] 儲存桶權限是否正確設置
- [ ] 用戶是否已驗證登入
- [ ] 網路連接是否正常

### 7. 成功標準

測試成功的標準：
- [ ] 圖片在編輯器中立即顯示
- [ ] 控制台顯示「✅ 圖片上傳成功」
- [ ] Supabase Storage 中能看到圖片檔案
- [ ] 發布的文章中圖片正常顯示
- [ ] 其他用戶能看到文章中的圖片

## 📞 如果測試失敗

請提供以下信息：
1. 具體的錯誤訊息（從 Xcode 控制台複製）
2. 失敗發生在哪個步驟
3. Supabase 控制台中的相關設定截圖

這將幫助我們快速診斷和解決問題！