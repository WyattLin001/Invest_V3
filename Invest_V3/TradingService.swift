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
        
        guard httpResponse.statusCode == 200 else {
            throw TradingError.serverError(httpResponse.statusCode)
        }
        
        let result = try JSONDecoder().decode(TradeResponse.self, from: data)
        
        if result.success {
            print("✅ 賣出成功: \(result.message)")
            // 重新載入投資組合和交易記錄
            await loadPortfolio()
            await loadTransactions()
        } else {
            throw TradingError.apiError(result.error ?? "賣出失敗")
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
        }
    }
}