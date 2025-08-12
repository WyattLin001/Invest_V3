#!/bin/bash

# 錦標賽高併發系統部署腳本
# 支援 10場錦標賽 x 100人同時交易

set -e  # 遇到錯誤時停止執行

echo "🚀 開始部署錦標賽高併發交易系統..."
echo "📊 目標: 支援 10場錦標賽 x 100人 = 1000人同時交易"
echo "=================================="

# 顏色定義
RED='\033[0;31m'
GREEN='\033[0;32m' 
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 函數：打印帶顏色的消息
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️ $1${NC}"
}

# 1. 環境檢查
echo "🔍 環境檢查..."

# 檢查 Python 版本
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version | cut -d' ' -f2)
    print_status "Python 版本: $PYTHON_VERSION"
else
    print_error "Python 3 未安裝"
    exit 1
fi

# 檢查 pip
if command -v pip3 &> /dev/null; then
    print_status "pip3 已安裝"
else
    print_error "pip3 未安裝"
    exit 1
fi

# 檢查 Redis（可選）
if command -v redis-server &> /dev/null; then
    print_status "Redis 已安裝"
    REDIS_STATUS=$(redis-cli ping 2>/dev/null || echo "未運行")
    if [ "$REDIS_STATUS" = "PONG" ]; then
        print_status "Redis 服務運行中"
    else
        print_warning "Redis 未運行，系統將使用記憶體快取"
    fi
else
    print_warning "Redis 未安裝，建議安裝以提升性能"
fi

# 2. 安裝 Python 依賴
echo ""
echo "📦 安裝 Python 依賴..."

# 創建虛擬環境（如果不存在）
if [ ! -d "venv" ]; then
    print_info "創建虛擬環境..."
    python3 -m venv venv
fi

# 啟動虛擬環境
source venv/bin/activate
print_status "虛擬環境已啟動"

# 升級 pip
pip install --upgrade pip

# 安裝依賴
echo "安裝 Flask 和相關依賴..."
pip install flask flask-cors gunicorn gevent

echo "安裝數據庫和快取依賴..."
pip install supabase redis psycopg2-binary

echo "安裝數據處理依賴..."
pip install pandas yfinance requests

echo "安裝系統監控依賴..."
pip install psutil

echo "安裝異步處理依賴..."
pip install asyncio aiohttp

print_status "所有依賴安裝完成"

# 3. 創建必要目錄
echo ""
echo "📁 創建目錄結構..."

mkdir -p logs
mkdir -p data/backup
mkdir -p config
mkdir -p static
mkdir -p tests

print_status "目錄結構創建完成"

# 4. 配置文件設置
echo ""
echo "⚙️ 配置文件設置..."

# 創建環境變量文件
cat > .env << EOF
# 錦標賽高併發系統環境變量

# Flask 配置
FLASK_ENV=production
FLASK_APP=app.py
FLASK_RUN_HOST=0.0.0.0
FLASK_RUN_PORT=5001

# Gunicorn 配置
GUNICORN_WORKERS=8
GUNICORN_THREADS=4
GUNICORN_TIMEOUT=30
GUNICORN_KEEPALIVE=5

# Redis 配置
REDIS_HOST=localhost
REDIS_PORT=6379
REDIS_DB=0

# Supabase 配置
SUPABASE_URL=https://wujlbjrouqcpnifbakmw.supabase.co
# 注意：生產環境應使用環境變量設置密鑰

# 系統配置
LOG_LEVEL=INFO
MAX_CONCURRENT_TRADES=1000
CACHE_TIMEOUT=10

# 監控配置
ENABLE_METRICS=true
METRICS_PORT=9090
EOF

print_status "環境變量配置完成"

# 5. 數據庫初始化檢查
echo ""
echo "🗄️ 數據庫檢查..."

