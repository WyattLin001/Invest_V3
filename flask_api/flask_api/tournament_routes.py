"""
錦標賽高併發交易路由
專為 10場錦標賽 x 100人交易設計的 API 路由

新增功能:
1. 高效能錦標賽交易 API
2. 實時排行榜 API  
3. 錦標賽統計和監控 API
4. 併發性能測試 API
"""

from flask import Blueprint, request, jsonify, current_app
from datetime import datetime, timedelta
import json
import uuid
import logging
import time
from typing import Dict, List, Optional
import asyncio

from tournament_service import get_tournament_service, TournamentTrade
from app import supabase, redis_client, fetch_yahoo_finance_price, set_cached_price, get_cached_price

logger = logging.getLogger(__name__)

# 創建錦標賽路由藍圖
tournament_bp = Blueprint('tournament', __name__, url_prefix='/api/tournament')

def get_tournament_service_instance():
    """獲取錦標賽服務實例"""
    return get_tournament_service(supabase, redis_client)

# ========================================
# 1. 高併發交易 API
# ========================================

@tournament_bp.route('/<tournament_id>/trade', methods=['POST'])
def execute_tournament_trade(tournament_id):
    """執行錦標賽交易（高併發優化版）"""
    data = request.get_json()
    
    # 驗證必要參數
    required_fields = ['user_id', 'symbol', 'side', 'qty', 'price']
    for field in required_fields:
        if field not in data:
            return jsonify({"error": f"缺少必要參數: {field}"}), 400
    
    try:
        start_time = time.time()
        
        # 獲取錦標賽服務
        service = get_tournament_service_instance()
        
        # 構建交易對象
        trade = TournamentTrade(
            tournament_id=tournament_id,
            user_id=data['user_id'],
            symbol=data['symbol'],
            side=data['side'],
            qty=float(data['qty']),
            price=float(data['price']),
            total_amount=float(data['qty']) * float(data['price']),
            executed_at=datetime.utcnow().isoformat()
        )
        
        # 執行交易
        result = service.execute_tournament_trade(trade)
        
        # 記錄 API 響應時間
        api_time = (time.time() - start_time) * 1000
        
        logger.info(f"✅ 錦標賽交易 API 完成: {tournament_id}:{data['user_id']} - {api_time:.2f}ms")
        
        return jsonify({
            'success': True,
            'tournament_id': tournament_id,
            'trade_id': result.get('trade_id'),
            'execution_time_ms': result.get('execution_time_ms'),
            'api_response_time_ms': api_time,
            'trade_details': {
                'symbol': trade.symbol,
                'side': trade.side,
                'qty': trade.qty,
                'price': trade.price,
                'total_amount': trade.total_amount
            },
            'timestamp': datetime.utcnow().isoformat()
        })
        
    except ValueError as ve:
        logger.warning(f"⚠️ 交易驗證失敗: {ve}")
        return jsonify({"error": str(ve)}), 400
        
    except Exception as e:
        logger.error(f"❌ 錦標賽交易失敗: {e}")
        return jsonify({"error": "交易執行失敗，請稍後重試"}), 500

