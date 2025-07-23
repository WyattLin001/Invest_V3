# 📋 資料庫 Schema 驗證清單

## 🎯 檢查目標
確保資料庫 schema 與 iOS 應用需求完全匹配

## ❌ **發現的問題**

### 1. 外鍵約束缺失
- [ ] `article_comments.article_id` 未引用 `articles(id)`
- [ ] `article_likes.article_id` 未引用 `articles(id)`
- [ ] `article_comments.user_id` 未引用 `auth.users(id)`
- [ ] `article_likes.user_id` 未引用 `auth.users(id)`

### 2. 重要欄位缺失
- [ ] `articles.shares_count` - 分享數量統計
- [ ] `articles.keywords` - 關鍵字陣列（關鍵字系統需要）
- [ ] `article_likes.user_name` - 按讚用戶名稱
- [ ] `article_comments.updated_at` - 留言編輯時間

### 3. 約束缺失
- [ ] `article_likes` 缺少防重複按讚的唯一約束
- [ ] `article_comments` 缺少內容非空檢查
- [ ] `article_shares` 的唯一約束可能不完整

### 4. 索引優化缺失
- [ ] `article_likes` 查詢優化索引
- [ ] `article_comments` 排序索引
- [ ] `article_shares` 統計索引

### 5. 觸發器缺失
- [ ] `article_comments.updated_at` 自動更新觸發器

## ✅ **iOS 應用需求對照**

### Article 模型需求
```swift
struct Article {
    let likesCount: Int      // ✅ 存在
    let commentsCount: Int   // ✅ 存在  
    let sharesCount: Int     // ❌ 缺失
    let keywords: [String]   // ❌ 缺失
}
```

### 互動功能需求
1. **按讚功能**
   - [ ] 防止重複按讚
   - [ ] 記錄用戶名稱
   - [ ] 統計總數

2. **留言功能**
   - [ ] 支援編輯（需要 updated_at）
   - [ ] 內容驗證
   - [ ] 用戶關聯

3. **分享功能**
   - [ ] 防止重複分享到同群組
   - [ ] 統計分享數量

4. **關鍵字系統**
   - [ ] 動態關鍵字分析
   - [ ] 熱門關鍵字排序

## 🔧 **修復方案**

### 立即執行
```sql
-- 執行 DATABASE_SCHEMA_FIXES.sql
-- 這個腳本會修復所有發現的問題
```

### 驗證步驟
1. **執行修復腳本**
2. **檢查外鍵約束**
3. **驗證新欄位**
4. **測試唯一約束**
5. **確認索引創建**
6. **驗證 RLS 策略**

## 📊 **完成後的檢查清單**

### 表結構檢查
- [ ] `articles` 表包含所有必需欄位
- [ ] `article_likes` 表結構完整
- [ ] `article_comments` 表支援編輯功能
- [ ] `article_shares` 表約束正確

### 性能檢查  
- [ ] 所有必要索引已創建
- [ ] 查詢計劃合理
- [ ] 大數據量測試通過

### 安全檢查
- [ ] RLS 策略正確設置
- [ ] 用戶只能操作自己的數據
- [ ] 敏感操作需要認證

### 功能測試
- [ ] iOS 應用可以正常讀取數據
- [ ] 互動功能完全正常
- [ ] 關鍵字系統運作正常
- [ ] 數據統計準確

## ⚠️ **注意事項**

1. **備份重要**
   - 執行修復前備份資料庫
   - 測試環境先行驗證

2. **漸進式修復**
   - 一步步執行修復
   - 每步驗證結果

3. **應用測試**
   - 修復後立即測試 iOS 應用
   - 確認所有功能正常

## 🚀 **修復完成後的效果**

- ✅ 完整的數據完整性保護
- ✅ 優化的查詢性能
- ✅ 安全的數據存取控制
- ✅ 完全支援 iOS 應用需求
- ✅ 可擴展的架構設計