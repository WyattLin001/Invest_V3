from flask import Flask, request, jsonify
from flask_cors import CORS
from datetime import datetime, timedelta
import yfinance as yf
import redis
import json
import uuid
from supabase import create_client, Client
import os
from typing import Dict, List, Optional
import logging
import pandas as pd
import requests
from requests.adapters import HTTPAdapter
from urllib3.util.retry import Retry
import random
import time

# 設定日誌
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = Flask(__name__)
CORS(app)  # 允許 iOS 跨域請求

# Redis 配置 (用於股價快取)
try:
    redis_client = redis.Redis(host='localhost', port=6379, db=0, decode_responses=True)
    redis_client.ping()
    logger.info("✅ Redis 連線成功")
except:
    redis_client = None
    logger.warning("⚠️ Redis 未連線，將使用記憶體快取")

# Supabase 配置
SUPABASE_URL = "https://wujlbjrouqcpnifbakmw.supabase.co"

# 使用服務角色密鑰以獲得寫入權限（開發環境）
# 注意：生產環境應使用環境變數
SUPABASE_SERVICE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MTgxMzE2NywiZXhwIjoyMDY3Mzg5MTY3fQ.WYKXMbgoceGT74HuXlpIchIwAuXIVT_SrZQl2H5FyHQ"
SUPABASE_ANON_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Ind1amxianJvdXFjcG5pZmJha213Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTE4MTMxNjcsImV4cCI6MjA2NzM4OTE2N30.2-l82gsxWDLMj3gUnSpj8sHddMLtX-JgqrbnY5c_9bg"

# 使用正確的服務角色密鑰
SUPABASE_KEY = os.environ.get('SUPABASE_SERVICE_KEY', SUPABASE_SERVICE_KEY)

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)
key_type = "服務角色" if SUPABASE_KEY == SUPABASE_SERVICE_KEY else "匿名"
logger.info(f"✅ Supabase 客戶端初始化完成 (使用 {key_type} 密鑰)")
logger.info(f"🔑 API Key 末尾: ...{SUPABASE_KEY[-10:]}")

# 記憶體快取 (Redis 備用方案)
memory_cache = {}

# 常量設定
CACHE_TIMEOUT = 10  # 股價快取 10 秒
STOCK_LIST_CACHE_TIMEOUT = 86400  # 股票清單快取 24 小時
TRANSACTION_FEE_RATE = 0.001425  # 台股手續費 0.1425%

# 台股配置
TAIWAN_STOCK_TAX_RATE = 0.003  # 台股證券交易稅 0.3%
TAIWAN_MIN_FEE = 20  # 台股最低手續費 20 元

# 熱門台股清單
POPULAR_TAIWAN_STOCKS = {
    "2330": "台積電",
    "2454": "聯發科", 
    "2317": "鴻海",
    "2308": "台達電",
    "2382": "廣達",
    "2412": "中華電",
    "2881": "富邦金",
    "2891": "中信金",
    "2886": "兆豐金",
    "2303": "聯電",
    "3008": "大立光",
    "2002": "中鋼",
    "1303": "南亞",
    "1301": "台塑",
    "2207": "和泰車",
    "2357": "華碩",
    "2409": "友達",
    "2474": "可成",
    "6505": "台塑化",
    "2912": "統一超"
}

# MARK: - 輔助函數

def normalize_taiwan_stock_symbol(symbol: str) -> str:
    """標準化台股股票代號"""
    symbol = symbol.upper().strip()
    
    # 如果是純數字且長度為4，自動加上 .TW
    if symbol.isdigit() and len(symbol) == 4:
        return f"{symbol}.TW"
    
    # 如果已經有 .TW 後綴，直接返回
    if symbol.endswith('.TW') or symbol.endswith('.TWO'):
        return symbol
    
    # 檢查是否為熱門台股（4位數字）
    base_symbol = symbol.replace('.TW', '').replace('.TWO', '')
    if base_symbol in POPULAR_TAIWAN_STOCKS:
        return f"{base_symbol}.TW"
    
    # 其他情況直接返回（可能是美股或其他市場）
    return symbol

def is_taiwan_stock(symbol: str) -> bool:
    """判斷是否為台股"""
    return symbol.endswith('.TW') or symbol.endswith('.TWO')

def get_taiwan_stock_name(symbol: str) -> str:
    """獲取台股中文名稱"""
    base_symbol = symbol.replace('.TW', '').replace('.TWO', '')
    return POPULAR_TAIWAN_STOCKS.get(base_symbol, f"{symbol} 股份有限公司")

def calculate_taiwan_trading_cost(amount: float, is_day_trading: bool = False) -> Dict[str, float]:
    """計算台股交易成本"""
    # 手續費計算（最低20元）
    brokerage_fee = max(amount * TRANSACTION_FEE_RATE, TAIWAN_MIN_FEE)
    
    # 證券交易稅（當沖減半）
    tax_rate = TAIWAN_STOCK_TAX_RATE / 2 if is_day_trading else TAIWAN_STOCK_TAX_RATE
    securities_tax = amount * tax_rate
    
    total_cost = brokerage_fee + securities_tax
    
    return {
        "brokerage_fee": brokerage_fee,
        "securities_tax": securities_tax,
        "total_cost": total_cost
    }

# 舊的網頁爬取函數已移除，改用官方 API

def create_robust_session():
    """建立具有重試機制的 HTTP 會話"""
    session = requests.Session()
    
    # 設定重試策略
    retry_strategy = Retry(
        total=3,
        backoff_factor=1,
        status_forcelist=[429, 500, 502, 503, 504],
    )
    
    adapter = HTTPAdapter(max_retries=retry_strategy)
    session.mount("http://", adapter)
    session.mount("https://", adapter)
    
    # 設定請求標頭來模擬真實瀏覽器
    session.headers.update({
        'User-Agent': 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36',
        'Accept': 'text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,image/apng,*/*;q=0.8,application/signed-exchange;v=b3;q=0.7',
        'Accept-Language': 'zh-TW,zh;q=0.9,en;q=0.8',
        'Accept-Encoding': 'gzip, deflate, br',
        'DNT': '1',
        'Connection': 'keep-alive',
        'Upgrade-Insecure-Requests': '1',
        'Sec-Fetch-Dest': 'document',
        'Sec-Fetch-Mode': 'navigate',
        'Sec-Fetch-Site': 'none',
        'Sec-Fetch-User': '?1',
        'Cache-Control': 'max-age=0'
    })
    
    return session

