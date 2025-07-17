#!/usr/bin/env python3
"""
簡化的測試伺服器 - 不依賴 Supabase 連接
用於測試基本 Flask 功能和 API 結構
"""

from flask import Flask, jsonify, request
from flask_cors import CORS
import os
import random
import string
from datetime import datetime
from dotenv import load_dotenv

# 載入環境變數
load_dotenv()

app = Flask(__name__)
CORS(app)

# 模擬資料儲存（開發測試用）
mock_users = {}
mock_stocks = [
    {"symbol": "2330", "name": "台灣積體電路製造股份有限公司", "price": 925.0},
    {"symbol": "2317", "name": "鴻海精密工業股份有限公司", "price": 203.5},
    {"symbol": "2454", "name": "聯發科技股份有限公司", "price": 1205.0},
    {"symbol": "2881", "name": "富邦金融控股股份有限公司", "price": 89.7},
    {"symbol": "2882", "name": "國泰金融控股股份有限公司", "price": 65.1}
]

def generate_otp():
    """生成 6 位數 OTP"""
    return ''.join(random.choices(string.digits, k=6))

def generate_invite_code():
    """生成邀請碼"""
    return ''.join(random.choices(string.ascii_uppercase + string.digits, k=8))

@app.route('/health', methods=['GET'])
def health_check():
    """健康檢查端點"""
    return jsonify({
        'status': 'healthy',
        'message': '投資模擬交易平台後端服務運行正常',
        'timestamp': datetime.now().isoformat(),
        'version': '1.0.0'
    })

