# 投資競賽系統使用指南

## 概述

本指南說明如何使用新整合的 TEJ API 和投資競賽系統。系統包含即時股票資料、模擬交易、競賽排名等功能。

## 主要功能

### 1. TEJ API 整合
- ✅ 即時台股報價
- ✅ 股票搜尋功能
- ✅ 歷史價格資料
- ✅ 批量資料獲取
- ✅ 錯誤處理與備援機制

### 2. 投資競賽系統
- ✅ 競賽建立與管理
- ✅ 用戶參與機制
- ✅ 即時排名系統
- ✅ 投資組合追蹤
- ✅ 模擬交易功能

### 3. 用戶界面
- ✅ 競賽列表頁面
- ✅ 競賽詳情頁面
- ✅ 投資組合管理
- ✅ 股票交易介面
- ✅ 排行榜顯示

## 使用流程

### 用戶參與競賽流程

1. **瀏覽競賽**
   - 打開應用程式
   - 點擊「競賽」標籤
   - 瀏覽可用競賽

2. **參加競賽**
   - 選擇想參加的競賽
   - 點擊「參加競賽」
   - 確認參加

3. **管理投資組合**
   - 進入競賽詳情頁
   - 點擊「我的投資組合」標籤
   - 查看持股和現金餘額

4. **進行交易**
   - 點擊「交易」按鈕
   - 搜尋或選擇股票
   - 輸入交易數量
   - 確認交易

5. **查看排名**
   - 在競賽詳情頁點擊「排行榜」標籤
   - 查看自己和其他參與者的排名

## API 使用方式

### TEJ API 調用

```swift
import Foundation

// 獲取單一股票報價
let stockService = StockService.shared
let stock = try await stockService.fetchStockQuote(symbol: "2330.TW")

// 批量獲取台股報價
let stocks = try await stockService.fetchTaiwanStocks()

// 搜尋股票
let searchResults = try await stockService.searchStocks(query: "台積電")

// 獲取歷史資料
let history = try await stockService.fetchStockHistory(symbol: "2330.TW")
```

### 競賽服務使用

```swift
import Foundation

// 獲取進行中的競賽
let competitionService = CompetitionService.shared
try await competitionService.fetchActiveCompetitions()

// 參加競賽
try await competitionService.joinCompetition(
    competitionId: competitionId,
    userId: userId
)

// 獲取競賽排名
let rankings = try await competitionService.fetchCompetitionRankings(
    competitionId: competitionId
)
```

### 投資組合管理

```swift
import Foundation

// 獲取用戶投資組合
let portfolioService = PortfolioService.shared
let portfolio = try await portfolioService.fetchUserPortfolio(userId: userId)

// 執行交易
let transaction = try await portfolioService.executeTransaction(
    userId: userId,
    symbol: "2330.TW",
    action: .buy,
    amount: 100000
)

// 計算收益率
let returnRate = try await portfolioService.calculatePortfolioReturn(userId: userId)
```

## 資料庫結構

### 主要資料表

1. **competitions** - 競賽基本資訊
2. **competition_participations** - 用戶參與記錄
3. **user_portfolios** - 用戶投資組合
4. **portfolio_transactions** - 交易記錄

詳細結構請參考 `Competition_Database_Schema.md`

## 錯誤處理

### 常見錯誤及處理

1. **TEJ API 錯誤**
   ```swift
   do {
       let stock = try await stockService.fetchStockQuote(symbol: "2330.TW")
   } catch StockServiceError.tejApiError(let message) {
       print("TEJ API 錯誤: \(message)")
       // 使用備援資料
   }
   ```

2. **競賽錯誤**
   ```swift
   do {
       try await competitionService.joinCompetition(competitionId: id, userId: userId)
   } catch CompetitionServiceError.alreadyParticipating {
       print("已經參加此競賽")
   }
   ```

3. **投資組合錯誤**
   ```swift
   do {
       try await portfolioService.executeTransaction(...)
   } catch PortfolioServiceError.insufficientFunds {
       print("資金不足")
   }
   ```

## 效能優化建議

### 1. 資料快取
- 股票資料快取 5 分鐘
- 競賽排名快取 1 分鐘
- 投資組合快取 30 秒

### 2. 批量操作
- 批量獲取股票報價
- 批量更新排名
- 批量計算收益率

### 3. 非同步處理
- 使用 async/await 進行網路請求
- 背景更新排名資料
- 延遲載入非關鍵資料

## 測試

### 單元測試
```bash
# 執行所有測試
xcodebuild test -scheme Invest_V3

# 執行特定測試
xcodebuild test -scheme Invest_V3 -only-testing:CompetitionSystemTests
```

### 測試覆蓋範圍
- TEJ API 整合測試
- 競賽功能測試
- 投資組合計算測試
- 錯誤處理測試

## 部署

### 環境設定
1. 確保 TEJ API Key 已正確設定
2. 設定 Supabase 連線
3. 建立必要的資料庫表格
4. 設定 RLS 政策

### 監控
- API 呼叫次數監控
- 錯誤率監控
- 用戶活動監控
- 系統效能監控

## 安全性

### 資料保護
- 使用 HTTPS 進行 API 通信
- 敏感資料加密存儲
- 實施 Row Level Security (RLS)
- 定期更新 API Key

### 權限控制
- 用戶只能管理自己的投資組合
- 競賽資料讀取權限控制
- 管理員功能權限檢查

## 常見問題

### Q: TEJ API 無法使用時怎麼辦？
A: 系統會自動切換到模擬資料模式，確保功能正常運作。

### Q: 如何重新計算競賽排名？
A: 系統會自動定期更新排名，也可手動調用 `updateAllCompetitionRankings()` 函數。

### Q: 投資組合計算有誤怎麼辦？
A: 檢查交易記錄是否正確，必要時可重新計算投資組合價值。

### Q: 如何新增更多股票？
A: 在 `TaiwanStocks.popularStocks` 和 `TaiwanStocks.stockNames` 中添加新的股票代號和名稱。

## 支援

如有任何問題或建議，請聯繫開發團隊或查看：

- 技術文檔: `Competition_Database_Schema.md`
- 測試檔案: `CompetitionSystemTests.swift`
- 原始碼: 各個服務和視圖檔案

## 更新日誌

### v1.0.0 (2024-01-XX)
- ✅ 整合 TEJ API 替代 Alpha Vantage
- ✅ 完成投資競賽系統
- ✅ 實現模擬交易功能
- ✅ 建立競賽排名機制
- ✅ 完成用戶界面設計
- ✅ 實現即時資料更新
- ✅ 添加完整的錯誤處理
- ✅ 建立comprehensive測試套件