# 好友系統測試指南

## 🗄️ 第一步：執行數據庫更新

在 Supabase Dashboard 的 SQL Editor 中執行 `UPDATE_FRIENDS_SYSTEM.sql` 文件：

1. 登錄 [Supabase Dashboard](https://supabase.com/dashboard)
2. 選擇 Invest_V3 項目
3. 進入 **SQL Editor**
4. 複製並貼上 `UPDATE_FRIENDS_SYSTEM.sql` 的完整內容
5. 點擊 **Run** 執行

### 創建的表格和功能：
- **user_profiles 更新**：添加 `user_id` 欄位（6-8位唯一數字）
- **friendships 表**：管理好友關係
- **自動分配 user_id**：新用戶自動獲得唯一 ID
- **搜尋和好友請求函數**：完整的好友管理 API

---

## 📱 第二步：在 iOS App 中測試

### 1. 編譯並運行 App
```bash
# 在 Xcode 中打開項目
open Invest_V3.xcodeproj

# 確保 App 可以正常編譯
```

### 2. 訪問好友管理功能

**路徑：**
```
App → 首頁 (HomeView) → 點擊右上角的 👥 (人員圖標) → 好友管理頁面
```

---

## 🔧 第三步：功能測試

### A. 連接測試
1. **進入好友管理頁面**
2. **點擊 "測試連接" 按鈕**
3. **確認顯示綠色圓點和 "連接正常"**

### B. 用戶 ID 檢查
1. **查看 "我的用戶 ID" 卡片**
2. **確認顯示6-8位數字 ID**
3. **記錄這個 ID**（其他人可以用它找到你）

### C. 搜尋用戶測試

#### 創建測試用戶（在 Supabase 中）
在 SQL Editor 中執行：
```sql
-- 創建測試用戶資料（模擬註冊）
INSERT INTO public.user_profiles (id, display_name, bio, user_id)
VALUES 
    (gen_random_uuid(), '測試用戶A', '這是第一個測試用戶', '123456'),
    (gen_random_uuid(), '測試用戶B', '這是第二個測試用戶', '789012'),
    (gen_random_uuid(), '投資達人', '專業投資顧問', '456789');
```

#### 搜尋測試
1. **在搜尋框中輸入**: `123456`
2. **點擊搜尋按鈕**
3. **確認顯示**: "測試用戶A" 的信息
4. **點擊 "加好友" 按鈕**
5. **確認顯示成功訊息**

### D. 好友請求測試

#### 在 Supabase 中模擬收到好友請求
```sql
-- 假設當前用戶收到來自測試用戶的好友請求
-- 需要替換 YOUR_USER_UUID 為實際的用戶 UUID
INSERT INTO public.friendships (requester_id, addressee_id, status)
SELECT 
    (SELECT id FROM public.user_profiles WHERE user_id = '789012'),
    auth.uid(),
    'pending'
WHERE auth.uid() IS NOT NULL;
```

#### 接受好友請求
1. **刷新好友管理頁面**
2. **查看是否顯示待處理請求**
3. **點擊接受按鈕**
4. **確認好友出現在好友列表中**

---

## 📊 第四步：數據驗證

### 在 Supabase Dashboard 中檢查：

#### 檢查 user_profiles 表
```sql
SELECT id, display_name, user_id, created_at 
FROM public.user_profiles 
ORDER BY created_at DESC 
LIMIT 10;
```

#### 檢查 friendships 表
```sql
SELECT f.*, 
       u1.display_name as requester_name,
       u2.display_name as addressee_name
FROM public.friendships f
JOIN public.user_profiles u1 ON f.requester_id = u1.id
JOIN public.user_profiles u2 ON f.addressee_id = u2.id
ORDER BY f.created_at DESC;
```

#### 檢查好友關係視圖
```sql
SELECT * FROM user_friends LIMIT 10;
```

---

## 🚨 故障排除

### 常見問題和解決方案：

#### 1. "找不到用戶 ID" 錯誤
- **檢查**: user_profiles 表中是否存在該 user_id
- **解決**: 在 Supabase 中創建測試用戶

#### 2. "Supabase 連接測試失敗"
- **檢查**: SupabaseService 配置
- **檢查**: 網絡連接
- **檢查**: Supabase 項目是否正常運行

#### 3. "用戶未登入" 錯誤
- **確保**: AuthenticationService 正常工作
- **檢查**: 用戶是否已登錄 App

#### 4. RLS 權限錯誤
- **檢查**: Row Level Security 政策
- **確認**: 當前用戶有正確的權限

### Debug 日誌檢查
在 Xcode Console 中查看以下日誌：
- `✅ [FriendService]` - 成功操作
- `❌ [FriendService]` - 錯誤信息
- `⚠️ [FriendService]` - 警告信息

---

## 📋 測試檢查清單

- [ ] ✅ 數據庫 SQL 腳本執行成功
- [ ] ✅ App 編譯並運行正常
- [ ] ✅ 好友管理頁面可以訪問
- [ ] ✅ Supabase 連接測試通過
- [ ] ✅ 顯示當前用戶的 user_id
- [ ] ✅ 可以搜尋並找到測試用戶
- [ ] ✅ 可以發送好友請求
- [ ] ✅ 可以接受好友請求
- [ ] ✅ 好友列表正確顯示
- [ ] ✅ 數據在 Supabase 中正確存儲

---

## 🎯 預期結果

### 完整工作流程：
1. **用戶A** 搜尋 **用戶B** 的 ID (例: 123456)
2. **用戶A** 點擊 "加好友" 發送請求
3. **用戶B** 在好友請求中看到 **用戶A** 的請求
4. **用戶B** 點擊 "接受" 成為好友
5. 雙方的好友列表中都顯示對方
6. 數據正確存儲在 Supabase 中

### 成功指標：
- ✅ 所有測試步驟都成功執行
- ✅ UI 響應正常，沒有崩潰
- ✅ 數據庫中的數據正確且一致
- ✅ 好友關係雙向可見

---

這個測試指南覆蓋了好友系統的完整功能，確保與 Supabase 數據庫的正確連接和數據同步。