@app.route('/api/auth/send-otp', methods=['POST'])
def send_otp():
    """發送 OTP"""
    try:
        data = request.json
        phone = data.get('phone')
        
        if not phone:
            return jsonify({'success': False, 'error': '請提供手機號碼'}), 400
        
        # 生成 OTP（開發模式直接返回）
        otp = generate_otp()
        
        # 模擬儲存 OTP
        mock_users[phone] = {
            'otp': otp,
            'created_at': datetime.now().isoformat()
        }
        
        return jsonify({
            'success': True,
            'message': 'OTP 發送成功',
            'otp': otp,  # 開發模式顯示 OTP
            'expires_in': 300
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/auth/verify-otp', methods=['POST'])
def verify_otp():
    """驗證 OTP 並創建/登入用戶"""
    try:
        data = request.json
        phone = data.get('phone')
        otp = data.get('otp')
        invite_code = data.get('invite_code')
        
        if not phone or not otp:
            return jsonify({'success': False, 'error': '請提供手機號碼和驗證碼'}), 400
        
        # 檢查 OTP
        if phone not in mock_users or mock_users[phone]['otp'] != otp:
            return jsonify({'success': False, 'error': '驗證碼錯誤'}), 400
        
        # 模擬用戶創建/登入
        user_id = f"user_{random.randint(1000, 9999)}"
        user_invite_code = generate_invite_code()
        
        user_data = {
            'id': user_id,
            'phone': phone,
            'name': f"用戶{phone[-4:]}",
            'cash_balance': 1000000.0,
            'total_assets': 1000000.0,
            'invite_code': user_invite_code,
            'created_at': datetime.now().isoformat()
        }
        
        # 儲存用戶資料
        mock_users[phone].update(user_data)
        
        return jsonify({
            'success': True,
            'message': '登入成功',
            'user': user_data,
            'access_token': f"mock_token_{user_id}",
            'is_new_user': True,
            'referral_bonus': 100000 if invite_code else 0
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/stocks', methods=['GET'])
def get_stocks():
    """獲取股票清單"""
    try:
        return jsonify({
            'success': True,
            'stocks': mock_stocks,
            'total': len(mock_stocks)
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/stocks/<symbol>', methods=['GET'])
def get_stock_price(symbol):
    """獲取股票價格"""
    try:
        # 找到股票
        stock = next((s for s in mock_stocks if s['symbol'] == symbol), None)
        
        if not stock:
            return jsonify({'success': False, 'error': '股票不存在'}), 404
        
        # 模擬價格波動
        base_price = stock['price']
        current_price = base_price * (1 + random.uniform(-0.05, 0.05))
        
        return jsonify({
            'success': True,
            'symbol': symbol,
            'name': stock['name'],
            'current_price': round(current_price, 2),
            'previous_close': base_price,
            'change': round(current_price - base_price, 2),
            'change_percent': round((current_price - base_price) / base_price * 100, 2),
            'timestamp': datetime.now().isoformat()
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/user/portfolio', methods=['GET'])
def get_portfolio():
    """獲取用戶投資組合"""
    try:
        # 模擬投資組合資料
        portfolio = {
            'cash_balance': 800000.0,
            'total_assets': 1050000.0,
            'total_profit': 50000.0,
            'cumulative_return': 5.0,
            'positions': [
                {
                    'symbol': '2330',
                    'quantity': 100,
                    'average_cost': 900.0,
                    'current_price': 925.0,
                    'market_value': 92500.0,
                    'unrealized_pnl': 2500.0,
                    'unrealized_pnl_percent': 2.78
                },
                {
                    'symbol': '2454',
                    'quantity': 50,
                    'average_cost': 1200.0,
                    'current_price': 1205.0,
                    'market_value': 60250.0,
                    'unrealized_pnl': 250.0,
                    'unrealized_pnl_percent': 0.42
                }
            ]
        }
        
        return jsonify({
            'success': True,
            'portfolio': portfolio
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/trade/buy', methods=['POST'])
def buy_stock():
    """買入股票"""
    try:
        data = request.json
        symbol = data.get('symbol')
        quantity = data.get('quantity')
        price = data.get('price')
        
        if not all([symbol, quantity, price]):
            return jsonify({'success': False, 'error': '缺少必要參數'}), 400
        
        # 計算費用
        total_amount = price * quantity
        fee = max(total_amount * 0.001425, 20)  # 手續費
        total_cost = total_amount + fee
        
        return jsonify({
            'success': True,
            'message': '買入成功',
            'transaction': {
                'symbol': symbol,
                'action': 'buy',
                'quantity': quantity,
                'price': price,
                'total_amount': total_amount,
                'fee': fee,
                'total_cost': total_cost,
                'timestamp': datetime.now().isoformat()
            }
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/trade/sell', methods=['POST'])
def sell_stock():
    """賣出股票"""
    try:
        data = request.json
        symbol = data.get('symbol')
        quantity = data.get('quantity')
        price = data.get('price')
        
        if not all([symbol, quantity, price]):
            return jsonify({'success': False, 'error': '缺少必要參數'}), 400
        
        # 計算費用
        total_amount = price * quantity
        fee = max(total_amount * 0.001425, 20)  # 手續費
        tax = total_amount * 0.003  # 證券交易稅
        total_received = total_amount - fee - tax
        
        return jsonify({
            'success': True,
            'message': '賣出成功',
            'transaction': {
                'symbol': symbol,
                'action': 'sell',
                'quantity': quantity,
                'price': price,
                'total_amount': total_amount,
                'fee': fee,
                'tax': tax,
                'total_received': total_received,
                'timestamp': datetime.now().isoformat()
            }
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.route('/api/rankings', methods=['GET'])
def get_rankings():
    """獲取排行榜"""
    try:
        # 模擬排行榜資料
        rankings = [
            {'rank': 1, 'name': '投資高手', 'return_rate': 15.6, 'total_assets': 1156000},
            {'rank': 2, 'name': '股神學徒', 'return_rate': 12.3, 'total_assets': 1123000},
            {'rank': 3, 'name': '技術分析師', 'return_rate': 9.8, 'total_assets': 1098000},
            {'rank': 4, 'name': '價值投資者', 'return_rate': 8.2, 'total_assets': 1082000},
            {'rank': 5, 'name': '穩健操作', 'return_rate': 6.5, 'total_assets': 1065000}
        ]
        
        return jsonify({
            'success': True,
            'period': 'weekly',
            'rankings': rankings
        })
        
    except Exception as e:
        return jsonify({'success': False, 'error': str(e)}), 500

@app.errorhandler(404)
def not_found(error):
    """404 錯誤處理"""
    return jsonify({'success': False, 'error': 'API 端點不存在'}), 404

@app.errorhandler(500)
def internal_error(error):
    """500 錯誤處理"""
    return jsonify({'success': False, 'error': '內部伺服器錯誤'}), 500

if __name__ == '__main__':
    port = int(os.getenv('PORT', 5000))
    app.run(
        host='0.0.0.0',
        port=port,
        debug=True
    )