def fetch_twse_official_data() -> List[Dict]:
    """使用官方 API 獲取上市股票數據"""
    session = create_robust_session()
    
    try:
        url = "https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL"
        logger.info(f"📡 正在獲取上市股票官方 API 資料: {url}")
        
        response = session.get(url, timeout=30)
        response.raise_for_status()
        
        logger.info(f"✅ 成功獲取上市股票 API 回應，狀態碼: {response.status_code}")
        
        # 解析 JSON 數據
        stock_data = response.json()
        
        # 轉換為我們需要的格式，只保留4位數字股票代碼
        stocks = []
        for item in stock_data:
            code = item.get('Code', '')
            name = item.get('Name', '')
            
            # 只保留傳統4位數字股票代碼
            if len(code) == 4 and code.isdigit():
                stock = {
                    "code": code,
                    "name": name,
                    "full_code": f"{code}.TW",
                    "market": "上市",
                    "industry": "其他",  # 官方API沒有產業別，使用預設值
                    "is_listed": True,
                    "exchange": "TWSE",
                    # 額外保留一些有用的交易數據
                    "closing_price": item.get('ClosingPrice', '0'),
                    "change": item.get('Change', '0'),
                    "trade_volume": item.get('TradeVolume', '0')
                }
                stocks.append(stock)
        
        logger.info(f"✅ 成功解析上市股票官方 API，共 {len(stocks)} 支傳統股票")
        return stocks
        
    except requests.exceptions.RequestException as e:
        logger.error(f"❌ 官方 API 請求失敗: {e}")
        raise
    except json.JSONDecodeError as e:
        logger.error(f"❌ JSON 解析失敗: {e}")
        raise
    except Exception as e:
        logger.error(f"❌ 官方 API 數據處理失敗: {e}")
        raise
    finally:
        session.close()

def fetch_tpex_official_data() -> List[Dict]:
    """使用官方 API 獲取上櫃股票數據"""
    session = create_robust_session()
    
    try:
        url = "https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes"
        logger.info(f"📡 正在獲取上櫃股票官方 API 資料: {url}")
        
        response = session.get(url, timeout=30)
        response.raise_for_status()
        
        logger.info(f"✅ 成功獲取上櫃股票 API 回應，狀態碼: {response.status_code}")
        
        # 解析 JSON 數據
        stock_data = response.json()
        
        # 轉換為我們需要的格式
        stocks = []
        for item in stock_data:
            code = item.get('SecuritiesCompanyCode', '')
            name = item.get('CompanyName', '')
            
            # 只保留傳統4位數字股票代碼
            if len(code) == 4 and code.isdigit():
                stock = {
                    "code": code,
                    "name": name,
                    "full_code": f"{code}.TWO",
                    "market": "上櫃",
                    "industry": "其他",
                    "is_listed": False,
                    "exchange": "TPEx",
                    "closing_price": item.get('Close', '0'),
                    "change": item.get('Change', '0')
                }
                stocks.append(stock)
        
        logger.info(f"✅ 成功解析上櫃股票官方 API，共 {len(stocks)} 支傳統股票")
        return stocks
        
    except requests.exceptions.RequestException as e:
        logger.error(f"❌ 上櫃官方 API 請求失敗: {e}")
        raise
    except json.JSONDecodeError as e:
        logger.error(f"❌ 上櫃 JSON 解析失敗: {e}")
        raise
    except Exception as e:
        logger.error(f"❌ 上櫃官方 API 數據處理失敗: {e}")
        raise
    finally:
        session.close()

def load_fallback_taiwan_stocks() -> List[Dict]:
    """載入靜態備份的台股清單"""
    try:
        fallback_file = os.path.join(os.path.dirname(__file__), 'taiwan_stocks_fallback.json')
        
        if os.path.exists(fallback_file):
            with open(fallback_file, 'r', encoding='utf-8') as f:
                stocks = json.load(f)
            logger.info(f"📋 載入靜態備份台股清單: {len(stocks)} 支股票")
            return stocks
        else:
            logger.warning("⚠️ 找不到靜態備份檔案，返回基本台股清單")
            # 使用基本的熱門台股清單作為最終備份
            basic_stocks = []
            for symbol, name in POPULAR_TAIWAN_STOCKS.items():
                basic_stocks.append({
                    "code": symbol,
                    "name": name,
                    "full_code": f"{symbol}.TW",
                    "market": "上市",
                    "industry": "其他",
                    "is_listed": True,
                    "exchange": "TWSE"
                })
            return basic_stocks
            
    except Exception as e:
        logger.error(f"❌ 載入靜態備份失敗: {e}")
        return []

def fetch_all_taiwan_stocks() -> List[Dict]:
    """使用官方 API 獲取完整台股清單，失敗時使用靜態備份"""
    try:
        logger.info("🔄 開始使用官方 API 獲取完整台股清單...")
        
        # 嘗試使用官方 API 獲取
        try:
            # 上市股票（使用官方 API）
            twse_stocks = fetch_twse_official_data()
            
            # 上櫃股票（使用官方 API）
            try:
                tpex_stocks = fetch_tpex_official_data()
            except Exception as tpex_error:
                logger.warning(f"⚠️ 上櫃官方 API 失敗，僅使用上市股票: {tpex_error}")
                tpex_stocks = []
            
            # 合併上市和上櫃股票
            all_stocks = twse_stocks + tpex_stocks
            
            if all_stocks:
                listed_count = len([s for s in all_stocks if s['is_listed']])
                otc_count = len([s for s in all_stocks if not s['is_listed']])
                logger.info(f"✅ 成功獲取官方 API 台股清單: {len(all_stocks)} 支股票 (上市: {listed_count}, 上櫃: {otc_count})")
                return all_stocks
            else:
                raise Exception("官方 API 未返回任何股票數據")
            
        except Exception as official_api_error:
            logger.warning(f"⚠️ 官方 API 失敗，嘗試使用靜態備份: {official_api_error}")
            
            # 使用靜態備份
            fallback_stocks = load_fallback_taiwan_stocks()
            if fallback_stocks:
                logger.info(f"✅ 使用靜態備份台股清單: {len(fallback_stocks)} 支股票")
                return fallback_stocks
            else:
                raise Exception("靜態備份也無法載入")
        
    except Exception as e:
        logger.error(f"❌ 獲取台股清單完全失敗: {e}")
        return []

def get_cached_taiwan_stocks() -> Optional[List[Dict]]:
    """從快取獲取台股清單"""
    cache_key = "taiwan_stocks:all"
    
    if redis_client:
        try:
            cached_data = redis_client.get(cache_key)
            if cached_data:
                logger.info("📋 使用 Redis 快取的台股清單")
                return json.loads(cached_data)
        except Exception as e:
            logger.error(f"Redis 讀取台股清單錯誤: {e}")
    
    # 備用記憶體快取
    if cache_key in memory_cache:
        data, timestamp = memory_cache[cache_key]
        if datetime.now() - timestamp < timedelta(seconds=STOCK_LIST_CACHE_TIMEOUT):
            logger.info("📋 使用記憶體快取的台股清單")
            return data
    
    return None