@tournament_bp.route('/<tournament_id>/batch-trade', methods=['POST'])
def execute_batch_trades(tournament_id):
    """批量執行錦標賽交易（測試高併發）"""
    data = request.get_json()
    
    if 'trades' not in data or not isinstance(data['trades'], list):
        return jsonify({"error": "缺少交易列表參數"}), 400
    
    try:
        start_time = time.time()
        service = get_tournament_service_instance()
        
        results = []
        errors = []
        
        for i, trade_data in enumerate(data['trades']):
            try:
                # 驗證單個交易數據
                required_fields = ['user_id', 'symbol', 'side', 'qty', 'price']
                for field in required_fields:
                    if field not in trade_data:
                        errors.append(f"交易 {i+1}: 缺少參數 {field}")
                        continue
                
                # 構建交易對象
                trade = TournamentTrade(
                    tournament_id=tournament_id,
                    user_id=trade_data['user_id'],
                    symbol=trade_data['symbol'],
                    side=trade_data['side'],
                    qty=float(trade_data['qty']),
                    price=float(trade_data['price']),
                    total_amount=float(trade_data['qty']) * float(trade_data['price']),
                    executed_at=datetime.utcnow().isoformat()
                )
                
                # 執行交易
                result = service.execute_tournament_trade(trade)
                results.append({
                    'trade_index': i + 1,
                    'success': True,
                    'trade_id': result.get('trade_id'),
                    'execution_time_ms': result.get('execution_time_ms')
                })
                
            except Exception as trade_error:
                errors.append(f"交易 {i+1}: {str(trade_error)}")
        
        total_time = (time.time() - start_time) * 1000
        
        logger.info(f"📦 批量交易完成: {len(results)} 成功, {len(errors)} 失敗, 總時間: {total_time:.2f}ms")
        
        return jsonify({
            'success': len(errors) == 0,
            'tournament_id': tournament_id,
            'total_trades': len(data['trades']),
            'successful_trades': len(results),
            'failed_trades': len(errors),
            'total_time_ms': total_time,
            'avg_time_per_trade_ms': total_time / len(data['trades']) if data['trades'] else 0,
            'results': results,
            'errors': errors,
            'timestamp': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"❌ 批量交易失敗: {e}")
        return jsonify({"error": str(e)}), 500

# ========================================
# 2. 實時排行榜 API
# ========================================

@tournament_bp.route('/<tournament_id>/leaderboard', methods=['GET'])
def get_tournament_leaderboard(tournament_id):
    """獲取錦標賽實時排行榜"""
    try:
        limit = min(int(request.args.get('limit', 100)), 500)
        service = get_tournament_service_instance()
        
        start_time = time.time()
        leaderboard = service.get_tournament_leaderboard(tournament_id, limit)
        query_time = (time.time() - start_time) * 1000
        
        logger.info(f"📊 排行榜查詢完成: {tournament_id}, {len(leaderboard)} 位參與者, {query_time:.2f}ms")
        
        return jsonify({
            'success': True,
            'tournament_id': tournament_id,
            'leaderboard': leaderboard,
            'total_participants': len(leaderboard),
            'query_time_ms': query_time,
            'last_updated': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"❌ 獲取排行榜失敗: {e}")
        return jsonify({"error": str(e)}), 500

@tournament_bp.route('/<tournament_id>/user-rank/<user_id>', methods=['GET'])
def get_user_rank(tournament_id, user_id):
    """獲取用戶在錦標賽中的排名"""
    try:
        service = get_tournament_service_instance()
        leaderboard = service.get_tournament_leaderboard(tournament_id, 1000)  # 獲取更多數據以確定準確排名
        
        user_rank = None
        user_stats = None
        
        for rank, participant in enumerate(leaderboard, 1):
            if participant['user_id'] == user_id:
                user_rank = rank
                user_stats = participant
                break
        
        if user_rank is None:
            return jsonify({"error": "用戶未參與此錦標賽"}), 404
        
        return jsonify({
            'success': True,
            'tournament_id': tournament_id,
            'user_id': user_id,
            'rank': user_rank,
            'total_participants': len(leaderboard),
            'user_stats': user_stats,
            'top_10_percent': user_rank <= len(leaderboard) * 0.1,
            'timestamp': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"❌ 獲取用戶排名失敗: {e}")
        return jsonify({"error": str(e)}), 500

# ========================================
# 3. 錦標賽統計 API
# ========================================

@tournament_bp.route('/<tournament_id>/stats', methods=['GET'])
def get_tournament_stats(tournament_id):
    """獲取錦標賽統計信息"""
    try:
        # 使用數據庫函數獲取實時統計
        result = supabase.rpc('get_tournament_stats', {'p_tournament_id': tournament_id}).execute()
        
        if result.data:
            stats = result.data[0] if isinstance(result.data, list) else result.data
            
            # 添加額外的統計信息
            stats['api_query_time'] = datetime.utcnow().isoformat()
            
            return jsonify({
                'success': True,
                'tournament_stats': stats
            })
        else:
            return jsonify({
                'success': False,
                'error': '錦標賽不存在或無統計數據'
            }), 404
        
    except Exception as e:
        logger.error(f"❌ 獲取錦標賽統計失敗: {e}")
        return jsonify({"error": str(e)}), 500

@tournament_bp.route('/active-tournaments', methods=['GET'])
def get_active_tournaments():
    """獲取所有進行中的錦標賽"""
    try:
        result = supabase.table('tournaments').select('*').eq('status', 'active').execute()
        
        tournaments = []
        for tournament in result.data:
            # 獲取每個錦標賽的參與者數量
            participants_result = supabase.table('tournament_members').select('user_id').eq('tournament_id', tournament['id']).execute()
            
            tournaments.append({
                'id': tournament['id'],
                'name': tournament['name'],
                'description': tournament.get('description', ''),
                'starts_at': tournament['starts_at'],
                'ends_at': tournament['ends_at'],
                'entry_capital': tournament['entry_capital'],
                'max_participants': tournament['max_participants'],
                'current_participants': len(participants_result.data),
                'status': tournament['status']
            })
        
        logger.info(f"📋 獲取進行中錦標賽: {len(tournaments)} 個")
        
        return jsonify({
            'success': True,
            'active_tournaments': tournaments,
            'total_count': len(tournaments),
            'timestamp': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"❌ 獲取進行中錦標賽失敗: {e}")
        return jsonify({"error": str(e)}), 500

# ========================================
# 4. 性能監控 API
# ========================================

@tournament_bp.route('/performance-metrics', methods=['GET'])
def get_performance_metrics():
    """獲取系統性能指標"""
    try:
        service = get_tournament_service_instance()
        metrics = service.get_performance_metrics()
        
        # 添加數據庫性能統計
        try:
            db_stats_result = supabase.table('tournament_performance_monitor').select('*').execute()
            metrics['database_stats'] = db_stats_result.data
        except Exception as db_error:
            logger.warning(f"⚠️ 獲取數據庫統計失敗: {db_error}")
            metrics['database_stats'] = []
        
        # 添加最近交易統計
        try:
            recent_trades = supabase.table('tournament_trades').select('tournament_id').gte('executed_at', (datetime.utcnow() - timedelta(minutes=1)).isoformat()).execute()
            metrics['recent_activity'] = {
                'trades_last_minute': len(recent_trades.data),
                'active_tournaments': len(set(trade['tournament_id'] for trade in recent_trades.data))
            }
        except Exception as activity_error:
            logger.warning(f"⚠️ 獲取近期活動統計失敗: {activity_error}")
            metrics['recent_activity'] = {
                'trades_last_minute': 0,
                'active_tournaments': 0
            }
        
        return jsonify({
            'success': True,
            'performance_metrics': metrics
        })
        
    except Exception as e:
        logger.error(f"❌ 獲取性能指標失敗: {e}")
        return jsonify({"error": str(e)}), 500

@tournament_bp.route('/health-check', methods=['GET'])
def tournament_health_check():
    """錦標賽系統健康檢查"""
    try:
        health_status = {
            'timestamp': datetime.utcnow().isoformat(),
            'overall_status': 'healthy',
            'components': {}
        }
        
        # 檢查錦標賽服務
        try:
            service = get_tournament_service_instance()
            health_status['components']['tournament_service'] = 'healthy'
        except Exception as e:
            health_status['components']['tournament_service'] = f'unhealthy: {str(e)}'
            health_status['overall_status'] = 'degraded'
        
        # 檢查數據庫連接
        try:
            supabase.table('tournaments').select('id').limit(1).execute()
            health_status['components']['database'] = 'healthy'
        except Exception as e:
            health_status['components']['database'] = f'unhealthy: {str(e)}'
            health_status['overall_status'] = 'unhealthy'
        
        # 檢查 Redis 連接
        if redis_client:
            try:
                redis_client.ping()
                health_status['components']['redis'] = 'healthy'
            except Exception as e:
                health_status['components']['redis'] = f'unhealthy: {str(e)}'
                health_status['overall_status'] = 'degraded'
        else:
            health_status['components']['redis'] = 'not_configured'
        
        # 檢查錦標賽數據完整性
        try:
            active_tournaments = supabase.table('tournaments').select('id').eq('status', 'active').execute()
            health_status['components']['active_tournaments'] = len(active_tournaments.data)
        except Exception as e:
            health_status['components']['active_tournaments'] = f'check_failed: {str(e)}'
        
        status_code = 200 if health_status['overall_status'] == 'healthy' else 503
        
        return jsonify({
            'success': health_status['overall_status'] in ['healthy', 'degraded'],
            'health': health_status
        }), status_code
        
    except Exception as e:
        logger.error(f"❌ 健康檢查失敗: {e}")
        return jsonify({
            'success': False,
            'health': {
                'overall_status': 'unhealthy',
                'error': str(e),
                'timestamp': datetime.utcnow().isoformat()
            }
        }), 503

# ========================================
# 5. 併發測試 API（開發用）
# ========================================

@tournament_bp.route('/load-test', methods=['POST'])
def tournament_load_test():
    """錦標賽負載測試（僅開發環境）"""
    if not current_app.debug:
        return jsonify({"error": "負載測試僅在開發環境中可用"}), 403
    
    data = request.get_json()
    tournament_id = data.get('tournament_id', '12345678-1234-1234-1234-123456789001')
    concurrent_users = min(int(data.get('concurrent_users', 10)), 100)  # 限制最大併發數
    trades_per_user = min(int(data.get('trades_per_user', 5)), 20)
    
    try:
        logger.info(f"🧪 開始負載測試: {concurrent_users} 併發用戶, 每用戶 {trades_per_user} 筆交易")
        
        start_time = time.time()
        
        # 模擬併發交易
        import threading
        import queue
        
        results_queue = queue.Queue()
        errors_queue = queue.Queue()
        
        def simulate_user_trading(user_index):
            try:
                user_id = f"load_test_user_{user_index:04d}"
                
                for trade_index in range(trades_per_user):
                    # 隨機選擇股票和交易參數
                    import random
                    symbols = ['2330.TW', '2454.TW', '2317.TW', 'AAPL', 'TSLA']
                    symbol = random.choice(symbols)
                    side = random.choice(['buy', 'sell'])
                    qty = random.randint(1, 100)
                    price = random.uniform(100, 1000)
                    
                    trade = TournamentTrade(
                        tournament_id=tournament_id,
                        user_id=user_id,
                        symbol=symbol,
                        side=side,
                        qty=qty,
                        price=price,
                        total_amount=qty * price,
                        executed_at=datetime.utcnow().isoformat()
                    )
                    
                    # 執行交易
                    service = get_tournament_service_instance()
                    result = service.execute_tournament_trade(trade)
                    
                    results_queue.put({
                        'user_index': user_index,
                        'trade_index': trade_index,
                        'execution_time_ms': result.get('execution_time_ms', 0)
                    })
                    
            except Exception as e:
                errors_queue.put({
                    'user_index': user_index,
                    'error': str(e)
                })
        
        # 啟動併發用戶線程
        threads = []
        for i in range(concurrent_users):
            thread = threading.Thread(target=simulate_user_trading, args=(i,))
            threads.append(thread)
            thread.start()
        
        # 等待所有線程完成
        for thread in threads:
            thread.join()
        
        # 收集結果
        results = []
        while not results_queue.empty():
            results.append(results_queue.get())
        
        errors = []
        while not errors_queue.empty():
            errors.append(errors_queue.get())
        
        total_time = (time.time() - start_time) * 1000
        total_trades = len(results)
        
        # 計算統計信息
        if results:
            execution_times = [r['execution_time_ms'] for r in results]
            avg_execution_time = sum(execution_times) / len(execution_times)
            max_execution_time = max(execution_times)
            min_execution_time = min(execution_times)
        else:
            avg_execution_time = max_execution_time = min_execution_time = 0
        
        logger.info(f"🎯 負載測試完成: {total_trades} 筆交易, {len(errors)} 個錯誤, 總時間: {total_time:.2f}ms")
        
        return jsonify({
            'success': True,
            'load_test_results': {
                'tournament_id': tournament_id,
                'concurrent_users': concurrent_users,
                'trades_per_user': trades_per_user,
                'total_trades': total_trades,
                'successful_trades': len(results),
                'failed_trades': len(errors),
                'total_time_ms': total_time,
                'avg_execution_time_ms': avg_execution_time,
                'max_execution_time_ms': max_execution_time,
                'min_execution_time_ms': min_execution_time,
                'throughput_tps': total_trades / (total_time / 1000) if total_time > 0 else 0
            },
            'errors_sample': errors[:10],  # 只返回前10個錯誤
            'timestamp': datetime.utcnow().isoformat()
        })
        
    except Exception as e:
        logger.error(f"❌ 負載測試失敗: {e}")
        return jsonify({"error": str(e)}), 500