# 🛠️ 資料庫修復指南

## 問題診斷

您遇到的錯誤：
```
❌ new row for relation "wallet_transactions" violates check constraint "wallet_transactions_transaction_type_check"
```

**問題根源**：Supabase 資料庫中的 `wallet_transactions` 表的 `transaction_type` 檢查約束不包含應用程式使用的所有交易類型。

## 📋 修復步驟

### 1. **立即修復（推薦）**

在 Supabase SQL Editor 中執行 `FIX_WALLET_TRANSACTIONS.sql`：

```sql
-- 最關鍵的修復 SQL
ALTER TABLE wallet_transactions 
DROP CONSTRAINT IF EXISTS wallet_transactions_transaction_type_check;

ALTER TABLE wallet_transactions 
ADD CONSTRAINT wallet_transactions_transaction_type_check 
CHECK (transaction_type IN (
    'deposit',
    'withdrawal',
    'gift_purchase', 
    'subscription',
    'tip',
    'bonus',
    'group_entry_fee',
    'group_tip'
));
```

### 2. **驗證修復**

執行以下查詢確認約束已更新：
```sql
SELECT 
    conname as constraint_name,
    pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'wallet_transactions'::regclass
AND contype = 'c'; -- check constraint
```

### 3. **測試抖內功能**

修復後：
1. 重新啟動您的 iOS 應用
2. 嘗試發送禮物
3. 檢查是否出現成功訊息

## 🎯 應該看到的結果

**修復前（錯誤）：**
```
❌ [ChatViewModel] 抖內失敗: new row for relation "wallet_transactions" violates check constraint
```

**修復後（成功）：**
```
✅ [ChatViewModel] 抖內成功: 5000 金幣
🎁 抖內動畫效果顯示
💬 聊天室顯示抖內訊息
```

## 🔍 技術說明

### 應用程式中定義的交易類型
```swift
enum TransactionType: String {
    case deposit = "deposit"
    case withdrawal = "withdrawal" 
    case giftPurchase = "gift_purchase"
    case subscription = "subscription"
    case tip = "tip"              // ← 這個可能在資料庫約束中缺失
    case bonus = "bonus"
    case groupEntryFee = "group_entry_fee"
    case groupTip = "group_tip"   // ← 這個也可能缺失
}
```

### 資料庫需要的約束
資料庫的檢查約束必須包含所有應用程式使用的交易類型。

## ⚡ 快速檢查

如果您想快速確認問題，可以在 Supabase SQL Editor 中執行：

```sql
-- 檢查現有約束
SELECT pg_get_constraintdef(oid) as constraint_definition
FROM pg_constraint 
WHERE conrelid = 'wallet_transactions'::regclass
AND conname LIKE '%transaction_type%';
```

如果結果不包含 `'tip'` 和 `'group_tip'`，就需要執行修復 SQL。

## 🚨 重要提醒

1. **備份**：修改約束前建議備份資料（如果有重要資料）
2. **測試**：修復後立即測試抖內功能
3. **監控**：檢查其他功能是否正常運作

修復完成後，您的禮物系統應該就能正常工作了！🎉