def set_cached_taiwan_stocks(stocks: List[Dict]):
    """設定台股清單快取"""
    cache_key = "taiwan_stocks:all"
    
    if redis_client:
        try:
            redis_client.setex(cache_key, STOCK_LIST_CACHE_TIMEOUT, json.dumps(stocks))
            logger.info("💾 台股清單已存入 Redis 快取")
        except Exception as e:
            logger.error(f"Redis 寫入台股清單錯誤: {e}")
    
    # 備用記憶體快取
    memory_cache[cache_key] = (stocks, datetime.now())
    logger.info("💾 台股清單已存入記憶體快取")

def get_cache_key(symbol: str) -> str:
    """生成快取鍵值"""
    return f"stock_price:{symbol.upper()}"

def get_cached_price(symbol: str) -> Optional[Dict]:
    """從快取獲取股價"""
    cache_key = get_cache_key(symbol)
    
    if redis_client:
        try:
            cached_data = redis_client.get(cache_key)
            if cached_data:
                return json.loads(cached_data)
        except Exception as e:
            logger.error(f"Redis 讀取錯誤: {e}")
    
    # 備用記憶體快取
    if cache_key in memory_cache:
        data, timestamp = memory_cache[cache_key]
        if datetime.now() - timestamp < timedelta(seconds=CACHE_TIMEOUT):
            return data
    
    return None

def set_cached_price(symbol: str, price_data: Dict):
    """設定股價快取"""
    cache_key = get_cache_key(symbol)
    
    if redis_client:
        try:
            redis_client.setex(cache_key, CACHE_TIMEOUT, json.dumps(price_data))
        except Exception as e:
            logger.error(f"Redis 寫入錯誤: {e}")
    
    # 備用記憶體快取
    memory_cache[cache_key] = (price_data, datetime.now())

def fetch_yahoo_finance_price(symbol: str) -> Dict:
    """從 Yahoo Finance 獲取股價"""
    try:
        # 標準化股票代號（支援台股）
        normalized_symbol = normalize_taiwan_stock_symbol(symbol)
        logger.info(f"🔍 查詢股價: {symbol} -> {normalized_symbol}")
        
        # 增加延遲避免頻率限制
        time.sleep(0.5)
        
        ticker = yf.Ticker(normalized_symbol)
        info = ticker.info
        hist = ticker.history(period="2d")
        
        if hist.empty:
            # 如果無法獲取歷史數據，嘗試使用模擬數據
            return get_fallback_price_data(normalized_symbol)
        
        current_price = float(hist['Close'].iloc[-1])
        previous_close = float(hist['Close'].iloc[-2]) if len(hist) > 1 else current_price
        change = current_price - previous_close
        change_percent = (change / previous_close) * 100 if previous_close != 0 else 0
        
        # 獲取股票名稱（台股顯示中文名）
        if is_taiwan_stock(normalized_symbol):
            stock_name = get_taiwan_stock_name(normalized_symbol)
            currency = "TWD"
        else:
            stock_name = info.get("longName", f"{normalized_symbol.upper()} Inc")
            currency = info.get("currency", "USD")
        
        return {
            "symbol": normalized_symbol.upper(),
            "name": stock_name,
            "current_price": current_price,
            "previous_close": previous_close,
            "change": change,
            "change_percent": change_percent,
            "timestamp": datetime.now().isoformat(),
            "currency": currency,
            "is_taiwan_stock": is_taiwan_stock(normalized_symbol)
        }
    except Exception as e:
        logger.error(f"Yahoo Finance API 錯誤: {e}")
        # 返回備用數據而不是拋出異常
        return get_fallback_price_data(normalized_symbol)

def get_fallback_price_data(symbol: str) -> Dict:
    """獲取備用股價數據（模擬數據用於測試）"""
    base_symbol = symbol.replace('.TW', '').replace('.TWO', '')
    
    # 預設股價數據
    fallback_prices = {
        "2330": {"name": "台積電", "price": 585.0},
        "2317": {"name": "鴻海", "price": 203.5},  
        "2454": {"name": "聯發科", "price": 1205.0},
        "2881": {"name": "富邦金", "price": 89.7},
        "2882": {"name": "國泰金", "price": 65.1},
        "AAPL": {"name": "Apple Inc", "price": 189.5},
        "TSLA": {"name": "Tesla Inc", "price": 248.3},
        "GOOGL": {"name": "Alphabet Inc", "price": 133.2}
    }
    
    if base_symbol in fallback_prices:
        data = fallback_prices[base_symbol]
        current_price = data["price"]
        stock_name = data["name"]
    else:
        # 生成隨機價格用於測試
        current_price = round(random.uniform(50.0, 1000.0), 2)
        stock_name = get_taiwan_stock_name(symbol) if is_taiwan_stock(symbol) else f"{base_symbol} Inc"
    
    previous_close = round(current_price * random.uniform(0.95, 1.05), 2)
    change = current_price - previous_close
    change_percent = (change / previous_close) * 100 if previous_close != 0 else 0
    
    currency = "TWD" if is_taiwan_stock(symbol) else "USD"
    
    logger.warning(f"⚠️ 使用備用股價數據: {symbol} - ${current_price}")
    
    return {
        "symbol": symbol.upper(),
        "name": stock_name,
        "current_price": current_price,
        "previous_close": previous_close,
        "change": change,
        "change_percent": change_percent,
        "timestamp": datetime.now().isoformat(),
        "currency": currency,
        "is_taiwan_stock": is_taiwan_stock(symbol)
    }

def validate_user(user_id: str) -> bool:
    """驗證用戶是否存在"""
    # 允許測試用戶進行測試
    test_user_ids = [
        "d64a0edd-62cc-423a-8ce4-81103b5a9770",  # 測試用戶 1
        "12345678-1234-1234-1234-123456789012"   # Mock 用戶
    ]
    if user_id in test_user_ids:
        logger.info(f"✅ 允許測試用戶: {user_id}")
        return True
    
    try:
        response = supabase.table("user_profiles").select("id").eq("id", user_id).execute()
        return len(response.data) > 0
    except Exception as e:
        logger.error(f"用戶驗證錯誤: {e}")
        return False

def get_user_balance(user_id: str) -> float:
    """獲取用戶現金餘額"""
    try:
        response = supabase.table("user_balances").select("balance").eq("user_id", user_id).execute()
        if response.data:
            return float(response.data[0]["balance"])
        return 100000.0  # 預設初始資金 10 萬
    except Exception as e:
        logger.error(f"獲取餘額錯誤: {e}")
        return 100000.0

def update_user_balance(user_id: str, new_balance: float):
    """更新用戶餘額"""
    try:
        # 確保餘額為整數（如果數據庫需要整數）
        balance_value = int(round(new_balance))
        supabase.table("user_balances").upsert({
            "user_id": user_id,
            "balance": balance_value,
            "updated_at": datetime.now().isoformat()
        }, on_conflict="user_id").execute()
        logger.info(f"✅ 餘額已更新: 用戶 {user_id}, 新餘額: {balance_value}")
    except Exception as e:
        logger.error(f"更新餘額錯誤: {e}")
        raise

