# 投資模擬交易平台後端

這是一個基於 Flask 的股票模擬交易平台後端 API，整合了 yfinance 股價數據和 Supabase 資料庫。

## 功能特色

- 📱 手機號碼 OTP 驗證註冊/登入
- 💰 模擬股票交易（買入/賣出）
- 📊 即時股價資料（透過 yfinance）
- 🏆 用戶排行榜系統
- 👥 好友邀請獎勵機制
- 📈 投資組合管理
- 📋 交易記錄追蹤
- 🔐 JWT 身份認證

## 技術架構

- **框架**: Flask 2.3.3
- **資料庫**: Supabase (PostgreSQL)
- **股價數據**: yfinance
- **認證**: JWT
- **簡訊服務**: Twilio
- **部署**: 支援 Docker 和雲端平台

## 快速開始

### 1. 環境設置

```bash
# 克隆專案
git clone <repository-url>
cd invest_simulator_backend

# 創建虛擬環境
python -m venv venv
source venv/bin/activate  # Linux/Mac
# 或 venv\Scripts\activate  # Windows

# 安裝套件
pip install -r requirements.txt
```

### 2. 環境變數設定

複製 `.env.example` 為 `.env` 並填入以下資訊：

```env
# Supabase 設定
SUPABASE_URL=your_supabase_project_url
SUPABASE_SERVICE_KEY=your_supabase_service_key
DATABASE_URL=your_postgres_connection_string

# JWT 設定
JWT_SECRET_KEY=your_jwt_secret_key_here

# Twilio 簡訊服務
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=your_twilio_phone_number

# 交易設定
INITIAL_CAPITAL=1000000
BROKER_FEE_RATE=0.001425
TAX_RATE=0.003
```

### 3. 資料庫初始化

在 Supabase 控制台的 SQL 編輯器中執行 `init_database.sql` 腳本：

```sql
-- 執行 init_database.sql 的內容
```

### 4. 運行應用

```bash
# 開發模式
python app.py

# 或使用 Flask CLI
flask run
```

應用將在 `http://localhost:5000` 啟動。

## API 文檔

### 認證端點

#### 發送 OTP
```http
POST /auth/send_otp
Content-Type: application/json

{
    "phone": "+886912345678"
}
```

#### 驗證 OTP
```http
POST /auth/verify_otp
Content-Type: application/json

{
    "phone": "+886912345678",
    "otp": "123456",
    "invite_code": "ABC12345"  // 選填
}
```

#### 取得用戶資料
```http
GET /auth/profile
Authorization: Bearer <jwt_token>
```

### 市場數據端點

#### 取得即時股價
```http
GET /api/quote?symbol=2330
Authorization: Bearer <jwt_token>
```

#### 取得歷史數據
```http
GET /api/history?symbol=2330&period=1mo&interval=1d
Authorization: Bearer <jwt_token>
```

### 交易端點

#### 執行交易
```http
POST /api/trade
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
    "symbol": "2330",
    "action": "buy",
    "quantity": 1000,
    "price_type": "market"
}
```

#### 取得投資組合
```http
GET /api/portfolio
Authorization: Bearer <jwt_token>
```

#### 取得交易記錄
```http
GET /api/transactions?limit=50&offset=0
Authorization: Bearer <jwt_token>
```

### 排行榜端點

#### 取得排行榜
```http
GET /api/rankings?period=weekly&limit=10
Authorization: Bearer <jwt_token>
```

#### 取得個人績效
```http
GET /api/performance
Authorization: Bearer <jwt_token>
```

### 好友邀請端點

#### 使用邀請碼
```http
POST /api/referral
Authorization: Bearer <jwt_token>
Content-Type: application/json

{
    "invite_code": "ABC12345"
}
```

## 服務架構

### 1. 資料庫服務 (DatabaseService)
- 用戶管理
- 持倉管理
- 交易記錄
- 排行榜計算

### 2. 市場數據服務 (MarketDataService)
- yfinance 整合
- 即時股價
- 歷史數據
- 股票資訊

### 3. 認證服務 (AuthService)
- OTP 發送/驗證
- JWT 管理
- 用戶註冊/登入

### 4. 交易服務 (TradingService)
- 交易執行
- 費用計算
- 持倉更新
- 損益計算

## 資料庫表結構

- **users**: 用戶基本資料
- **positions**: 持倉記錄
- **transactions**: 交易記錄
- **stocks**: 股票資訊
- **performance_snapshots**: 績效快照
- **referrals**: 邀請關係

## 開發指南

### 添加新的交易功能

1. 在 `TradingService` 中添加新方法
2. 在 `app.py` 中添加對應的路由
3. 更新 API 文檔

### 添加新的股票市場

1. 在 `MarketDataService` 中更新 `market_suffixes`
2. 在 `format_ticker` 方法中添加新的格式化邏輯
3. 更新股票清單資料

### 擴展認證方式

1. 在 `AuthService` 中添加新的認證方法
2. 更新 JWT 處理邏輯
3. 添加對應的 API 端點

## 測試

```bash
# 安裝測試依賴
pip install pytest pytest-cov

# 運行測試
pytest tests/

# 測試覆蓋率
pytest --cov=services tests/
```

## 部署

### Docker 部署

```bash
# 構建映像
docker build -t invest-simulator-backend .

# 運行容器
docker run -p 5000:5000 --env-file .env invest-simulator-backend
```

### 雲端部署

支援部署到：
- Heroku
- Railway
- Fly.io
- AWS EC2
- Google Cloud Run

## 安全考量

1. **環境變數保護**: 敏感資訊使用環境變數
2. **JWT 密鑰**: 使用強密鑰並定期更換
3. **API 限流**: 實施請求限制
4. **輸入驗證**: 所有用戶輸入都需驗證
5. **HTTPS**: 生產環境強制使用 HTTPS

## 監控與日誌

- 使用 Python logging 記錄關鍵操作
- 監控 API 回應時間
- 追蹤交易異常
- 設定資料庫性能監控

## 常見問題

### Q: yfinance 無法取得股價？
A: 檢查網路連線和股票代號格式，確保使用正確的市場後綴。

### Q: Supabase 連線失敗？
A: 檢查 SUPABASE_URL 和 SUPABASE_SERVICE_KEY 是否正確設定。

### Q: OTP 無法發送？
A: 檢查 Twilio 設定，開發模式下 OTP 會記錄在日誌中。

### Q: 交易執行失敗？
A: 檢查用戶餘額、持倉數量和股票代號是否正確。

## 支援

如有問題請聯繫開發團隊或查看專案文檔。

## 授權

此專案遵循 MIT 授權條款。