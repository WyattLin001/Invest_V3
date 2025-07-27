import Foundation
import Combine

// MARK: - 交易 API 服務
@MainActor
class TradingService: ObservableObject {
    static let shared = TradingService()
    
    // 後端 API 基礎 URL
    private let baseURL = "http://localhost:5001"
    
    // Published 屬性用於 UI 更新
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentUser: TradingUser?
    @Published var portfolio: TradingPortfolio?
    @Published var stocks: [TradingStock] = []
    @Published var transactions: [TradingTransaction] = []
    @Published var rankings: [UserRanking] = []
    
    private var session = URLSession.shared
    private var otpStorage: String = ""
    private var phoneNumber: String = ""
    
    private init() {}
    
    // MARK: - 認證相關
    
    /// 發送 OTP 驗證碼
    func sendOTP(phone: String) async throws {
        self.phoneNumber = phone
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let url = URL(string: "\(baseURL)/api/auth/send-otp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = ["phone": phone]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingError.serverError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(OTPResponse.self, from: data)
        
        if result.success {
            // 在開發模式下，儲存 OTP 供測試使用
            self.otpStorage = result.otp ?? ""
            print("📱 OTP 已發送: \(self.otpStorage)")
        } else {
            throw TradingError.apiError(result.error ?? "發送 OTP 失敗")
        }
    }
    
    /// 驗證 OTP 並登入/註冊
    func verifyOTP(otp: String, inviteCode: String? = nil) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let url = URL(string: "\(baseURL)/api/auth/verify-otp")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        var body: [String: Any] = [
            "phone": phoneNumber,
            "otp": otp
        ]
        
        if let inviteCode = inviteCode, !inviteCode.isEmpty {
            body["invite_code"] = inviteCode
        }
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingError.serverError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(AuthResponse.self, from: data)
        
        if result.success {
            self.currentUser = result.user
            
            // 儲存認證資訊
            UserDefaults.standard.set(result.accessToken, forKey: "trading_access_token")
            UserDefaults.standard.set(result.user.id, forKey: "trading_user_id")
            
            print("✅ 登入成功: \(result.user.name)")
            
            // 載入用戶資料
            await loadUserData()
        } else {
            throw TradingError.apiError(result.error ?? "登入失敗")
        }
    }
    
    /// 檢查登入狀態
    func checkAuthStatus() async {
        guard let token = UserDefaults.standard.string(forKey: "trading_access_token"),
              let userId = UserDefaults.standard.string(forKey: "trading_user_id") else {
            return
        }
        
        // 這裡可以驗證 token 有效性
        // 暫時直接載入用戶資料
        await loadUserData()
    }
    
    /// 登出
    func logout() {
        UserDefaults.standard.removeObject(forKey: "trading_access_token")
        UserDefaults.standard.removeObject(forKey: "trading_user_id")
        
        currentUser = nil
        portfolio = nil
        stocks = []
        transactions = []
        rankings = []
    }
    
    // MARK: - 資料載入
    