if python3 -c "
import sys
sys.path.insert(0, '.')
try:
    from app import supabase
    result = supabase.table('tournaments').select('id').limit(1).execute()
    print('✅ Supabase 連接正常')
except Exception as e:
    print(f'❌ Supabase 連接失敗: {e}')
    sys.exit(1)
" 2>/dev/null; then
    print_status "數據庫連接檢查通過"
else
    print_warning "數據庫連接檢查失敗，請檢查 Supabase 配置"
    print_info "請確保已執行 tournament_schema.sql 創建錦標賽表結構"
fi

# 6. 性能測試
echo ""
echo "🧪 簡單性能測試..."

# 創建測試腳本
cat > quick_test.py << 'EOF'
#!/usr/bin/env python3
import time
import requests
import json
from concurrent.futures import ThreadPoolExecutor
import sys

def test_health_endpoint():
    """測試健康檢查端點"""
    try:
        response = requests.get('http://localhost:5001/api/health', timeout=10)
        return response.status_code == 200
    except:
        return False

def test_concurrent_requests(num_requests=50):
    """測試併發請求"""
    def make_request():
        try:
            response = requests.get('http://localhost:5001/api/taiwan-stocks', timeout=5)
            return response.status_code == 200
        except:
            return False
    
    start_time = time.time()
    with ThreadPoolExecutor(max_workers=10) as executor:
        results = list(executor.map(lambda _: make_request(), range(num_requests)))
    end_time = time.time()
    
    success_count = sum(results)
    total_time = end_time - start_time
    
    print(f"併發測試結果:")
    print(f"  請求數: {num_requests}")
    print(f"  成功數: {success_count}")
    print(f"  成功率: {success_count/num_requests*100:.1f}%")
    print(f"  總時間: {total_time:.2f}s")
    print(f"  平均 RPS: {num_requests/total_time:.1f}")
    
    return success_count/num_requests >= 0.9  # 90% 成功率

if __name__ == "__main__":
    print("🚀 啟動快速測試...")
    
    # 等待服務啟動
    print("等待服務啟動...")
    for i in range(30):  # 等待最多30秒
        if test_health_endpoint():
            print("✅ 服務已就緒")
            break
        time.sleep(1)
    else:
        print("❌ 服務啟動超時")
        sys.exit(1)
    
    # 執行併發測試
    if test_concurrent_requests():
        print("✅ 併發測試通過")
        sys.exit(0)
    else:
        print("❌ 併發測試失敗")
        sys.exit(1)
EOF

# 7. 創建啟動腳本
echo ""
echo "📜 創建啟動腳本..."

# 開發環境啟動腳本
cat > start_dev.sh << 'EOF'
#!/bin/bash
echo "🔧 啟動開發環境..."
source venv/bin/activate
export FLASK_ENV=development
export FLASK_DEBUG=1
python3 app.py
EOF
chmod +x start_dev.sh

# 生產環境啟動腳本
cat > start_prod.sh << 'EOF'
#!/bin/bash
echo "🚀 啟動生產環境（高併發模式）..."
source venv/bin/activate

# 載入環境變量
if [ -f .env ]; then
    export $(cat .env | grep -v '#' | awk '/=/ {print $1}')
fi

# 創建日誌目錄
mkdir -p logs

# 使用 Gunicorn 啟動高併發服務
echo "🎯 啟動 Gunicorn 高併發服務器..."
echo "📊 配置: 支援 1000+ 併發連接"

gunicorn app:app \
    --config gunicorn_config.py \
    --daemon \
    --pid gunicorn.pid

if [ $? -eq 0 ]; then
    echo "✅ Gunicorn 服務器啟動成功"
    echo "🌐 服務地址: http://0.0.0.0:5001"
    echo "📊 監控地址: http://0.0.0.0:5001/api/health"
    echo "🏆 錦標賽 API: http://0.0.0.0:5001/api/tournament/"
    echo "📈 性能測試: http://0.0.0.0:5001/api/tournament/performance-metrics"
    
    # 等待服務就緒
    sleep 3
    
    # 執行快速健康檢查
    if curl -s http://localhost:5001/api/health > /dev/null; then
        echo "✅ 服務健康檢查通過"
    else
        echo "⚠️ 服務健康檢查失敗，請查看日誌"
    fi
    
