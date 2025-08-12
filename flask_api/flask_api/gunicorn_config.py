"""
Gunicorn 高併發配置
專為 10場錦標賽 x 100人交易優化

配置重點:
1. 多進程 + 異步工作模式
2. 合理的連接池和超時設置
3. 性能監控和日誌配置
4. 資源限制和錯誤處理
"""

import multiprocessing
import os

# ========================================
# 基本服務配置
# ========================================

# 綁定地址和端口
bind = "0.0.0.0:5001"

# 進程配置 - 根據 CPU 核心數動態調整
# 公式: (2 * CPU核心數) + 1，但限制在合理範圍內
max_workers = min(multiprocessing.cpu_count() * 2 + 1, 16)
workers = max_workers

# 工作模式 - 使用 gevent 異步模式處理高併發
worker_class = "gevent"
worker_connections = 1000  # 每個 worker 的最大連接數

# 線程配置（當使用 sync worker 時）
threads = 2

print(f"🚀 Gunicorn 配置: {workers} workers, {worker_connections} connections per worker")
print(f"📊 預期最大併發: {workers * worker_connections} 連接")

# ========================================
# 性能和資源配置
# ========================================

# 超時設置
timeout = 30        # 請求超時（秒）
keepalive = 5       # Keep-Alive 超時
graceful_timeout = 30  # 優雅關閉超時

# 內存和 CPU 限制
max_requests = 1000           # 每個 worker 處理請求數上限（防內存洩漏）
max_requests_jitter = 100     # 添加隨機性，避免所有 worker 同時重啟
memory_limit = 512 * 1024 * 1024  # 每個 worker 512MB 內存限制

# 預載入應用（提升性能，共享內存）
preload_app = True

# ========================================
# 日誌配置
# ========================================

# 日誌等級
loglevel = "info"

# 日誌文件
logs_dir = os.path.join(os.path.dirname(__file__), "logs")
os.makedirs(logs_dir, exist_ok=True)

accesslog = os.path.join(logs_dir, "gunicorn_access.log")
errorlog = os.path.join(logs_dir, "gunicorn_error.log")

# 日誌格式
access_log_format = '%(h)s %(l)s %(u)s %(t)s "%(r)s" %(s)s %(b)s "%(f)s" "%(a)s" %(D)s'

# 設置 Python 日誌
capture_output = True
enable_stdio_inheritance = True

# ========================================
# 安全配置
# ========================================

# 用戶和組（生產環境設置）
# user = "www-data"
# group = "www-data"

# 進程名稱
proc_name = "invest_v3_tournament_api"

# ========================================
# 監控和健康檢查
# ========================================

# 啟用統計端點
enable_stdio_inheritance = True

def when_ready(server):
    """服務器就緒時的回調"""
    server.log.info("🎯 錦標賽 API 服務器已就緒")
    server.log.info(f"📊 工作進程: {server.num_workers}")
    server.log.info(f"🔗 預期併發連接: {server.num_workers * worker_connections}")

def worker_int(worker):
    """Worker 接收到 SIGINT 信號時的回調"""
    worker.log.info(f"⚠️ Worker {worker.pid} 正在關閉...")

def pre_fork(server, worker):
    """Fork 新 worker 前的回調"""
    server.log.info(f"🔄 正在啟動 worker {worker.age}")

def post_fork(server, worker):
    """Fork 新 worker 後的回調"""
    server.log.info(f"✅ Worker {worker.pid} 已啟動")

def pre_exec(server):
    """重新執行前的回調"""
    server.log.info("🔄 準備重新載入配置...")

def on_exit(server):
    """服務器退出時的回調"""
    server.log.info("🛑 錦標賽 API 服務器正在關閉...")

def worker_abort(worker):
    """Worker 異常中止時的回調"""
    worker.log.error(f"💥 Worker {worker.pid} 異常中止")

# ========================================
# 開發和調試配置
# ========================================

# 開發環境配置
if os.environ.get('FLASK_ENV') == 'development':
    reload = True
    reload_engine = 'poll'
    loglevel = "debug"
    workers = 2  # 開發環境減少 worker 數量
    print("🔧 開發模式: 啟用自動重載")

# ========================================
# SSL 配置（生產環境）
# ========================================

# 如果需要 HTTPS（生產環境）
# keyfile = "/path/to/keyfile"
# certfile = "/path/to/certfile"
# ssl_version = ssl.PROTOCOL_TLSv1_2
# ciphers = "ECDHE+AESGCM:ECDHE+CHACHA20:DHE+AESGCM:DHE+CHACHA20:!aNULL:!MD5:!DSS"

# ========================================
# 監控統計配置
# ========================================

def child_exit(server, worker):
    """子進程退出時記錄統計信息"""
    server.log.info(f"📈 Worker {worker.pid} 統計:")
    server.log.info(f"   處理請求數: {getattr(worker, 'requests_count', 'N/A')}")
    server.log.info(f"   運行時間: {getattr(worker, 'alive_time', 'N/A')} 秒")

# 錯誤處理和恢復
def worker_timeout(worker):
    """Worker 超時處理"""
    worker.log.warning(f"⏰ Worker {worker.pid} 請求超時，正在重啟...")

# 自定義應用配置函數
def post_worker_init(worker):
    """Worker 初始化後的配置"""
    import logging
    
    # 配置應用程序級別的日誌
    logging.basicConfig(
        level=logging.INFO,
        format='%(asctime)s [%(levelname)s] %(name)s: %(message)s',
        handlers=[
            logging.StreamHandler(),
            logging.FileHandler(os.path.join(logs_dir, f"app_worker_{worker.pid}.log"))
        ]
    )
    
    worker.log.info(f"🎮 Worker {worker.pid} 應用初始化完成")

# ========================================
# 性能調優建議
# ========================================

"""
生產環境部署建議:

1. 系統級優化:
   - 調整 Linux 文件描述符限制: ulimit -n 65536
   - 優化 TCP 參數: echo 1 > /proc/sys/net/ipv4/tcp_fin_timeout
   - 設置合適的 vm.overcommit_memory

2. 資源監控:
   - 使用 htop 監控 CPU 使用率
   - 使用 iostat 監控 I/O 性能
   - 使用 netstat 監控網路連接數

3. 負載均衡:
   - 使用 Nginx 作為反向代理
   - 配置多個 Gunicorn 實例
   - 使用 Redis 作為會話存儲

4. 容器化部署:
   - 每個容器運行 1 個 Gunicorn 實例
   - 使用 Docker Swarm 或 Kubernetes 編排
   - 設置適當的資源限制和健康檢查

5. 數據庫優化:
   - 使用連接池
   - 設置合適的 shared_buffers
   - 定期 VACUUM 和 ANALYZE
"""

print("📋 Gunicorn 高併發配置載入完成")
print("🎯 適用場景: 10場錦標賽 x 100人同時交易")
print("📊 預期 TPS: 500-1000 (根據硬件配置)")