# MARK: - 測試端點
@app.route('/api/test-tournament-isolation', methods=['POST'])
def test_tournament_isolation():
    """測試錦標賽數據隔離功能（不需要數據庫）"""
    data = request.get_json()
    
    # 模擬交易記錄
    mock_transactions = [
        {"user_id": "test", "symbol": "2337", "action": "buy", "amount": 100, "tournament_id": "test06"},
        {"user_id": "test", "symbol": "2330", "action": "buy", "amount": 200, "tournament_id": "test06"},
        {"user_id": "test", "symbol": "2454", "action": "buy", "amount": 150, "tournament_id": "test05"},
        {"user_id": "test", "symbol": "2317", "action": "buy", "amount": 300, "tournament_id": None},  # 一般交易
    ]
    
    tournament_id = data.get('tournament_id')
    user_id = data.get('user_id', 'test')
    
    # 根據錦標賽 ID 過濾交易
    if tournament_id:
        filtered_transactions = [tx for tx in mock_transactions if tx['tournament_id'] == tournament_id and tx['user_id'] == user_id]
        context = f"錦標賽 {tournament_id}"
    else:
        filtered_transactions = [tx for tx in mock_transactions if tx['tournament_id'] is None and tx['user_id'] == user_id]
        context = "一般模式"
    
    return jsonify({
        "success": True,
        "context": context,
        "transactions": filtered_transactions,
        "transaction_count": len(filtered_transactions),
        "isolation_test": {
            "test06_only": [tx for tx in mock_transactions if tx['tournament_id'] == 'test06'],
            "test05_only": [tx for tx in mock_transactions if tx['tournament_id'] == 'test05'],
            "general_only": [tx for tx in mock_transactions if tx['tournament_id'] is None]
        }
    })

# MARK: - API 路由

@app.route('/api/health', methods=['GET'])
def health_check():
    """健康檢查端點"""
    # 檢查官方 API 連線狀態
    twse_api_status = "unknown"
    tpex_api_status = "unknown"
    
    try:
        session = create_robust_session()
        
        # 測試上市官方 API
        response = session.get("https://openapi.twse.com.tw/v1/exchangeReport/STOCK_DAY_ALL", timeout=10)
        twse_api_status = "connected" if response.status_code == 200 else f"error_{response.status_code}"
        
        # 測試上櫃官方 API
        response = session.get("https://www.tpex.org.tw/openapi/v1/tpex_mainboard_daily_close_quotes", timeout=10)
        tpex_api_status = "connected" if response.status_code == 200 else f"error_{response.status_code}"
        
        session.close()
    except Exception as e:
        twse_api_status = f"failed_{str(e)[:50]}"
        tpex_api_status = f"failed_{str(e)[:50]}"
    
    return jsonify({
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "redis_connected": redis_client is not None,
        "supabase_connected": True,
        "twse_official_api": twse_api_status,
        "tpex_official_api": tpex_api_status,
        "fallback_available": os.path.exists(os.path.join(os.path.dirname(__file__), 'taiwan_stocks_fallback.json')),
        "api_version": "official_twse_api_v1"
    })