else
    echo "❌ Gunicorn 服務器啟動失敗"
    exit 1
fi
EOF
chmod +x start_prod.sh

# 停止腳本
cat > stop.sh << 'EOF'
#!/bin/bash
echo "🛑 停止錦標賽交易系統..."

if [ -f gunicorn.pid ]; then
    PID=$(cat gunicorn.pid)
    echo "正在停止 Gunicorn (PID: $PID)..."
    kill $PID
    sleep 2
    
    if kill -0 $PID 2>/dev/null; then
        echo "強制停止 Gunicorn..."
        kill -9 $PID
    fi
    
    rm -f gunicorn.pid
    echo "✅ 服務已停止"
else
    echo "⚠️ 未找到 Gunicorn PID 文件"
fi

# 清理其他可能的進程
pkill -f "python.*app.py" || true
pkill -f "gunicorn.*app:app" || true

echo "🧹 清理完成"
EOF
chmod +x stop.sh

print_status "啟動腳本創建完成"

# 8. 創建監控腳本
echo ""
echo "📊 創建監控腳本..."

cat > monitor.sh << 'EOF'
#!/bin/bash
echo "📊 錦標賽系統監控儀表板"
echo "================================"

while true; do
    clear
    echo "📊 錦標賽高併發交易系統監控 - $(date)"
    echo "================================"
    
    # 系統資源監控
    echo "💻 系統資源:"
    echo "  CPU: $(top -l 1 -s 0 | grep "CPU usage" | awk '{print $3}' | sed 's/%//')"
    echo "  內存: $(ps -caxm -orss,comm | awk '{ sum += $1 } END { printf "%.2f MB", sum / 1024 }')"
    
    # Gunicorn 進程監控
    echo ""
    echo "🏃 Gunicorn 進程:"
    ps aux | grep gunicorn | grep -v grep | awk '{print "  PID:", $2, "CPU:", $3"%", "MEM:", $4"%"}'
    
    # 網絡連接監控
    echo ""
    echo "🌐 網絡連接:"
    CONNECTIONS=$(netstat -an | grep :5001 | grep ESTABLISHED | wc -l)
    echo "  活躍連接數: $CONNECTIONS"
    
    # API 健康檢查
    echo ""
    echo "🏥 API 健康狀態:"
    HEALTH_RESPONSE=$(curl -s http://localhost:5001/api/health || echo "連接失敗")
    if [[ $HEALTH_RESPONSE == *"healthy"* ]]; then
        echo "  ✅ API 服務正常"
    else
        echo "  ❌ API 服務異常"
    fi
    
    # 錦標賽統計
    echo ""
    echo "🏆 錦標賽統計:"
    TOURNAMENT_STATS=$(curl -s http://localhost:5001/api/tournament/active-tournaments | jq -r '.total_count // "N/A"' 2>/dev/null || echo "N/A")
    echo "  活躍錦標賽數: $TOURNAMENT_STATS"
    
    echo ""
    echo "按 Ctrl+C 退出監控..."
    sleep 5
done
EOF
chmod +x monitor.sh

print_status "監控腳本創建完成"

# 9. 創建快速命令參考
echo ""
echo "📚 創建命令參考..."

cat > README_DEPLOYMENT.md << 'EOF'
# 錦標賽高併發交易系統部署指南

## 🎯 系統目標
支援 **10場錦標賽 x 100人 = 1000人同時交易**

## 🚀 快速啟動

### 開發環境
```bash
./start_dev.sh
```

### 生產環境
```bash
./start_prod.sh
```

### 停止服務
```bash
./stop.sh
```

### 監控系統
```bash
./monitor.sh
```

## 📡 API 端點

### 基礎 API
- **健康檢查**: `GET /api/health`
- **股票報價**: `GET /api/quote?symbol=2330`
- **一般交易**: `POST /api/trade`

### 錦標賽 API (高併發優化)
- **錦標賽交易**: `POST /api/tournament/{id}/trade`
- **批量交易**: `POST /api/tournament/{id}/batch-trade`
- **實時排行榜**: `GET /api/tournament/{id}/leaderboard`
- **用戶排名**: `GET /api/tournament/{id}/user-rank/{user_id}`
- **錦標賽統計**: `GET /api/tournament/{id}/stats`
- **性能指標**: `GET /api/tournament/performance-metrics`
- **負載測試**: `POST /api/tournament/load-test` (開發環境)

### 監控端點
- **系統健康**: `GET /api/tournament/health-check`
- **活躍錦標賽**: `GET /api/tournament/active-tournaments`

## 🔧 配置文件

### 環境變量 (.env)
- `FLASK_ENV`: 運行環境 (development/production)
- `GUNICORN_WORKERS`: Gunicorn 工作進程數
- `REDIS_HOST`: Redis 主機地址
- `SUPABASE_URL`: Supabase 數據庫 URL

### Gunicorn 配置 (gunicorn_config.py)
- 多進程 + 異步工作模式
- 優化的超時和連接設置
- 完整的監控和日誌配置

## 📊 性能指標

### 預期性能
- **併發連接數**: 1000+
- **TPS (每秒交易數)**: 500-1000
- **響應時間**: < 100ms (P95)
- **可用性**: 99.9%+

### 監控指標
- CPU 使用率 < 80%
- 內存使用率 < 70%
- Redis 命中率 > 90%
- 數據庫連接池使用率 < 80%

## 🚨 故障排除

### 常見問題
1. **Redis 連接失敗**: 檢查 Redis 服務是否運行
2. **Supabase 連接超時**: 檢查網絡和密鑰配置
3. **高 CPU 使用率**: 調整 Gunicorn 工作進程數
4. **內存洩漏**: 檢查 max_requests 設置

### 日誌位置
- **Gunicorn 訪問日誌**: `logs/gunicorn_access.log`
- **Gunicorn 錯誤日誌**: `logs/gunicorn_error.log`
- **應用程序日誌**: `logs/app_worker_*.log`

## 📈 擴展建議

### 水平擴展
1. 使用負載均衡器 (Nginx)
2. 部署多個應用實例
3. 使用 Redis Cluster
4. 數據庫讀寫分離

### 垂直擴展
1. 增加 CPU 核心數
2. 增加內存容量
3. 使用 SSD 存儲
4. 優化網絡帶寬

## 🔐 安全建議

1. 使用環境變量存儲敏感信息
2. 啟用 HTTPS (生產環境)
3. 設置請求頻率限制
4. 定期更新依賴包
5. 監控異常活動

## 📞 支援聯繫

如遇問題，請查看日誌文件或聯繫技術支援。
EOF

print_status "部署文檔創建完成"

# 完成部署
echo ""
echo "🎉 部署完成！"
echo "================================"
print_status "錦標賽高併發交易系統已成功部署"
echo ""
echo "🚀 啟動命令:"
echo "  開發環境: ./start_dev.sh"  
echo "  生產環境: ./start_prod.sh"
echo "  系統監控: ./monitor.sh"
echo "  停止服務: ./stop.sh"
echo ""
echo "📖 詳細文檔: README_DEPLOYMENT.md"
echo "🌐 服務地址: http://localhost:5001"
echo "📊 健康檢查: http://localhost:5001/api/health"
echo "🏆 錦標賽 API: http://localhost:5001/api/tournament/"
echo ""
print_info "建議先在開發環境測試，確認無誤後再切換到生產環境"
echo "================================"