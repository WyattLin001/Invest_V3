from flask import Flask, request, jsonify
from flask_cors import CORS
from flask_jwt_extended import JWTManager, create_access_token, jwt_required, get_jwt_identity
from dotenv import load_dotenv
import os
from datetime import datetime, timedelta
import logging

# Load environment variables
load_dotenv()

app = Flask(__name__)
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY')
app.config['JWT_ACCESS_TOKEN_EXPIRES'] = timedelta(days=30)

# Initialize extensions
jwt = JWTManager(app)
CORS(app)

# Configure logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Import services
from services.db_service import DatabaseService
from services.market_data_service import MarketDataService
from services.auth_service import AuthService
from services.trading_service import TradingService
from services.scheduler_service import scheduler_service

# Initialize services
db_service = DatabaseService()
market_service = MarketDataService()
auth_service = AuthService()
trading_service = TradingService()

# Health check endpoint
@app.route('/health', methods=['GET'])
def health_check():
    return jsonify({
        'status': 'healthy',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })

# Authentication routes
@app.route('/auth/send_otp', methods=['POST'])
def send_otp():
    try:
        data = request.get_json()
        phone = data.get('phone')
        
        if not phone:
            return jsonify({'error': 'Phone number is required'}), 400
        
        result = auth_service.send_otp(phone)
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error sending OTP: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/auth/verify_otp', methods=['POST'])
def verify_otp():
    try:
        data = request.get_json()
        phone = data.get('phone')
        otp = data.get('otp')
        invite_code = data.get('invite_code')
        
        if not phone or not otp:
            return jsonify({'error': 'Phone and OTP are required'}), 400
        
        result = auth_service.verify_otp(phone, otp, invite_code)
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error verifying OTP: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/auth/profile', methods=['GET'])
@jwt_required()
def get_profile():
    try:
        user_id = get_jwt_identity()
        profile = db_service.get_user_profile(user_id)
        return jsonify(profile)
    except Exception as e:
        logger.error(f"Error getting profile: {e}")
        return jsonify({'error': 'Internal server error'}), 500