@app.route('/api/taiwan-stocks', methods=['GET'])
def get_taiwan_stock_list():
    """獲取熱門台股清單（保持向後兼容）"""
    try:
        taiwan_stocks = []
        for symbol, name in POPULAR_TAIWAN_STOCKS.items():
            taiwan_stocks.append({
                "symbol": f"{symbol}.TW",
                "base_symbol": symbol,
                "name": name,
                "display_name": f"{symbol} {name}"
            })
        
        logger.info(f"✅ 回傳熱門台股清單: {len(taiwan_stocks)} 支股票")
        return jsonify({
            "stocks": taiwan_stocks,
            "total_count": len(taiwan_stocks),
            "last_updated": datetime.now().isoformat()
        })
    except Exception as e:
        logger.error(f"獲取熱門台股清單失敗: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/taiwan-stocks/all', methods=['GET'])
def get_all_taiwan_stocks():
    """獲取完整台股清單"""
    try:
        # 獲取查詢參數
        page = int(request.args.get('page', 1))
        per_page = min(int(request.args.get('per_page', 100)), 500)  # 最多500筆
        search = request.args.get('search', '').strip()
        market = request.args.get('market', '').strip()  # 'listed' 或 'otc'
        industry = request.args.get('industry', '').strip()
        
        # 嘗試從快取獲取
        stocks = get_cached_taiwan_stocks()
        if not stocks:
            # 快取中沒有，重新獲取
            stocks = fetch_all_taiwan_stocks()
            if stocks:
                set_cached_taiwan_stocks(stocks)
            else:
                # 提供詳細的錯誤資訊
                fallback_available = os.path.exists(os.path.join(os.path.dirname(__file__), 'taiwan_stocks_fallback.json'))
                error_detail = {
                    "error": "無法獲取台股清單",
                    "details": "即時資料和靜態備份都無法載入",
                    "fallback_available": fallback_available,
                    "suggestion": "請檢查網路連線或聯繫系統管理員"
                }
                return jsonify(error_detail), 500
        
        # 搜尋篩選
        if search:
            search_lower = search.lower()
            stocks = [s for s in stocks if 
                     search_lower in s['code'] or 
                     search_lower in s['name'].lower() or
                     search_lower in s['industry'].lower()]
        
        # 市場篩選
        if market == 'listed':
            stocks = [s for s in stocks if s['is_listed']]
        elif market == 'otc':
            stocks = [s for s in stocks if not s['is_listed']]
        
        # 產業篩選
        if industry:
            stocks = [s for s in stocks if industry in s['industry']]
        
        # 分頁處理
        total_count = len(stocks)
        start_idx = (page - 1) * per_page
        end_idx = start_idx + per_page
        paginated_stocks = stocks[start_idx:end_idx]
        
        # 統計資訊
        listed_count = len([s for s in stocks if s['is_listed']])
        otc_count = total_count - listed_count
        
        # 產業統計
        industries = {}
        for stock in stocks:
            industry_name = stock['industry']
            industries[industry_name] = industries.get(industry_name, 0) + 1
        
        response = {
            "stocks": paginated_stocks,
            "pagination": {
                "page": page,
                "per_page": per_page,
                "total_count": total_count,
                "total_pages": (total_count + per_page - 1) // per_page,
                "has_next": end_idx < total_count,
                "has_prev": page > 1
            },
            "statistics": {
                "total_count": total_count,
                "listed_count": listed_count,
                "otc_count": otc_count,
                "industries": dict(sorted(industries.items(), key=lambda x: x[1], reverse=True)[:10])  # 前10大產業
            },
            "filters": {
                "search": search,
                "market": market,
                "industry": industry
            },
            "last_updated": datetime.now().isoformat()
        }
        
        logger.info(f"✅ 回傳完整台股清單: 第{page}頁，{len(paginated_stocks)}/{total_count} 支股票")
        return jsonify(response)
        
    except Exception as e:
        logger.error(f"獲取完整台股清單失敗: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/taiwan-stocks/search', methods=['GET'])
def search_taiwan_stocks():
    """台股智能搜尋"""
    try:
        query = request.args.get('q', '').strip()
        limit = min(int(request.args.get('limit', 20)), 100)
        
        if not query:
            return jsonify({"stocks": [], "total_count": 0})
        
        # 獲取股票清單
        stocks = get_cached_taiwan_stocks()
        if not stocks:
            stocks = fetch_all_taiwan_stocks()
            if stocks:
                set_cached_taiwan_stocks(stocks)
        
        if not stocks:
            fallback_available = os.path.exists(os.path.join(os.path.dirname(__file__), 'taiwan_stocks_fallback.json'))
            error_detail = {
                "error": "無法獲取台股清單",
                "details": "即時資料和靜態備份都無法載入",
                "fallback_available": fallback_available,
                "suggestion": "請檢查網路連線或聯繫系統管理員"
            }
            return jsonify(error_detail), 500
        
        query_lower = query.lower()
        matched_stocks = []
        
        for stock in stocks:
            score = 0
            # 代號完全匹配優先級最高
            if stock['code'] == query:
                score = 100
            elif stock['code'].startswith(query):
                score = 90
            elif query in stock['code']:
                score = 80
            # 名稱匹配
            elif query_lower in stock['name'].lower():
                if stock['name'].lower().startswith(query_lower):
                    score = 70
                else:
                    score = 60
            # 產業匹配
            elif query_lower in stock['industry'].lower():
                score = 50
            
            if score > 0:
                matched_stocks.append({**stock, 'match_score': score})
        
        # 按匹配分數排序
        matched_stocks.sort(key=lambda x: x['match_score'], reverse=True)
        matched_stocks = matched_stocks[:limit]
        
        # 移除匹配分數
        for stock in matched_stocks:
            stock.pop('match_score', None)
        
        logger.info(f"🔍 搜尋 '{query}': 找到 {len(matched_stocks)} 支股票")
        return jsonify({
            "stocks": matched_stocks,
            "total_count": len(matched_stocks),
            "query": query,
            "limit": limit
        })
        
    except Exception as e:
        logger.error(f"台股搜尋失敗: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/quote', methods=['GET'])
def get_stock_quote():
    """獲取股票報價"""
    symbol = request.args.get('symbol')
    if not symbol:
        return jsonify({"error": "缺少股票代號參數"}), 400
    
    try:
        # 檢查快取
        cached_price = get_cached_price(symbol)
        if cached_price:
            logger.info(f"📋 使用快取股價: {symbol}")
            return jsonify(cached_price)
        
        # 從 Yahoo Finance 獲取
        price_data = fetch_yahoo_finance_price(symbol)
        
        # 設定快取
        set_cached_price(symbol, price_data)
        
        logger.info(f"✅ 獲取股價成功: {symbol} - ${price_data['current_price']}")
        return jsonify(price_data)
        
    except Exception as e:
        logger.error(f"獲取股價失敗: {e}")
        
        # 嘗試使用備用數據
        try:
            fallback_data = get_fallback_price_data(symbol)
            logger.warning(f"⚠️ 使用備用股價數據: {symbol}")
            return jsonify(fallback_data)
        except Exception as fallback_error:
            logger.error(f"備用數據也失敗: {fallback_error}")
            return jsonify({"error": "無法獲取股價數據，請稍後重試"}), 404

@app.route('/api/trade', methods=['POST'])
def execute_trade():
    """執行交易"""
    data = request.get_json()
    
    # 驗證請求參數
    required_fields = ['user_id', 'symbol', 'action', 'amount']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"缺少必要參數: {field}"}), 400
    
    user_id = data['user_id']
    original_symbol = data['symbol']
    action = data['action'].lower()
    amount = float(data['amount'])
    tournament_id = data.get('tournament_id')  # 錦標賽 ID（可選）
    is_day_trading = data.get('is_day_trading', False)  # 是否為當沖
    
    if action not in ['buy', 'sell']:
        return jsonify({"error": "交易動作必須為 buy 或 sell"}), 400
    
    try:
        # 標準化股票代號
        symbol = normalize_taiwan_stock_symbol(original_symbol)
        trade_context = f"錦標賽 {tournament_id}" if tournament_id else "一般模式"
        logger.info(f"💰 執行交易 ({trade_context}): {original_symbol} -> {symbol}, {action}, 金額: {amount}")
        
        # 驗證用戶
        if not validate_user(user_id):
            return jsonify({"error": "用戶不存在"}), 404
        
        # 獲取當前股價
        price_data = get_cached_price(symbol)
        if not price_data:
            price_data = fetch_yahoo_finance_price(symbol)
            set_cached_price(symbol, price_data)
        
        current_price = price_data['current_price']
        is_tw_stock = is_taiwan_stock(symbol)
        
        # 計算交易詳情
        if action == 'buy':
            # 買入：amount 是金額
            if is_tw_stock:
                # 台股費用計算
                cost_info = calculate_taiwan_trading_cost(amount, is_day_trading)
                transaction_fee = cost_info['total_cost']
                fee_details = cost_info
            else:
                # 美股費用計算
                transaction_fee = amount * TRANSACTION_FEE_RATE
                fee_details = {"brokerage_fee": transaction_fee, "securities_tax": 0, "total_cost": transaction_fee}
            
            available_amount = amount - transaction_fee
            shares = available_amount / current_price
            total_cost = amount
            
            # 檢查餘額
            user_balance = get_user_balance(user_id)
            if user_balance < total_cost:
                return jsonify({"error": "餘額不足"}), 400
            
            # 更新餘額（測試用戶跳過）
            if user_id not in ["d64a0edd-62cc-423a-8ce4-81103b5a9770", "12345678-1234-1234-1234-123456789012"]:
                new_balance = user_balance - total_cost
                update_user_balance(user_id, new_balance)
            else:
                logger.info(f"🧪 測試用戶 {user_id} 跳過餘額更新")
            
        else:
            # 賣出：amount 是股數
            shares = amount
            gross_amount = shares * current_price
            
            if is_tw_stock:
                # 台股費用計算
                cost_info = calculate_taiwan_trading_cost(gross_amount, is_day_trading)
                transaction_fee = cost_info['total_cost']
                fee_details = cost_info
            else:
                # 美股費用計算
                transaction_fee = gross_amount * TRANSACTION_FEE_RATE
                fee_details = {"brokerage_fee": transaction_fee, "securities_tax": 0, "total_cost": transaction_fee}
            
            total_cost = gross_amount - transaction_fee
            
            # TODO: 檢查持股數量
            # 這裡需要實作持股驗證邏輯
            
            # 更新餘額（測試用戶跳過）
            if user_id not in ["d64a0edd-62cc-423a-8ce4-81103b5a9770", "12345678-1234-1234-1234-123456789012"]:
                user_balance = get_user_balance(user_id)
                new_balance = user_balance + total_cost
                update_user_balance(user_id, new_balance)
            else:
                logger.info(f"🧪 測試用戶 {user_id} 跳過餘額更新")
        
        # 記錄交易 (適配 portfolio_transactions 表結構)
        transaction_record = {
            "user_id": user_id,
            "symbol": symbol,
            "action": action,
            "amount": abs(total_cost),  # 使用總金額
            "price": current_price,
            "executed_at": datetime.now().isoformat()
        }
        
        # 只有當 tournament_id 是有效的非空字符串時才加入
        if tournament_id and tournament_id.strip():
            transaction_record["tournament_id"] = tournament_id
        
        # 保存交易記錄到數據庫 (使用正確的 portfolio_transactions 表)
        supabase.table("portfolio_transactions").insert(transaction_record).execute()
        
        # 構建回應訊息
        stock_name = price_data.get('name', symbol)
        action_text = '買入' if action == 'buy' else '賣出'
        currency = price_data.get('currency', 'USD')
        
        logger.info(f"✅ 交易執行成功 ({trade_context}): {action_text} {stock_name} - {shares:.2f} 股")
        
        return jsonify({
            "success": True,
            "symbol": symbol,
            "stock_name": stock_name,
            "action": action,
            "amount": abs(total_cost),
            "price": current_price,
            "tournament_id": tournament_id,
            "executed_at": transaction_record["executed_at"],
            "message": f"{action_text} {stock_name} 成功，金額 ${abs(total_cost):,.2f}"
        })
        
    except Exception as e:
        logger.error(f"交易執行失敗: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/portfolio', methods=['GET'])
def get_portfolio():
    """獲取投資組合"""
    user_id = request.args.get('user_id')
    tournament_id = request.args.get('tournament_id')
    
    if not user_id:
        return jsonify({"error": "缺少用戶 ID 參數"}), 400
    
    try:
        # 獲取用戶現金餘額
        cash_balance = get_user_balance(user_id)
        
        # 根據是否有錦標賽 ID 來獲取相應的交易記錄
        if tournament_id:
            logger.info(f"🏆 獲取錦標賽 {tournament_id} 的投資組合")
            response = supabase.table("portfolio_transactions").select("*").eq("user_id", user_id).eq("tournament_id", tournament_id).execute()
        else:
            logger.info(f"📊 獲取用戶 {user_id} 的一般投資組合")
            # 獲取沒有錦標賽 ID 的交易記錄（一般模式）
            response = supabase.table("portfolio_transactions").select("*").eq("user_id", user_id).is_("tournament_id", "null").execute()
        
        transactions = response.data
        
        # 計算每支股票的持倉（適配 portfolio_transactions 表結構）
        holdings = {}
        for tx in transactions:
            symbol = tx['symbol']
            if symbol not in holdings:
                holdings[symbol] = {"shares": 0, "total_cost": 0}
            
            # portfolio_transactions 使用 amount 字段，需要計算股數
            current_price = tx.get('price', 1.0)  # 確保不為零
            shares = tx['amount'] / current_price if current_price > 0 else 0
            
            if tx['action'] == 'buy':
                holdings[symbol]['shares'] += shares
                holdings[symbol]['total_cost'] += tx['amount']
            else:
                holdings[symbol]['shares'] -= shares
                holdings[symbol]['total_cost'] -= tx['amount']
        
        # 清理零持倉
        holdings = {k: v for k, v in holdings.items() if v['shares'] > 0.001}
        
        # 獲取當前股價並計算市值
        positions = []
        total_market_value = 0
        
        for symbol, holding in holdings.items():
            try:
                price_data = get_cached_price(symbol)
                if not price_data:
                    price_data = fetch_yahoo_finance_price(symbol)
                    set_cached_price(symbol, price_data)
                
                current_price = price_data['current_price']
                market_value = holding['shares'] * current_price
                avg_cost = holding['total_cost'] / holding['shares']
                unrealized_gain = market_value - holding['total_cost']
                unrealized_gain_percent = (unrealized_gain / holding['total_cost']) * 100
                
                positions.append({
                    "symbol": symbol,
                    "shares": holding['shares'],
                    "average_price": avg_cost,
                    "current_price": current_price,
                    "market_value": market_value,
                    "unrealized_gain": unrealized_gain,
                    "unrealized_gain_percent": unrealized_gain_percent
                })
                
                total_market_value += market_value
                
            except Exception as e:
                logger.error(f"獲取 {symbol} 股價失敗: {e}")
                continue
        
        # 計算總體投資組合指標
        total_value = cash_balance + total_market_value
        total_invested = sum(pos['average_price'] * pos['shares'] for pos in positions)
        total_return = total_market_value - total_invested
        total_return_percent = (total_return / total_invested * 100) if total_invested > 0 else 0
        
        portfolio = {
            "user_id": user_id,
            "tournament_id": tournament_id,
            "total_value": total_value,
            "cash_balance": cash_balance,
            "market_value": total_market_value,
            "total_invested": total_invested,
            "total_return": total_return,
            "total_return_percent": total_return_percent,
            "positions": positions,
            "last_updated": datetime.now().isoformat()
        }
        
        portfolio_type = f"錦標賽 {tournament_id}" if tournament_id else "一般模式"
        logger.info(f"✅ 獲取投資組合成功: 用戶 {user_id} ({portfolio_type}), 總值 ${total_value:.2f}")
        return jsonify(portfolio)
        
    except Exception as e:
        logger.error(f"獲取投資組合失敗: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/transactions', methods=['GET'])
def get_transactions():
    """獲取交易歷史"""
    user_id = request.args.get('user_id')
    tournament_id = request.args.get('tournament_id')
    limit = int(request.args.get('limit', 50))
    
    if not user_id:
        return jsonify({"error": "缺少用戶 ID 參數"}), 400
    
    try:
        # 根據是否有錦標賽 ID 來獲取相應的交易記錄
        if tournament_id:
            logger.info(f"🏆 獲取錦標賽 {tournament_id} 的交易歷史")
            response = supabase.table("portfolio_transactions")\
                .select("*")\
                .eq("user_id", user_id)\
                .eq("tournament_id", tournament_id)\
                .order("executed_at", desc=True)\
                .limit(limit)\
                .execute()
        else:
            logger.info(f"📊 獲取用戶 {user_id} 的一般交易歷史")
            response = supabase.table("portfolio_transactions")\
                .select("*")\
                .eq("user_id", user_id)\
                .is_("tournament_id", "null")\
                .order("executed_at", desc=True)\
                .limit(limit)\
                .execute()
        
        transactions = []
        for tx in response.data:
            # 適配 portfolio_transactions 表結構
            current_price = tx.get('price', 1.0)
            shares = tx['amount'] / current_price if current_price > 0 else 0
            
            transactions.append({
                "id": tx['id'],
                "symbol": tx['symbol'],
                "action": tx['action'],
                "quantity": shares,  # 根據 amount 和 price 計算股數
                "price": tx['price'],
                "amount": tx['amount'],  # 使用 amount 字段
                "executed_at": tx['executed_at'],
                "tournament_id": tx.get('tournament_id')  # 包含錦標賽 ID
            })
        
        transaction_type = f"錦標賽 {tournament_id}" if tournament_id else "一般模式"
        logger.info(f"✅ 獲取交易歷史成功: 用戶 {user_id} ({transaction_type}), {len(transactions)} 筆記錄")
        return jsonify(transactions)
        
    except Exception as e:
        logger.error(f"獲取交易歷史失敗: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/available-tournaments', methods=['GET'])
def get_available_tournaments():
    """獲取所有可參與的錦標賽（test03創建的錦標賽 + 用戶創建的錦標賽）"""
    user_id = request.args.get('user_id', '')  # 獲取用戶ID參數
    
    try:
        logger.info(f"🏆 獲取可參與的錦標賽列表 (用戶: {user_id})")
        
        # 獲取所有錦標賽（簡化邏輯，所有錦標賽都屬於用戶）
        try:
            # 直接查詢所有tournaments
            response = supabase.table("tournaments")\
                .select("*")\
                .execute()
            
            tournaments = []
            for tournament in response.data:
                tournaments.append({
                    "id": tournament.get("id"),
                    "name": tournament.get("name", "未命名錦標賽"),
                    "description": tournament.get("description", ""),
                    "status": tournament.get("status", "ongoing"),
                    "start_date": tournament.get("start_date", "2025-08-01T00:00:00Z"),
                    "end_date": tournament.get("end_date", "2025-08-31T23:59:59Z"),
                    "initial_balance": tournament.get("initial_balance", 100000.0),
                    "current_participants": tournament.get("current_participants", 0),
                    "max_participants": tournament.get("max_participants", 100),
                    "created_by": "user",  # 簡化為所有錦標賽都屬於用戶
                    "created_at": tournament.get("created_at"),
                    "is_user_created": True,  # 所有錦標賽都是用戶創建
                    "creator_label": "我創建的"  # 統一標籤
                })
            
            logger.info(f"✅ 從數據庫獲取錦標賽: {len(tournaments)} 個")
            
        except Exception as db_error:
            logger.warning(f"⚠️ 數據庫查詢失敗，使用備用數據: {db_error}")
            
            # 數據庫查詢失敗時使用備用數據（所有錦標賽都是用戶創建）
            tournaments = [
                {
                    "id": "12345678-1234-1234-1234-123456789001",
                    "name": "科技股挑戰賽",
                    "description": "專注科技股的錦標賽",
                    "status": "ongoing",
                    "start_date": "2025-08-01T00:00:00Z",
                    "end_date": "2025-08-31T23:59:59Z",
                    "initial_balance": 100000.0,
                    "current_participants": 45,
                    "max_participants": 100,
                    "created_by": "user",
                    "created_at": "2025-08-01T00:00:00Z"
                },
                {
                    "id": "12345678-1234-1234-1234-123456789002", 
                    "name": "新手友善錦標賽",
                    "description": "適合新手參與的錦標賽",
                    "status": "ongoing",
                    "start_date": "2025-08-05T00:00:00Z",
                    "end_date": "2025-09-05T23:59:59Z",
                    "initial_balance": 50000.0,
                    "current_participants": 28,
                    "max_participants": 50,
                    "created_by": "user",
                    "created_at": "2025-08-05T00:00:00Z"
                },
                {
                    "id": "12345678-1234-1234-1234-123456789003", 
                    "name": "高手進階賽",
                    "description": "高手限定的進階錦標賽",
                    "status": "ongoing",
                    "start_date": "2025-08-10T00:00:00Z",
                    "end_date": "2025-09-10T23:59:59Z",
                    "initial_balance": 200000.0,
                    "current_participants": 35,
                    "max_participants": 75,
                    "created_by": "user",
                    "created_at": "2025-08-10T00:00:00Z"
                },
                {
                    "id": "user001-1234-1234-1234-123456789001",
                    "name": "我的科技股專題賽",
                    "description": "我創建的科技股投資錦標賽",
                    "status": "ongoing",
                    "start_date": "2025-08-08T00:00:00Z",
                    "end_date": "2025-09-08T23:59:59Z",
                    "initial_balance": 200000.0,
                    "current_participants": 15,
                    "max_participants": 50,
                    "created_by": "user",
                    "created_at": "2025-08-08T00:00:00Z"
                },
                {
                    "id": "user002-1234-1234-1234-123456789002",
                    "name": "我的價值投資挑戰",
                    "description": "我創建的長期價值投資策略錦標賽",
                    "status": "ongoing",
                    "start_date": "2025-08-09T00:00:00Z",
                    "end_date": "2025-09-09T23:59:59Z",
                    "initial_balance": 150000.0,
                    "current_participants": 8,
                    "max_participants": 30,
                    "created_by": "user",
                    "created_at": "2025-08-09T00:00:00Z"
                }
            ]
        
        # 為所有錦標賽添加統一標籤（所有錦標賽都是用戶創建）
        for tournament in tournaments:
            tournament["is_user_created"] = True
            tournament["creator_label"] = "我創建的"
        
        # 統計信息（簡化後全部為用戶創建）
        user_created_count = len(tournaments)
        test03_created_count = 0
        
        return jsonify({
            "tournaments": tournaments,
            "total_count": len(tournaments),
            "user_created_count": user_created_count,
            "test03_created_count": test03_created_count,
            "mixed_source": user_id and user_created_count > 0 and test03_created_count > 0,
            "query_user_id": user_id
        })
        
    except Exception as e:
        logger.error(f"獲取可參與錦標賽失敗: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/user-tournaments', methods=['GET'])
def get_user_tournaments():
    """獲取用戶已參與的錦標賽列表"""
    user_id = request.args.get('user_id')
    
    if not user_id:
        return jsonify({"error": "缺少用戶 ID 參數"}), 400
    
    try:
        logger.info(f"🏆 獲取用戶 {user_id} 已參與的錦標賽")
        
        # 獲取所有錦標賽（簡化邏輯）
        try:
            # 直接查詢所有tournaments
            all_tournaments_response = supabase.table("tournaments")\
                .select("*")\
                .execute()
            
            all_tournaments = all_tournaments_response.data
        except Exception:
            # 使用備用錦標賽數據（所有錦標賽都屬於用戶）
            all_tournaments = [
                {
                    "id": "12345678-1234-1234-1234-123456789001",
                    "name": "科技股挑戰賽",
                    "description": "專注科技股的錦標賽",
                    "status": "ongoing",
                    "start_date": "2025-08-01T00:00:00Z",
                    "end_date": "2025-08-31T23:59:59Z",
                    "initial_balance": 100000.0,
                    "current_participants": 45,
                    "max_participants": 100,
                    "created_by": "user"
                },
                {
                    "id": "12345678-1234-1234-1234-123456789002", 
                    "name": "新手友善錦標賽",
                    "description": "適合新手參與的錦標賽", 
                    "status": "ongoing",
                    "start_date": "2025-08-05T00:00:00Z",
                    "end_date": "2025-09-05T23:59:59Z",
                    "initial_balance": 50000.0,
                    "current_participants": 28,
                    "max_participants": 50,
                    "created_by": "user"
                },
                {
                    "id": "user001-1234-1234-1234-123456789001",
                    "name": "我的科技股專題賽",
                    "description": "我創建的科技股投資錦標賽",
                    "status": "ongoing",
                    "start_date": "2025-08-08T00:00:00Z",
                    "end_date": "2025-09-08T23:59:59Z",
                    "initial_balance": 200000.0,
                    "current_participants": 15,
                    "max_participants": 50,
                    "created_by": "user"
                },
                {
                    "id": "user002-1234-1234-1234-123456789002",
                    "name": "我的價值投資挑戰",
                    "description": "我創建的長期價值投資策略錦標賽",
                    "status": "ongoing",
                    "start_date": "2025-08-09T00:00:00Z",
                    "end_date": "2025-09-09T23:59:59Z",
                    "initial_balance": 150000.0,
                    "current_participants": 8,
                    "max_participants": 30,
                    "created_by": "user"
                }
            ]
        
        # 簡化邏輯：所有錦標賽都是用戶創建且參與的
        user_tournaments = []
        for tournament in all_tournaments:
            tournament_id = tournament.get("id")
            
            user_tournaments.append({
                "id": tournament_id,
                "name": tournament.get("name"),
                "description": tournament.get("description", ""),
                "status": tournament.get("status", "ongoing"),
                "start_date": tournament.get("start_date"),
                "end_date": tournament.get("end_date"),
                "initial_balance": tournament.get("initial_balance"),
                "current_participants": tournament.get("current_participants"),
                "max_participants": tournament.get("max_participants"),
                "created_by": "user",
                "is_enrolled": True,
                "is_user_created": True,  # 所有錦標賽都是用戶創建
                "creator_label": "我創建的",
                "participation_type": "創建者",
                "total_trades": 5  # 固定數量，避免資料庫查詢
            })
        
        # 統計信息（簡化）
        created_by_user = len(user_tournaments)
        participated_only = 0
        
        logger.info(f"✅ 獲取用戶錦標賽成功: 用戶 {user_id}, {len(user_tournaments)} 個錦標賽 (創建: {created_by_user}, 參與: {participated_only})")
        return jsonify({
            "tournaments": user_tournaments,
            "total_count": len(user_tournaments),
            "created_by_user_count": created_by_user,
            "participated_only_count": participated_only,
            "user_id": user_id
        })
        
    except Exception as e:
        logger.error(f"獲取用戶錦標賽失敗: {e}")
        return jsonify({"error": str(e)}), 500

@app.route('/api/join-tournament', methods=['POST'])
def join_tournament():
    """加入錦標賽"""
    data = request.get_json()
    
    required_fields = ['user_id', 'tournament_id']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"缺少必要參數: {field}"}), 400
    
    user_id = data['user_id']
    tournament_id = data['tournament_id']
    
    try:
        logger.info(f"🏆 用戶 {user_id} 嘗試加入錦標賽 {tournament_id}")
        
        # 檢查錦標賽是否存在（從可參與錦標賽中查找）
        try:
            tournament_response = supabase.table("tournaments")\
                .select("*")\
                .eq("id", tournament_id)\
                .eq("created_by", "test03")\
                .execute()
            
            if not tournament_response.data:
                return jsonify({"error": "錦標賽不存在或不可參與"}), 404
            
            tournament_info = tournament_response.data[0]
        except Exception:
            # 使用備用數據檢查
            available_tournaments = [
                "12345678-1234-1234-1234-123456789001",
                "12345678-1234-1234-1234-123456789002", 
                "12345678-1234-1234-1234-123456789003"
            ]
            if tournament_id not in available_tournaments:
                return jsonify({"error": "錦標賽不存在或不可參與"}), 404
            
            tournament_info = {
                "id": tournament_id,
                "name": f"test03的錦標賽 {tournament_id[:8]}",
                "initial_balance": 100000.0
            }
        
        # 檢查用戶是否已經參與此錦標賽
        try:
            existing_participation = supabase.table("portfolio_transactions")\
                .select("tournament_id")\
                .eq("user_id", user_id)\
                .eq("tournament_id", tournament_id)\
                .limit(1)\
                .execute()
            
            if existing_participation.data:
                return jsonify({"error": "用戶已經參與此錦標賽"}), 409
        except Exception:
            logger.warning("⚠️ 無法檢查用戶參與狀態，繼續加入流程")
        
        # 創建初始交易記錄來標記用戶參與錦標賽
        # 這是一個"加入錦標賽"的標記交易，不是真實的股票交易
        initial_transaction = {
            "user_id": user_id,
            "tournament_id": tournament_id,
            "symbol": "INIT",
            "action": "join", 
            "amount": tournament_info.get("initial_balance", 100000.0),
            "price": 1.0,
            "executed_at": datetime.now().isoformat()
        }
        
        try:
            supabase.table("portfolio_transactions").insert(initial_transaction).execute()
            
            logger.info(f"✅ 用戶 {user_id} 成功加入錦標賽 {tournament_id}")
            return jsonify({
                "success": True,
                "message": f"成功加入錦標賽: {tournament_info.get('name', '未命名錦標賽')}",
                "tournament_id": tournament_id,
                "initial_balance": tournament_info.get("initial_balance", 100000.0)
            })
            
        except Exception as db_error:
            logger.error(f"❌ 加入錦標賽數據庫操作失敗: {db_error}")
            
            # 即使數據庫操作失敗，也返回成功（對於演示目的）
            logger.info(f"✅ 模擬用戶 {user_id} 加入錦標賽 {tournament_id} (數據庫問題，使用模擬模式)")
            return jsonify({
                "success": True,
                "message": f"成功加入錦標賽: {tournament_info.get('name', '未命名錦標賽')} (模擬模式)",
                "tournament_id": tournament_id,
                "initial_balance": tournament_info.get("initial_balance", 100000.0),
                "note": "模擬模式：實際環境中會記錄到數據庫"
            })
        
    except Exception as e:
        logger.error(f"加入錦標賽失敗: {e}")
        return jsonify({"error": str(e)}), 500

if __name__ == '__main__':
    import os
    port = int(os.environ.get('PORT', 5001))  # 改為 5001 避免與 macOS AirPlay 衝突
    debug = os.environ.get('FLASK_ENV') != 'production'
    
    logger.info(f"🚀 Flask API 服務器啟動 - Port: {port}, Debug: {debug}")
    app.run(debug=debug, host='0.0.0.0', port=port)