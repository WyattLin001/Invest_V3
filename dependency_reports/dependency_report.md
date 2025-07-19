# Invest_V3 依賴分析報告

**生成時間**: 2025-07-19 11:34:32

## 📊 專案概覽

- **總檔案數**: 87
- **總依賴關係**: 98
- **總代碼行數**: 19592
- **平均複雜度**: 23.21
- **依賴密度**: 1.13

## 🏗️ 架構層級

### Tests (3 檔案)
- Invest_V3Tests
- Invest_V3UITestsLaunchTests
- Invest_V3UITests

### Views (36 檔案)
- TradingMainView
- StockMarketView
- TradeOrderView
- TableEditorView
- ArticleEditorView
- SettingsView
- SearchView
- SimpleMarkdownView
- GridTableEditorView
- ArticleView
- InfoView
- TradingAuthView
- MainAppView
- PublishSettingsView
- ToastView
- HomeView
- FullScreenQRCodeView
- RankingsView
- LoginPromptView
- AuthenticationView
- CreateGroupView
- ArticleCardView
- TopicsEditView
- NotificationView
- TradingAppView
- ArticleDetailView
- AuthorEarningsView
- ChatView
- WalletView
- DraftsView
- ContentView
- RichTextView
- PieChartView
- TradingView
- PortfolioView
- ExpertProfileView

### Other (28 檔案)
- DynamicPieChart
- Friend
- PublishSettingsSheet
- MediumStyleEditor
- TradingModels
- ChatMessage
- TradingRankingModels
- PlatformSubscription
- TableGridPicker
- GroupAvatarPicker
- EarningsDesignTokens
- UserProfile
- WalletTransaction
- Portfolio
- InitializeRankingsData
- PaymentViews
- Subscription
- GiftItem
- ArticleDraft
- Stock
- Notification
- GridTable
- Article
- ArticleTemplate
- SupabaseError
- PerformanceChart
- InvestmentGroup
- NativeRichTextEditor

### App (2 檔案)
- Invest_V3App
- EarningsTestApp

### Services (8 檔案)
- ChatPortfolioManager
- UserProfileService
- StockService
- AuthenticationService
- PortfolioService
- TradingService
- SupabaseManager
- SupabaseService

### ViewModels (7 檔案)
- HomeViewModel
- ChatViewModel
- SettingsViewModel
- CreateGroupViewModel
- AuthorEarningsViewModel
- WalletViewModel
- ArticleViewModel

### Extensions (3 檔案)
- Color+Hex
- Font+Style
- Int+Formatted

## ⚠️ 循環依賴

### 循環 1
HomeViewModel → SupabaseService → HomeViewModel

### 循環 2
SupabaseService → UserProfile → SupabaseService

### 循環 3
SupabaseService → UserProfileService → SupabaseService

### 循環 4
SupabaseService → UserProfileService → UserProfile → SupabaseService

### 循環 5
TradingRankingModels → TradingModels → TradingRankingModels

## 📈 複雜度排行 (前 10 名)

| 檔案 | 複雜度 | 代碼行數 | 依賴數 |
|------|--------|----------|--------|
| SupabaseService | 413 | 2544 | 14 |
| ChatViewModel | 94 | 565 | 2 |
| ChatView | 74 | 1123 | 2 |
| WalletTransaction | 71 | 157 | 0 |
| SupabaseError | 61 | 133 | 0 |
| TradingService | 57 | 271 | 0 |
| TradingModels | 56 | 251 | 3 |
| InvestmentGroup | 46 | 145 | 0 |
| MediumStyleEditor | 45 | 489 | 3 |
| SearchView | 41 | 306 | 0 |