    /// 載入用戶資料
    private func loadUserData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadPortfolio() }
            group.addTask { await self.loadStocks() }
            group.addTask { await self.loadTransactions() }
            group.addTask { await self.loadRankings() }
        }
    }
    
    /// 載入投資組合
    func loadPortfolio() async {
        do {
            let url = URL(string: "\(baseURL)/api/user/portfolio")!
            let request = createAuthorizedRequest(url: url)
            
            let (data, _) = try await session.data(for: request)
            let result = try JSONDecoder().decode(PortfolioResponse.self, from: data)
            
            if result.success {
                self.portfolio = result.portfolio
            }
        } catch {
            self.error = "載入投資組合失敗: \(error.localizedDescription)"
        }
    }
    
    /// 載入股票清單
    func loadStocks() async {
        do {
            let url = URL(string: "\(baseURL)/api/stocks")!
            let request = createAuthorizedRequest(url: url)
            
            let (data, _) = try await session.data(for: request)
            let result = try JSONDecoder().decode(StocksResponse.self, from: data)
            
            if result.success {
                self.stocks = result.stocks
            }
        } catch {
            self.error = "載入股票清單失敗: \(error.localizedDescription)"
        }
    }
    
    /// 載入交易記錄
    func loadTransactions() async {
        do {
            let url = URL(string: "\(baseURL)/api/user/transactions")!
            let request = createAuthorizedRequest(url: url)
            
            let (data, _) = try await session.data(for: request)
            let result = try JSONDecoder().decode(TransactionsResponse.self, from: data)
            
            if result.success {
                self.transactions = result.transactions
            }
        } catch {
            self.error = "載入交易記錄失敗: \(error.localizedDescription)"
        }
    }
    
    /// 載入排行榜
    func loadRankings() async {
        do {
            let url = URL(string: "\(baseURL)/api/rankings")!
            let request = createAuthorizedRequest(url: url)
            
            let (data, _) = try await session.data(for: request)
            let result = try JSONDecoder().decode(RankingsResponse.self, from: data)
            
            if result.success {
                self.rankings = result.rankings
            }
        } catch {
            self.error = "載入排行榜失敗: \(error.localizedDescription)"
        }
    }
    
    // MARK: - 交易操作
    
    /// 獲取股票即時價格
    func getStockPrice(symbol: String) async throws -> TradingStockPrice {
        let url = URL(string: "\(baseURL)/api/stocks/\(symbol)")!
        let request = createAuthorizedRequest(url: url)
        
        let (data, _) = try await session.data(for: request)
        let result = try JSONDecoder().decode(StockPriceResponse.self, from: data)
        
        if result.success {
            return TradingStockPrice(
                symbol: result.symbol,
                name: result.name,
                currentPrice: result.currentPrice,
                previousClose: result.previousClose,
                change: result.change,
                changePercent: result.changePercent,
                timestamp: result.timestamp,
                currency: "TWD",
                isTaiwanStock: true
            )
        } else {
            throw TradingError.apiError(result.error ?? "獲取股價失敗")
        }
    }
    
    /// 買入股票
    func buyStock(symbol: String, quantity: Int, price: Double) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let url = URL(string: "\(baseURL)/api/trade/buy")!
        var request = createAuthorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "symbol": symbol,
            "quantity": quantity,
            "price": price
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw TradingError.serverError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(TradeResponse.self, from: data)
        
        if result.success {
            print("✅ 買入成功: \(result.message)")
            // 重新載入投資組合和交易記錄
            await loadPortfolio()
            await loadTransactions()
        } else {
            throw TradingError.apiError(result.error ?? "買入失敗")
        }
    }
    
    /// 賣出股票
    func sellStock(symbol: String, quantity: Int, price: Double) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        // 前端預驗證（可選，提供更好的用戶體驗）
        let totalAmount = Double(quantity) * price
        let suggestion = TradingConstants.getSellSuggestion(
            requestedQuantity: quantity,
            availableQuantity: Int.max, // 這裡假設後端會驗證實際持股
            price: price
        )
        
        // 檢查是否為明顯的不合理交易
        switch suggestion {
        case .rejected(_, let reason, _):
            throw TradingError.sellValidationError(reason)
        default:
            break
        }
        
        let url = URL(string: "\(baseURL)/api/trade/sell")!
        var request = createAuthorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        let body = [
            "symbol": symbol,
            "quantity": quantity,
            "price": price
        ] as [String: Any]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: body)
        
        let (data, response) = try await session.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw TradingError.invalidResponse
        }
        
        // 改善錯誤處理，提供更具體的錯誤信息
        if httpResponse.statusCode != 200 {
            // 嘗試解析錯誤響應
            if let errorData = try? JSONDecoder().decode(TradeErrorResponse.self, from: data) {
                switch errorData.errorCode {
                case "INSUFFICIENT_HOLDINGS":
                    throw TradingError.insufficientHoldings(errorData.message)
                case "MINIMUM_AMOUNT_NOT_MET":
                    throw TradingError.minimumAmountNotMet(errorData.message)
                case "INVALID_QUANTITY":
                    throw TradingError.invalidQuantity(errorData.message)
                default:
                    throw TradingError.apiError(errorData.message)
                }
            } else {
                throw TradingError.serverError(httpResponse.statusCode)
            }
        }
        
        let result = try JSONDecoder().decode(TradeResponse.self, from: data)
        
        if result.success {
            print("✅ 賣出成功: \(result.message)")
            // 重新載入投資組合和交易記錄
            await loadPortfolio()
            await loadTransactions()
        } else {
            // 解析具體的交易失敗原因
            throw TradingError.tradeExecutionFailed(result.error ?? "賣出失敗")
        }
    }
    
    // MARK: - 工具方法
    
    /// 創建帶有認證的請求
    private func createAuthorizedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        
        if let token = UserDefaults.standard.string(forKey: "trading_access_token") {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        
        return request
    }
    
    /// 格式化貨幣
    func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "TWD"
        formatter.maximumFractionDigits = 0
        return formatter.string(from: NSNumber(value: amount)) ?? "NT$0"
    }
    
    /// 格式化百分比
    func formatPercentage(_ percentage: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .percent
        formatter.maximumFractionDigits = 2
        return formatter.string(from: NSNumber(value: percentage / 100)) ?? "0%"
    }
}

