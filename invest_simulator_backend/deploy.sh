#!/bin/bash

# 投資模擬交易平台 - 部署腳本
# 用於快速部署後端服務

set -e  # 遇到錯誤立即退出

echo "🚀 投資模擬交易平台 - 後端部署腳本"
echo "======================================"

# 檢查Python環境
echo "🔍 檢查Python環境..."
if ! command -v python3 &> /dev/null; then
    echo "❌ Python3 未安裝，請先安裝Python3"
    exit 1
fi

echo "✅ Python版本: $(python3 --version)"

# 檢查pip
if ! command -v pip &> /dev/null; then
    echo "❌ pip 未安裝，請先安裝pip"
    exit 1
fi

# 安裝依賴
echo "📦 安裝Python依賴包..."
pip install -r requirements.txt

# 檢查環境變數
echo "🔧 檢查環境變數配置..."
ENV_FILE=".env"

if [ ! -f "$ENV_FILE" ]; then
    echo "⚠️  未找到 .env 文件，創建示例配置..."
    cat > $ENV_FILE << EOF
# Supabase 配置
SUPABASE_URL=your_supabase_url_here
SUPABASE_SERVICE_KEY=your_supabase_service_key_here

# JWT 配置
JWT_SECRET_KEY=your_jwt_secret_key_here

# Twilio SMS 配置 (可選)
TWILIO_ACCOUNT_SID=your_twilio_account_sid
TWILIO_AUTH_TOKEN=your_twilio_auth_token
TWILIO_PHONE_NUMBER=your_twilio_phone_number

# 交易配置
INITIAL_CAPITAL=1000000
REFERRAL_BONUS=100000

# 資料庫配置 (如果使用直接PostgreSQL連接)
DATABASE_URL=postgresql://user:password@host:port/database
EOF
    echo "📝 請編輯 .env 文件並填入正確的配置信息"
    echo "   特別是 SUPABASE_URL 和 SUPABASE_SERVICE_KEY"
fi

# 測試服務連接
echo "🔗 測試服務連接..."
if python3 -c "
import os
from dotenv import load_dotenv
load_dotenv()

# 檢查必需的環境變數
required_vars = ['SUPABASE_URL', 'SUPABASE_SERVICE_KEY', 'JWT_SECRET_KEY']
missing_vars = []

for var in required_vars:
    if not os.getenv(var) or os.getenv(var) == f'your_{var.lower()}_here':
        missing_vars.append(var)

if missing_vars:
    print(f'❌ 請在 .env 文件中設置以下環境變數: {missing_vars}')
    exit(1)
else:
    print('✅ 環境變數配置完成')
"; then
    echo "✅ 環境變數檢查通過"
else
    echo "❌ 環境變數配置有問題，請檢查 .env 文件"
    exit 1
fi

# 檢查端口
PORT=5001
echo "🔍 檢查端口 $PORT 是否可用..."
if lsof -i :$PORT &> /dev/null; then
    echo "⚠️  端口 $PORT 已被佔用，嘗試終止現有進程..."
    lsof -ti:$PORT | xargs kill -9 2>/dev/null || true
    sleep 2
fi

# 創建日誌目錄
echo "📁 創建日誌目錄..."
mkdir -p logs

# 啟動選項
echo "🎯 選擇啟動模式:"
echo "1) 開發模式 (前台運行，顯示日誌)"
echo "2) 生產模式 (後台運行，日誌輸出到文件)"
echo "3) 測試模式 (運行測試腳本)"
echo "4) 僅安裝依賴 (不啟動服務)"

read -p "請選擇 (1-4): " choice

case $choice in
    1)
        echo "🚀 啟動開發模式..."
        echo "按 Ctrl+C 停止服務"
        python3 app.py
        ;;
    2)
        echo "🚀 啟動生產模式..."
        nohup python3 app.py > logs/app.log 2>&1 &
        APP_PID=$!
        echo "✅ 服務已在後台啟動 (PID: $APP_PID)"
        echo "📋 日誌文件: logs/app.log"
        echo "🌐 服務地址: http://localhost:$PORT"
        echo "❓ 檢查狀態: curl http://localhost:$PORT/health"
        echo "⏹️  停止服務: kill $APP_PID"
        
        # 保存PID到文件
        echo $APP_PID > logs/app.pid
        ;;
    3)
        echo "🧪 運行系統測試..."
        if [ -f "integration_test.py" ]; then
            python3 integration_test.py
        else
            echo "❌ 未找到測試腳本 integration_test.py"
        fi
        ;;
    4)
        echo "✅ 依賴安裝完成"
        echo "🚀 手動啟動: python3 app.py"
        ;;
    *)
        echo "❌ 無效選擇"
        exit 1
        ;;
esac

echo "======================================"
echo "🎉 部署腳本執行完成"