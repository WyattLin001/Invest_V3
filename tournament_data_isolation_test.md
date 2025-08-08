# 錦標賽數據隔離測試計劃

## 測試目的
驗證統一表架構 (`portfolio_transactions`) 是否正確實現錦標賽間的數據隔離功能。

## 測試環境
- **Flask API**: 已更新使用 `portfolio_transactions` 表
- **iOS TradingService**: 已適配新的 API 響應格式
- **數據庫**: Supabase `portfolio_transactions` 表包含 `tournament_id` 字段

## 預期行為
1. **錦標賽交易**：在 Test06 錦標賽中的交易只會出現在 Test06 的投資組合和交易記錄中
2. **一般交易**：一般模式的交易（`tournament_id` 為 null）不會出現在任何錦標賽中
3. **數據隔離**：Test05 和 Test06 錦標賽之間的數據完全隔離

## 測試步驟

### 步驟 1：Flask API 端點測試
```bash
# 測試一般模式投資組合
curl "http://localhost:5001/api/portfolio?user_id=USER_ID"

# 測試錦標賽投資組合
curl "http://localhost:5001/api/portfolio?user_id=USER_ID&tournament_id=TOURNAMENT_ID"

# 測試一般交易記錄
curl "http://localhost:5001/api/transactions?user_id=USER_ID"

# 測試錦標賽交易記錄
curl "http://localhost:5001/api/transactions?user_id=USER_ID&tournament_id=TOURNAMENT_ID"
```

### 步驟 2：交易測試
```bash
# 在錦標賽中執行買入交易
curl -X POST "http://localhost:5001/api/trade" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "USER_ID",
    "symbol": "2337",
    "action": "buy",
    "amount": 100,
    "tournament_id": "TOURNAMENT_ID"
  }'

# 在一般模式執行買入交易
curl -X POST "http://localhost:5001/api/trade" \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": "USER_ID", 
    "symbol": "2337",
    "action": "buy",
    "amount": 100
  }'
```

### 步驟 3：數據庫驗證
在 Supabase 中檢查 `portfolio_transactions` 表：
```sql
-- 查看所有交易記錄
SELECT user_id, symbol, action, amount, tournament_id, executed_at 
FROM portfolio_transactions 
WHERE user_id = 'USER_ID' 
ORDER BY executed_at DESC;

-- 驗證錦標賽數據隔離
SELECT tournament_id, COUNT(*) as transaction_count
FROM portfolio_transactions 
WHERE user_id = 'USER_ID'
GROUP BY tournament_id;
```

### 步驟 4：iOS 應用測試
1. 在 iOS 應用中切換到 Test06 錦標賽
2. 執行買入 2337 股票 100元 的交易
3. 切換到 Test05 錦標賽，確認該交易不出現
4. 切換到一般模式，確認該交易不出現
5. 重複步驟但在不同模式下執行交易

## 驗證檢查項

### ✅ Flask API 檢查項
- [ ] `portfolio_transactions` 表交易記錄包含正確的 `tournament_id`
- [ ] 錦標賽投資組合 API 只返回對應錦標賽的數據
- [ ] 一般模式投資組合 API 只返回 `tournament_id` 為 null 的數據
- [ ] 交易 API 正確保存 `tournament_id` 字段

### ✅ iOS TradingService 檢查項  
- [ ] `TradingTransaction` 模型正確解析 `tournament_id` 字段
- [ ] `PortfolioResponse` 正確處理新的 API 響應格式
- [ ] 錦標賽切換後數據正確重新載入
- [ ] 交易後觸發正確的數據重載邏輯

### ✅ 數據隔離檢查項
- [ ] Test05 錦標賽中看不到 Test06 的交易
- [ ] Test06 錦標賽中看不到 Test05 的交易  
- [ ] 一般模式中看不到錦標賽交易
- [ ] 錦標賽中看不到一般模式交易

## 測試結果

### 成功標準
- 所有 API 端點正確返回對應模式的數據
- iOS 應用在不同模式間切換時數據正確隔離
- 數據庫中交易記錄包含正確的 `tournament_id`
- 用戶體驗符合預期：在 Test06 的交易不會出現在 Test05 中

### 失敗處理
如果測試失敗，檢查以下項目：
1. Flask API 是否正確使用 `portfolio_transactions` 表
2. iOS TradingService 是否正確處理新的響應格式
3. 數據庫表結構是否包含 `tournament_id` 字段
4. API 端點的 `tournament_id` 參數篩選邏輯

## 修正完成的問題

### ✅ 已解決問題
1. **Flask API 使用不存在的表**：從 `transactions` 改為使用 `portfolio_transactions`
2. **API 響應格式不匹配**：調整了 iOS 模型以適配新的響應結構
3. **數據字段映射錯誤**：修正了 `amount` vs `shares` 字段的使用
4. **投資組合響應結構**：適配了 Flask API 的直接響應格式

## 總結
這個測試計劃確保了統一表架構 (`portfolio_transactions`) 正確實現了錦標賽數據隔離功能。通過 `tournament_id` 字段，系統能夠在同一個表中管理一般交易和多個錦標賽的交易，同時保持完全的數據隔離。