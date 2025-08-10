import Foundation
import Combine

// MARK: - 交易 API 服務
@MainActor
class TradingService: ObservableObject {
    static let shared = TradingService()
    
    // 一般模式視為永久錦標賽的常量ID
    static let GENERAL_MODE_TOURNAMENT_ID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
    
    // 後端 API 基礎 URL
    private let baseURL = "http://localhost:5001"
    
    // Published 屬性用於 UI 更新（統一使用錦標賽架構）
    @Published var isLoading = false
    @Published var error: String?
    @Published var currentUser: TradingUser?
    @Published var currentPortfolio: TradingPortfolio? // 當前活躍的投資組合（無論一般或錦標賽）
    @Published var stocks: [TradingStock] = []
    @Published var transactions: [TradingTransaction] = []
    @Published var rankings: [UserRanking] = []
    
    // 當前活躍的錦標賽ID（一般模式使用 GENERAL_MODE_TOURNAMENT_ID）
    @Published var currentTournamentId: UUID = GENERAL_MODE_TOURNAMENT_ID
    
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
        currentPortfolio = nil
        stocks = []
        transactions = []
        rankings = []
        
        // 重置為一般模式
        currentTournamentId = Self.GENERAL_MODE_TOURNAMENT_ID
    }
    
    // MARK: - 統一錦標賽架構方法
    
    /// 切換錦標賽（包含一般模式）
    func switchToTournament(_ tournamentId: UUID) async {
        print("🔄 [TradingService] 切換錦標賽: \(tournamentId == Self.GENERAL_MODE_TOURNAMENT_ID ? "一般模式" : tournamentId.uuidString)")
        
        currentTournamentId = tournamentId
        
        // 載入新錦標賽的數據
        await loadCurrentTournamentData()
        
        // 發送切換通知
        NotificationCenter.default.post(
            name: NSNotification.Name("TournamentSwitched"),
            object: self,
            userInfo: [
                "tournamentId": tournamentId.uuidString,
                "isGeneralMode": tournamentId == Self.GENERAL_MODE_TOURNAMENT_ID
            ]
        )
    }
    
    /// 載入用戶資料（統一使用錦標賽架構）
    private func loadUserData() async {
        // 檢查當前是否為錦標賽模式
        let tournamentStateManager = TournamentStateManager.shared
        if tournamentStateManager.isParticipatingInTournament,
           let activeTournamentId = tournamentStateManager.getCurrentTournamentId() {
            currentTournamentId = activeTournamentId
        } else {
            currentTournamentId = Self.GENERAL_MODE_TOURNAMENT_ID
        }
        
        await loadCurrentTournamentData()
    }
    
    /// 載入當前錦標賽數據（統一方法）
    func loadCurrentTournamentData() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTournamentPortfolio(tournamentId: self.currentTournamentId) }
            group.addTask { await self.loadStocks() }
            group.addTask { await self.loadTournamentTransactions(tournamentId: self.currentTournamentId) }
            group.addTask { await self.loadTournamentRankings(tournamentId: self.currentTournamentId) }
        }
    }
    
    /// 載入股票清單（保留，因為股票清單不分錦標賽）
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
    
    /// 載入錦標賽數據（統一方法，支援一般模式）
    func loadTournamentData(tournamentId: UUID) async {
        let isGeneralMode = tournamentId == Self.GENERAL_MODE_TOURNAMENT_ID
        print("🔄 [TradingService] 載入\(isGeneralMode ? "一般模式" : "錦標賽")數據: \(tournamentId)")
        
        // 更新當前錦標賽ID
        currentTournamentId = tournamentId
        
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadTournamentPortfolio(tournamentId: tournamentId) }
            group.addTask { await self.loadStocks() }
            group.addTask { await self.loadTournamentTransactions(tournamentId: tournamentId) }
            group.addTask { await self.loadTournamentRankings(tournamentId: tournamentId) }
        }
        
        // 同時觸發 UI 更新通知
        NotificationCenter.default.post(
            name: NSNotification.Name("TournamentDataReloaded"),
            object: self,
            userInfo: [
                "tournamentId": tournamentId.uuidString,
                "isGeneralMode": isGeneralMode
            ]
        )
        print("📤 [TradingService] 已發送數據重載通知: \(tournamentId)")
    }
    
    /// 載入錦標賽投資組合（統一方法）
    func loadTournamentPortfolio(tournamentId: UUID) async {
        do {
            // 獲取當前用戶ID
            guard let userId = UserDefaults.standard.string(forKey: "trading_user_id") else {
                print("❌ [TradingService] 無法獲取用戶ID，無法載入投資組合")
                return
            }
            
            let isGeneralMode = tournamentId == Self.GENERAL_MODE_TOURNAMENT_ID
            
            // 使用現有API端點
            let url: URL
            if isGeneralMode {
                // 一般模式不傳 tournament_id 參數
                url = URL(string: "\(baseURL)/api/portfolio?user_id=\(userId)")!
                print("📊 [TradingService] 載入一般模式投資組合")
            } else {
                // 錦標賽模式傳入具體的 tournament_id
                url = URL(string: "\(baseURL)/api/portfolio?user_id=\(userId)&tournament_id=\(tournamentId.uuidString)")!
                print("🏆 [TradingService] 載入錦標賽投資組合: \(tournamentId)")
            }
            
            let request = createAuthorizedRequest(url: url)
            let (data, _) = try await session.data(for: request)
            let result = try JSONDecoder().decode(PortfolioResponse.self, from: data)
            
            // 統一存儲到 currentPortfolio
            self.currentPortfolio = result.portfolio
            print("✅ [TradingService] 投資組合載入成功，存儲到 currentPortfolio")
        } catch {
            self.error = "載入投資組合失敗: \(error.localizedDescription)"
            print("❌ [TradingService] 投資組合載入失敗: \(error)")
        }
    }
    
    /// 載入錦標賽交易記錄（統一方法）
    func loadTournamentTransactions(tournamentId: UUID) async {
        do {
            // 獲取當前用戶ID
            guard let userId = UserDefaults.standard.string(forKey: "trading_user_id") else {
                print("❌ [TradingService] 無法獲取用戶ID，無法載入交易記錄")
                return
            }
            
            let isGeneralMode = tournamentId == Self.GENERAL_MODE_TOURNAMENT_ID
            
            // 使用現有API端點
            let url: URL
            if isGeneralMode {
                // 一般模式不傳 tournament_id 參數
                url = URL(string: "\(baseURL)/api/transactions?user_id=\(userId)")!
                print("📊 [TradingService] 載入一般模式交易記錄")
            } else {
                // 錦標賽模式傳入具體的 tournament_id
                url = URL(string: "\(baseURL)/api/transactions?user_id=\(userId)&tournament_id=\(tournamentId.uuidString)")!
                print("🏆 [TradingService] 載入錦標賽交易記錄: \(tournamentId)")
            }
            let request = createAuthorizedRequest(url: url)
            
            let (data, _) = try await session.data(for: request)
            
            // Flask API 直接返回交易陣列
            self.transactions = try JSONDecoder().decode([TradingTransaction].self, from: data)
            print("✅ [TradingService] 交易記錄載入成功: \(transactions.count) 筆")
        } catch {
            self.error = "載入交易記錄失敗: \(error.localizedDescription)"
            print("❌ [TradingService] 交易記錄載入失敗: \(error)")
        }
    }

    
    /// 載入錦標賽排行榜（統一數據源，支援一般模式）
    func loadTournamentRankings(tournamentId: UUID) async {
        do {
            let isGeneralMode = tournamentId == Self.GENERAL_MODE_TOURNAMENT_ID
            
            if isGeneralMode {
                print("📊 [TradingService] 載入一般模式排行榜")
                // 一般模式使用原有的排行榜 API
                let url = URL(string: "\(baseURL)/api/rankings")!
                let request = createAuthorizedRequest(url: url)
                
                let (data, _) = try await session.data(for: request)
                let result = try JSONDecoder().decode(RankingsResponse.self, from: data)
                
                if result.success {
                    self.rankings = result.rankings
                    print("✅ [TradingService] 一般模式排行榜載入成功: \(result.rankings.count) 筆")
                }
            } else {
                print("🏆 [TradingService] 載入錦標賽 \(tournamentId) 的排行榜")
                
                // 嘗試從 Supabase 載入錦標賽排行榜
                let supabaseRankings = try await SupabaseService.shared.fetchTournamentRankingsForUI(tournamentId: tournamentId)
                
                print("✅ [TradingService] 成功載入 \(supabaseRankings.count) 筆錦標賽排行榜")
                self.rankings = supabaseRankings
            }
            
            // 發送排行榜更新通知，確保所有視圖同步
            NotificationCenter.default.post(
                name: NSNotification.Name("TournamentRankingsUpdated"),
                object: self,
                userInfo: [
                    "tournamentId": tournamentId.uuidString,
                    "rankingsCount": rankings.count,
                    "isGeneralMode": isGeneralMode
                ]
            )
            print("📤 [TradingService] 已發送排行榜更新通知: \(tournamentId)")
            
        } catch {
            print("⚠️ [TradingService] API 失敗，使用模擬資料: \(error)")
            
            // 如果 API 失敗，則回退到模擬資料
            let mockRankings = generateMockTournamentRankings(for: tournamentId)
            self.rankings = mockRankings
            
            // 即使使用模擬資料也發送更新通知
            NotificationCenter.default.post(
                name: NSNotification.Name("TournamentRankingsUpdated"),
                object: self,
                userInfo: [
                    "tournamentId": tournamentId.uuidString,
                    "rankingsCount": mockRankings.count,
                    "isSimulated": true
                ]
            )
            
            // 不設置 error，因為有備用資料
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
    
    /// 買入股票（統一架構）
    func buyStock(symbol: String, quantity: Int, price: Double) async throws {
        isLoading = true
        error = nil
        
        defer { isLoading = false }
        
        let url = URL(string: "\(baseURL)/api/trade")!
        var request = createAuthorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 獲取當前用戶ID
        guard let userId = UserDefaults.standard.string(forKey: "trading_user_id") else {
            throw TradingError.apiError("無法獲取用戶ID")
        }
        
        // 計算交易金額（Flask API 需要金額，不是數量）
        let amount = Double(quantity) * price
        
        let isGeneralMode = currentTournamentId == Self.GENERAL_MODE_TOURNAMENT_ID
        
        var body: [String: Any] = [
            "user_id": userId,
            "symbol": symbol,
            "action": "buy",
            "amount": amount
        ]
        
        // 統一添加錦標賽上下文（一般模式不傳錦標賽參數）
        if !isGeneralMode {
            body["tournament_id"] = currentTournamentId.uuidString
            // 可以從 TournamentStateManager 取得錦標賽名稱
            if let tournamentName = TournamentStateManager.shared.currentTournamentContext?.tournament.name {
                body["tournament_name"] = tournamentName
            }
        }
        
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
            print("🔄 [TradingService] 重新載入\(isGeneralMode ? "一般模式" : "錦標賽")數據")
            
            // 統一重新載入當前錦標賽數據
            await loadTournamentData(tournamentId: currentTournamentId)
        } else {
            throw TradingError.apiError(result.error ?? "買入失敗")
        }
    }
    
    /// 賣出股票（統一架構）
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
        
        let url = URL(string: "\(baseURL)/api/trade")!
        var request = createAuthorizedRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // 獲取當前用戶ID
        guard let userId = UserDefaults.standard.string(forKey: "trading_user_id") else {
            throw TradingError.apiError("無法獲取用戶ID")
        }
        
        let isGeneralMode = currentTournamentId == Self.GENERAL_MODE_TOURNAMENT_ID
        
        var body: [String: Any] = [
            "user_id": userId,
            "symbol": symbol,
            "action": "sell",
            "amount": quantity  // 對於賣出，amount 是股數
        ]
        
        // 統一添加錦標賽上下文（一般模式不傳錦標賽參數）
        if !isGeneralMode {
            body["tournament_id"] = currentTournamentId.uuidString
            // 可以從 TournamentStateManager 取得錦標賽名稱
            if let tournamentName = TournamentStateManager.shared.currentTournamentContext?.tournament.name {
                body["tournament_name"] = tournamentName
            }
        }
        
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
            print("🔄 [TradingService] 重新載入\(isGeneralMode ? "一般模式" : "錦標賽")數據")
            
            // 統一重新載入當前錦標賽數據
            await loadTournamentData(tournamentId: currentTournamentId)
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
    
    /// 生成錦標賽專用模擬排行榜資料
    private func generateMockTournamentRankings(for tournamentId: UUID) -> [UserRanking] {
        // 根據不同的錦標賽 ID 生成不同的排行榜資料
        let tournamentString = tournamentId.uuidString
        let participantNames: [String]
        let participantCount: Int
        
        // 根據錦標賽 ID 的前幾個字符來決定模擬數據的特徵
        if tournamentString.hasPrefix("A") || tournamentString.hasPrefix("B") {
            // Test03 類型的錦標賽
            participantNames = ["台股達人", "價值投資者", "技術分析師", "長期投資家", "短線交易員", "ETF專家", "股海航手", "投資老鳥", "理財達人", "資產配置師"]
            participantCount = 8
        } else if tournamentString.hasPrefix("C") || tournamentString.hasPrefix("D") {
            // 2025 Q4 投資錦標賽類型
            participantNames = ["全球投資王", "美股專家", "ETF大師", "量化交易員", "資產管理師", "投資組合家", "風險控制師", "財富管理者", "投資顧問", "基金經理"]
            participantCount = 12
        } else {
            // 其他錦標賽
            participantNames = ["投資新秀", "理財專家", "股市老手", "交易達人", "投資導師", "財務分析師", "市場觀察家", "投資策略家", "績效冠軍", "風險大師"]
            participantCount = 10
        }
        
        var rankings: [UserRanking] = []
        
        // 使用錦標賽 ID 作為隨機種子，確保相同錦標賽總是生成相同的排行榜
        var generator = SeededRandomNumberGenerator(seed: UInt64(abs(tournamentId.hashValue)))
        
        for i in 0..<min(participantCount, participantNames.count) {
            let name = participantNames[i]
            let returnRate = Double.random(in: -15.0...45.0, using: &generator)
            let totalAssets = Double.random(in: 800000...1500000, using: &generator)
            
            let ranking = UserRanking(
                rank: i + 1,
                name: name,
                returnRate: returnRate,
                totalAssets: totalAssets
            )
            
            rankings.append(ranking)
        }
        
        // 按排名排序
        return rankings.sorted { $0.rank < $1.rank }
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