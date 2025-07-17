# 投資模擬交易平台 📈

> 一個完整的股票模擬交易系統，包含iOS前端應用和Flask後端服務

![Platform](https://img.shields.io/badge/Platform-iOS-blue)
![Backend](https://img.shields.io/badge/Backend-Flask-green)
![Database](https://img.shields.io/badge/Database-PostgreSQL-orange)
![Status](https://img.shields.io/badge/Status-Complete-success)

## 📖 目錄

- [功能特色](#功能特色)
- [技術架構](#技術架構)
- [快速開始](#快速開始)
- [API文檔](#api文檔)
- [項目結構](#項目結構)
- [測試指南](#測試指南)
- [部署說明](#部署說明)
- [常見問題](#常見問題)

## ✨ 功能特色

### 🔐 用戶認證系統
- **OTP手機驗證登入** - 安全的簡訊驗證碼認證
- **邀請碼獎勵機制** - 新用戶註冊獲得虛擬獎金
- **JWT身份驗證** - 無狀態的安全認證機制

### 📱 iOS SwiftUI 前端
- **🏠 首頁** - 投資組合總覽和快速操作
- **📊 股票市場** - 實時股價、搜尋、股票詳情
- **💰 模擬交易** - 買賣下單、市價/限價訂單
- **📈 投資組合** - 持股管理、績效追蹤
- **🏆 排行榜** - 用戶投資績效排名

### 🚀 Flask 後端服務
- **RESTful API** - 完整的API端點設計
- **實時股價** - yfinance API台股數據
- **交易引擎** - 完整的買賣邏輯和風險控制
- **定時任務** - 自動股價更新和排名計算

### ⏰ 調度器系統
- 📅 **股價更新**: 每30秒自動更新
- 🏆 **排名計算**: 每5分鐘重新計算
- 💼 **投資組合**: 每1分鐘重算資產

## 🏗️ 技術架構

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   iOS SwiftUI   │───▶│   Flask API     │───▶│   PostgreSQL    │
│                 │    │                 │    │                 │
│ • Authentication│    │ • REST Endpoints│    │ • User Data     │
│ • Trading UI    │    │ • Business Logic│    │ • Stock Data    │
│ • Portfolio     │    │ • Scheduler     │    │ • Transactions  │
│ • Rankings      │    │ • Stock Service │    │ • Rankings      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
        │                       │                       │
        │              ┌─────────────────┐             │
        └──────────────▶│   Supabase      │◀────────────┘
                       │                 │
                       │ • Authentication│
                       │ • Database      │
                       │ • Real-time     │
                       └─────────────────┘
```

## 🚀 快速開始

### 前置要求

- **iOS開發**: Xcode 14+ / iOS 15+
- **後端開發**: Python 3.8+ / PostgreSQL
- **雲端服務**: Supabase帳號 (或PostgreSQL)

### 1️⃣ 後端設置

```bash
# 克隆項目
git clone <repository-url>
cd Invest_V3/invest_simulator_backend

# 安裝依賴
pip install -r requirements.txt

# 配置環境變數
cp .env.example .env
# 編輯 .env 文件，填入你的配置

# 使用部署腳本
./deploy.sh
```

### 2️⃣ 環境配置

創建 `.env` 文件：

```env
# Supabase 配置
SUPABASE_URL=your_supabase_project_url
SUPABASE_SERVICE_KEY=your_supabase_service_key

# JWT 配置
JWT_SECRET_KEY=your_jwt_secret_key

# 交易配置
INITIAL_CAPITAL=1000000
REFERRAL_BONUS=100000

# Twilio SMS (可選)
TWILIO_ACCOUNT_SID=your_twilio_sid
TWILIO_AUTH_TOKEN=your_twilio_token
TWILIO_PHONE_NUMBER=your_twilio_number
```

### 3️⃣ 資料庫初始化

```bash
# 連接到PostgreSQL
psql -h your_host -U your_user -d your_database

# 執行建表腳本
\i setup_trading_tables.sql
```

### 4️⃣ 啟動後端服務

```bash
# 開發模式
python app.py

# 或使用部署腳本
./deploy.sh
# 選擇選項 1 (開發模式)
```

### 5️⃣ iOS App 設置

```bash
# 打開 Xcode 項目
open Invest_V3.xcodeproj

# 配置後端URL (在 TradingService.swift)
private let baseURL = "http://localhost:5001"  # 本地測試
# 或
private let baseURL = "https://your-domain.com"  # 生產環境
```

### 6️⃣ 運行應用

1. 在 Xcode 中選擇模擬器或設備
2. 按 `Cmd + R` 編譯並運行
3. 使用手機號註冊 (格式: +886912345678)
4. 輸入收到的OTP驗證碼
5. 開始模擬交易！

## 📋 API文檔

### 認證端點

| 方法 | 端點 | 描述 | 參數 |
|------|------|------|------|
| POST | `/auth/send_otp` | 發送OTP簡訊 | `{"phone": "+886912345678"}` |
| POST | `/auth/verify_otp` | 驗證OTP並登入 | `{"phone": "+886...", "otp": "123456", "invite_code": "ABC123"}` |

### 交易端點

| 方法 | 端點 | 描述 | 需要認證 |
|------|------|------|----------|
| GET | `/api/stocks` | 獲取股票列表 | ✅ |
| GET | `/api/stocks/search?q=台積電` | 搜尋股票 | ✅ |
| POST | `/api/trading/buy` | 買入股票 | ✅ |
| POST | `/api/trading/sell` | 賣出股票 | ✅ |
| GET | `/api/portfolio` | 獲取投資組合 | ✅ |
| GET | `/api/transactions` | 獲取交易記錄 | ✅ |
| GET | `/api/rankings` | 獲取用戶排行榜 | ✅ |

### 管理端點

| 方法 | 端點 | 描述 |
|------|------|------|
| GET | `/health` | 健康檢查 |
| GET | `/admin/scheduler/status` | 調度器狀態 |
| POST | `/admin/scheduler/force_update` | 強制更新 |

### 請求範例

```bash
# 發送OTP
curl -X POST http://localhost:5001/auth/send_otp \
  -H "Content-Type: application/json" \
  -d '{"phone": "+886912345678"}'

# 買入股票
curl -X POST http://localhost:5001/api/trading/buy \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_JWT_TOKEN" \
  -d '{"symbol": "2330.TW", "quantity": 100, "order_type": "market"}'
```

## 📁 項目結構

```
Invest_V3/
├── 📱 iOS App
│   ├── Invest_V3/
│   │   ├── 🔐 TradingAuthView.swift      # 認證介面
│   │   ├── 🏠 TradingMainView.swift      # 主頁面
│   │   ├── 📊 StockMarketView.swift      # 股票市場
│   │   ├── 💰 TradeOrderView.swift       # 交易下單
│   │   ├── 📈 PortfolioView.swift        # 投資組合
│   │   ├── 🏆 RankingsView.swift         # 排行榜
│   │   ├── 🔧 TradingService.swift       # API服務
│   │   ├── 📦 TradingModels.swift        # 資料模型
│   │   └── 🎨 Color+Hex.swift           # 設計系統
│   └── 📄 TradingAppView.swift           # 應用入口
│
├── 🚀 Backend API
│   ├── app.py                           # Flask主程式
│   ├── requirements.txt                 # Python依賴
│   ├── deploy.sh                       # 部署腳本
│   ├── services/
│   │   ├── 🔐 auth_service.py          # 認證服務
│   │   ├── 💾 db_service.py            # 資料庫服務
│   │   ├── 💰 trading_service.py       # 交易服務
│   │   ├── 📊 market_data_service.py   # 股價服務
│   │   └── ⏰ scheduler_service.py     # 調度器服務
│   └── 🗄️ Database
│       ├── setup_trading_tables.sql    # 建表腳本
│       └── setup_rankings_table.sql    # 排名表腳本
│
├── 🧪 Testing
│   ├── integration_test.py             # 整合測試
│   ├── test_scheduler.py              # 調度器測試
│   └── comprehensive_test.py          # 全面測試
│
└── 📚 Documentation
    ├── README.md                       # 本文件
    ├── PROJECT_SUMMARY.md             # 項目總結
    └── SETUP_GUIDE.md                 # 設置指南
```

## 🧪 測試指南

### 系統整合測試

```bash
# 確保後端服務運行
python app.py

# 在另一個終端運行測試
python integration_test.py
```

### 調度器功能測試

```bash
# 測試定時任務系統
python test_scheduler.py
```

### 手動API測試

```bash
# 健康檢查
curl http://localhost:5001/health

# 調度器狀態
curl http://localhost:5001/admin/scheduler/status

# 強制更新股價
curl -X POST http://localhost:5001/admin/scheduler/force_update
```

### iOS測試流程

1. **認證測試**: 輸入手機號 → 收到OTP → 成功登入
2. **股票瀏覽**: 查看股票列表 → 搜尋功能 → 股票詳情
3. **模擬交易**: 選擇股票 → 下單買入 → 確認交易
4. **投資組合**: 查看持股 → 檢查損益 → 交易記錄
5. **排行榜**: 查看自己排名 → 比較其他用戶績效

## 🚀 部署說明

### 本地開發環境

```bash
# 使用部署腳本
./deploy.sh
# 選擇選項 1: 開發模式
```

### 生產環境部署

#### 後端部署

```bash
# 1. 服務器準備
sudo apt update
sudo apt install python3 python3-pip postgresql

# 2. 應用部署
git clone <your-repo>
cd Invest_V3/invest_simulator_backend
pip install -r requirements.txt

# 3. 配置環境變數
cp .env.example .env
# 編輯 .env 填入生產配置

# 4. 使用部署腳本
./deploy.sh
# 選擇選項 2: 生產模式
```

#### iOS App部署

```bash
# 1. 更新後端URL
# 編輯 TradingService.swift
private let baseURL = "https://your-production-domain.com"

# 2. Archive & Upload
# Xcode → Product → Archive → Upload to App Store

# 3. TestFlight測試
# 邀請測試用戶通過TestFlight安裝
```

### Docker部署 (可選)

```dockerfile
# Dockerfile
FROM python:3.9-slim

WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt

COPY . .
EXPOSE 5001

CMD ["python", "app.py"]
```

```bash
# 構建和運行
docker build -t invest-simulator .
docker run -p 5001:5001 --env-file .env invest-simulator
```

## ❓ 常見問題

### Q: OTP簡訊沒收到怎麼辦？

**A:** 
- 檢查手機號格式 (需要包含國碼 +886)
- 開發模式下OTP會顯示在後端日誌中
- 確認Twilio配置是否正確

### Q: iOS應用無法連接到後端？

**A:**
- 確認後端服務正在運行 (`curl http://localhost:5001/health`)
- 檢查iOS模擬器網路設置
- 確認TradingService.swift中的baseURL設置正確

### Q: 股價數據不更新？

**A:**
- 檢查調度器狀態 (`curl http://localhost:5001/admin/scheduler/status`)
- 確認yfinance API可正常訪問
- 查看後端日誌是否有錯誤信息

### Q: 資料庫連接失敗？

**A:**
- 檢查Supabase配置 (URL和Service Key)
- 確認資料庫表格已正確創建
- 檢查網路連接和防火牆設置

### Q: iOS編譯錯誤？

**A:**
- 確認Xcode版本 (需要14+)
- 清理構建緩存 (Product → Clean Build Folder)
- 檢查Swift版本兼容性

### Q: 如何新增股票？

**A:**
- 編輯 `TaiwanStocks.popularStocks` 數組
- 在 `stockNames` 字典中添加對應的中文名稱
- 重啟後端服務使更改生效

### Q: 如何修改初始資金？

**A:**
- 編輯 `.env` 文件中的 `INITIAL_CAPITAL`
- 或在資料庫服務中修改 `self.initial_capital`

### Q: 如何自定義手續費？

**A:**
- 編輯 `TradingModels.swift` 中的 `TradingConstants`
- 修改 `BUY_FEE_RATE` 和 `SELL_FEE_RATE`

## 📞 技術支援

如果遇到問題，請按以下順序排查：

1. **查看日誌**: 後端日誌文件 `logs/app.log`
2. **檢查配置**: 確認 `.env` 文件配置正確
3. **重啟服務**: `./deploy.sh` 重新部署
4. **清理緩存**: Xcode Clean Build / 後端重新安裝依賴

## 📄 授權條款

本項目為教育和演示目的，請勿用於實際金融交易。

---

**開發完成時間**: 2025年7月16-17日  
**技術棧**: SwiftUI + Flask + PostgreSQL + Supabase  
**版本**: v1.0.0  

🎉 **準備好開始你的模擬交易之旅了嗎？**