// MARK: - 錯誤類型
enum TradingError: Error, LocalizedError {
    case invalidResponse
    case serverError(Int)
    case apiError(String)
    case networkError
    
    // 賣出相關錯誤
    case sellValidationError(String)
    case insufficientHoldings(String)
    case minimumAmountNotMet(String)
    case invalidQuantity(String)
    case tradeExecutionFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "無效的伺服器回應"
        case .serverError(let code):
            return "伺服器錯誤 (\(code))"
        case .apiError(let message):
            return message
        case .networkError:
            return "網路連接錯誤"
        case .sellValidationError(let message):
            return "賣出驗證失敗: \(message)"
        case .insufficientHoldings(let message):
            return "持股不足: \(message)"
        case .minimumAmountNotMet(let message):
            return "金額過小: \(message)"
        case .invalidQuantity(let message):
            return "股數無效: \(message)"
        case .tradeExecutionFailed(let message):
            return "交易執行失敗: \(message)"
        }
    }
    
    /// 獲取用戶友好的錯誤提示和建議
    var userFriendlyMessage: String {
        switch self {
        case .insufficientHoldings:
            return "您的持股數量不足，請檢查持股狀況後再試"
        case .minimumAmountNotMet:
            return "交易金額過小，建議增加賣出數量或選擇價格較高的時機"
        case .invalidQuantity:
            return "請輸入有效的股數（必須為正整數）"
        case .sellValidationError:
            return "賣出條件不符，請檢查股數和價格設定"
        case .tradeExecutionFailed:
            return "交易執行遇到問題，請稍後再試或聯繫客服"
        default:
            return errorDescription ?? "發生未知錯誤"
        }
    }
    
    /// 建議的解決方案
    var suggestions: [String] {
        switch self {
        case .insufficientHoldings:
            return ["檢查您的持股餘額", "減少賣出數量", "確認股票代碼正確"]
        case .minimumAmountNotMet:
            return ["增加賣出股數", "等待更好的價格時機", "考慮一次性賣出更多"]
        case .invalidQuantity:
            return ["輸入正整數股數", "確保股數大於 0", "檢查數字格式"]
        case .sellValidationError:
            return ["檢查股數和價格設定", "使用智能建議功能", "聯繫客服協助"]
        case .tradeExecutionFailed:
            return ["稍後重試", "檢查網路連接", "聯繫客服支援"]
        default:
            return ["稍後重試", "檢查網路連接"]
        }
    }
}