# Market data routes
@app.route('/api/quote', methods=['GET'])
@jwt_required()
def get_quote():
    try:
        symbol = request.args.get('symbol')
        if not symbol:
            return jsonify({'error': 'Symbol is required'}), 400
        
        quote = market_service.get_realtime_price(symbol)
        return jsonify(quote)
    except Exception as e:
        logger.error(f"Error getting quote: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/history', methods=['GET'])
@jwt_required()
def get_history():
    try:
        symbol = request.args.get('symbol')
        period = request.args.get('period', '1mo')
        interval = request.args.get('interval', '1d')
        
        if not symbol:
            return jsonify({'error': 'Symbol is required'}), 400
        
        history = market_service.get_history(symbol, period, interval)
        return jsonify(history)
    except Exception as e:
        logger.error(f"Error getting history: {e}")
        return jsonify({'error': 'Internal server error'}), 500

# Trading routes
@app.route('/api/trade', methods=['POST'])
@jwt_required()
def execute_trade():
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        
        required_fields = ['symbol', 'action', 'quantity']
        for field in required_fields:
            if field not in data:
                return jsonify({'error': f'{field} is required'}), 400
        
        result = trading_service.execute_trade(user_id, data)
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error executing trade: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/portfolio', methods=['GET'])
@jwt_required()
def get_portfolio():
    try:
        user_id = get_jwt_identity()
        portfolio = db_service.get_user_portfolio(user_id)
        return jsonify(portfolio)
    except Exception as e:
        logger.error(f"Error getting portfolio: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/transactions', methods=['GET'])
@jwt_required()
def get_transactions():
    try:
        user_id = get_jwt_identity()
        limit = request.args.get('limit', 50, type=int)
        offset = request.args.get('offset', 0, type=int)
        
        transactions = db_service.get_user_transactions(user_id, limit, offset)
        return jsonify(transactions)
    except Exception as e:
        logger.error(f"Error getting transactions: {e}")
        return jsonify({'error': 'Internal server error'}), 500

# Rankings routes
@app.route('/api/rankings', methods=['GET'])
@jwt_required()
def get_rankings():
    try:
        period = request.args.get('period', 'weekly')
        limit = request.args.get('limit', 10, type=int)
        
        rankings = db_service.get_rankings(period, limit)
        return jsonify(rankings)
    except Exception as e:
        logger.error(f"Error getting rankings: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/api/rankings/initialize', methods=['POST'])
@jwt_required()
def initialize_ranking_data():
    """初始化排名系統測試資料"""
    try:
        result = db_service.initialize_test_trading_data()
        logger.info(f"排名資料初始化結果: {result}")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error initializing ranking data: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/rankings/clear', methods=['POST'])
@jwt_required()
def clear_test_data():
    """清除測試資料"""
    try:
        result = db_service.clear_all_trading_test_data()
        logger.info(f"測試資料清除結果: {result}")
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error clearing test data: {e}")
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/performance', methods=['GET'])
@jwt_required()
def get_performance():
    try:
        user_id = get_jwt_identity()
        performance = db_service.get_user_performance(user_id)
        return jsonify(performance)
    except Exception as e:
        logger.error(f"Error getting performance: {e}")
        return jsonify({'error': 'Internal server error'}), 500

# Referral routes
@app.route('/api/referral', methods=['POST'])
@jwt_required()
def submit_referral():
    try:
        user_id = get_jwt_identity()
        data = request.get_json()
        invite_code = data.get('invite_code')
        
        if not invite_code:
            return jsonify({'error': 'Invite code is required'}), 400
        
        result = db_service.process_referral(user_id, invite_code)
        return jsonify(result)
    except Exception as e:
        logger.error(f"Error processing referral: {e}")
        return jsonify({'error': 'Internal server error'}), 500

# Error handlers
@app.errorhandler(404)
def not_found(error):
    return jsonify({'error': 'Not found'}), 404

@app.errorhandler(500)
def internal_error(error):
    return jsonify({'error': 'Internal server error'}), 500

@jwt.expired_token_loader
def expired_token_callback(jwt_header, jwt_payload):
    return jsonify({'error': 'Token has expired'}), 401

@jwt.invalid_token_loader
def invalid_token_callback(error):
    return jsonify({'error': 'Invalid token'}), 401

@jwt.unauthorized_loader
def missing_token_callback(error):
    return jsonify({'error': 'Authorization token is required'}), 401

# Scheduler management routes
@app.route('/admin/scheduler/status', methods=['GET'])
def get_scheduler_status():
    """獲取調度器狀態"""
    try:
        status = scheduler_service.get_status()
        return jsonify(status)
    except Exception as e:
        logger.error(f"Error getting scheduler status: {e}")
        return jsonify({'error': 'Internal server error'}), 500

@app.route('/admin/scheduler/start', methods=['POST'])
def start_scheduler():
    """啟動調度器"""
    try:
        scheduler_service.start()
        return jsonify({'message': 'Scheduler started successfully'})
    except Exception as e:
        logger.error(f"Error starting scheduler: {e}")
        return jsonify({'error': 'Failed to start scheduler'}), 500

@app.route('/admin/scheduler/stop', methods=['POST'])
def stop_scheduler():
    """停止調度器"""
    try:
        scheduler_service.stop()
        return jsonify({'message': 'Scheduler stopped successfully'})
    except Exception as e:
        logger.error(f"Error stopping scheduler: {e}")
        return jsonify({'error': 'Failed to stop scheduler'}), 500

@app.route('/admin/scheduler/force_update', methods=['POST'])
def force_update_all():
    """強制執行所有更新任務"""
    try:
        scheduler_service.force_update_all()
        return jsonify({'message': 'Force update completed'})
    except Exception as e:
        logger.error(f"Error in force update: {e}")
        return jsonify({'error': 'Force update failed'}), 500

# Graceful shutdown
import signal
import sys

def signal_handler(sig, frame):
    logger.info('Gracefully shutting down...')
    scheduler_service.stop()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)
signal.signal(signal.SIGTERM, signal_handler)

if __name__ == '__main__':
    # 啟動調度器
    scheduler_service.start()
    logger.info("Starting Flask application with scheduler...")
    
    try:
        app.run(debug=True, host='0.0.0.0', port=5001)
    finally:
        # 確保調度器在應用關閉時停止
        scheduler_service.stop()