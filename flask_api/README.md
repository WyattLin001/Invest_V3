# 📈 Invest_V3 Flask API 服務器

## 🚀 快速開始

### 1. 環境設置

```bash
# 創建虛擬環境
python3 -m venv venv
source venv/bin/activate  # macOS/Linux
# venv\Scripts\activate  # Windows

# 安裝依賴
pip install -r requirements.txt
```

### 2. 數據庫設置

```bash
# 在 Supabase Dashboard 中執行 setup_database.sql
# 或者使用 Supabase CLI
supabase db reset
```

### 3. Redis 設置 (可選)

```bash
# macOS with Homebrew
brew install redis
brew services start redis

# Ubuntu/Debian
sudo apt-get install redis-server
sudo systemctl start redis-server

# 或者使用 Docker
docker run -d --name redis -p 6379:6379 redis:alpine
```

### 4. 啟動服務器

```bash
# 開發模式
python app.py

# 生產模式
gunicorn --bind 0.0.0.0:5000 app:app
```

## 📡 API 端點

### GET /api/health
健康檢查端點

**回應:**
```json
{
  "status": "healthy",
  "timestamp": "2025-07-24T...",
  "redis_connected": true,
  "supabase_connected": true
}
```

### GET /api/quote?symbol=AAPL
獲取股票報價

**參數:**
- `symbol`: 股票代號 (必填)

**回應:**
```json
{
  "symbol": "AAPL",
  "name": "Apple Inc.",
  "current_price": 150.25,
  "previous_close": 149.80,
  "change": 0.45,
  "change_percent": 0.30,
  "timestamp": "2025-07-24T...",
  "currency": "USD"
}
```

### POST /api/trade
執行股票交易

**請求體:**
```json
{
  "user_id": "user_demo_001",
  "symbol": "AAPL",
  "action": "buy",
  "amount": 1000.00
}
```

**回應:**
```json
{
  "success": true,
  "transaction_id": "uuid...",
  "symbol": "AAPL",
  "action": "buy",
  "shares": 6.65,
  "price": 150.25,
  "total_amount": 1000.00,
  "fee": 1.425,
  "executed_at": "2025-07-24T...",
  "message": "買入成功"
}
```

### GET /api/portfolio?user_id=xxx
獲取投資組合

**參數:**
- `user_id`: 用戶 ID (必填)

**回應:**
```json
{
  "user_id": "user_demo_001",
  "total_value": 105000.00,
  "cash_balance": 95000.00,
  "market_value": 10000.00,
  "total_invested": 10000.00,
  "total_return": 0.00,
  "total_return_percent": 0.00,
  "positions": [
    {
      "symbol": "AAPL",
      "shares": 6.65,
      "average_price": 150.25,
      "current_price": 150.25,
      "market_value": 999.16,
      "unrealized_gain": -0.84,
      "unrealized_gain_percent": -0.08
    }
  ],
  "last_updated": "2025-07-24T..."
}
```

### GET /api/transactions?user_id=xxx&limit=50
獲取交易歷史

**參數:**
- `user_id`: 用戶 ID (必填)
- `limit`: 限制筆數 (默認 50)

**回應:**
```json
[
  {
    "id": "uuid...",
    "symbol": "AAPL",
    "action": "buy",
    "quantity": 6.65,
    "price": 150.25,
    "total_amount": 1000.00,
    "fee": 1.425,
    "executed_at": "2025-07-24T..."
  }
]
```

## 🔧 配置說明

### 環境變數
- `SUPABASE_URL`: Supabase 項目 URL
- `SUPABASE_KEY`: Supabase 匿名密鑰
- `REDIS_URL`: Redis 連接 URL (可選)

### 快取機制
- 股價數據快取 10 秒
- 優先使用 Redis，備用記憶體快取
- 自動緩存失效和更新

### 手續費設定
- 台股手續費率: 0.1425%
- 買入時從投資金額扣除
- 賣出時從賣出金額扣除

## 🛡️ 安全性

### 數據庫安全
- Row Level Security (RLS) 啟用
- 用戶只能存取自己的資料
- SQL 注入防護

### API 安全
- CORS 配置
- 請求參數驗證
- 錯誤訊息過濾

## 📊 監控和日誌

### 日誌等級
- INFO: 正常操作記錄
- ERROR: 錯誤和異常記錄
- DEBUG: 詳細調試信息

### 監控指標
- API 請求次數和響應時間
- 數據庫查詢性能
- 快取命中率
- 交易成功率

## 🚀 部署

### Fly.io 部署
```bash
# 安裝 Fly CLI
curl -L https://fly.io/install.sh | sh

# 登錄和初始化
fly auth login
fly launch

# 部署
fly deploy
```

### Docker 部署
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "app:app"]
```

## 🧪 測試

### 本地測試
```bash
# 健康檢查
curl http://localhost:5000/api/health

# 獲取股價
curl "http://localhost:5000/api/quote?symbol=AAPL"

# 執行交易
curl -X POST http://localhost:5000/api/trade \
  -H "Content-Type: application/json" \
  -d '{"user_id":"user_demo_001","symbol":"AAPL","action":"buy","amount":1000}'
```

### API 測試腳本
```python
import requests

base_url = "http://localhost:5000/api"

# 測試獲取股價
response = requests.get(f"{base_url}/quote?symbol=AAPL")
print(response.json())

# 測試交易
trade_data = {
    "user_id": "user_demo_001",
    "symbol": "AAPL", 
    "action": "buy",
    "amount": 1000
}
response = requests.post(f"{base_url}/trade", json=trade_data)
print(response.json())
```

## 📝 開發注意事項

1. **股價數據來源**: 使用 yfinance 庫，免費但有速率限制
2. **交易邏輯**: 目前為模擬交易，不涉及真實金錢
3. **用戶認證**: 簡化版本，生產環境需要完整的 JWT 認證
4. **錯誤處理**: 已包含基本的錯誤處理和日誌記錄
5. **性能優化**: Redis 快取和數據庫索引已配置