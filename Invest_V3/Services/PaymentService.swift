//
//  PaymentService.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import Foundation
import StoreKit

class PaymentService: NSObject, ObservableObject {
    static let shared = PaymentService()
    
    @Published var products: [SKProduct] = []
    @Published var purchaseState: PurchaseState = .idle
    
    private var productsRequest: SKProductsRequest?
    
    enum PurchaseState {
        case idle
        case purchasing
        case purchased
        case failed(Error)
    }
    
    // Product IDs for In-App Purchases
    private let productIDs = [
        "com.invest.subscription.monthly",  // 月訂閱 300 NTD
        "com.invest.gift.flower",          // 花束 100 NTD
        "com.invest.gift.rocket",          // 火箭 1000 NTD
        "com.invest.gift.gold"             // 黃金 5000 NTD
    ]
    
    override init() {
        super.init()
        SKPaymentQueue.default().add(self)
        fetchProducts()
    }
    
    deinit {
        SKPaymentQueue.default().remove(self)
    }
    
    func fetchProducts() {
        guard !productIDs.isEmpty else { return }
        
        productsRequest = SKProductsRequest(productIdentifiers: Set(productIDs))
        productsRequest?.delegate = self
        productsRequest?.start()
    }
    
    func purchase(product: SKProduct) {
        guard SKPaymentQueue.canMakePayments() else {
            purchaseState = .failed(PaymentError.cannotMakePayments)
            return
        }
        
        purchaseState = .purchasing
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func restorePurchases() {
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    // MARK: - Gift Purchase
    func purchaseGift(type: GiftType, for groupId: UUID) async throws {
        guard let product = products.first(where: { $0.productIdentifier == type.productID }) else {
            throw PaymentError.productNotFound
        }
        
        purchase(product: product)
        
        // Wait for purchase completion
        // In a real implementation, you would handle this through the payment queue delegate
    }
    
    // MARK: - Subscription
    func subscribeToAuthor(authorId: UUID) async throws {
        guard let product = products.first(where: { $0.productIdentifier == "com.invest.subscription.monthly" }) else {
            throw PaymentError.productNotFound
        }
        
        purchase(product: product)
    }
}

// MARK: - SKProductsRequestDelegate
extension PaymentService: SKProductsRequestDelegate {
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.products = response.products
        }
    }
    
    func request(_ request: SKRequest, didFailWithError error: Error) {
        print("Products request failed: \(error)")
    }
}

// MARK: - SKPaymentTransactionObserver
extension PaymentService: SKPaymentTransactionObserver {
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchased:
                handlePurchased(transaction)
            case .failed:
                handleFailed(transaction)
            case .restored:
                handleRestored(transaction)
            case .deferred, .purchasing:
                break
            @unknown default:
                break
            }
        }
    }
    
    private func handlePurchased(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            self.purchaseState = .purchased
        }
        
        // Record transaction in Supabase
        Task {
            await recordTransaction(transaction)
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func handleFailed(_ transaction: SKPaymentTransaction) {
        DispatchQueue.main.async {
            if let error = transaction.error {
                self.purchaseState = .failed(error)
            }
        }
        
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func handleRestored(_ transaction: SKPaymentTransaction) {
        SKPaymentQueue.default().finishTransaction(transaction)
    }
    
    private func recordTransaction(_ transaction: SKPaymentTransaction) async {
        guard let userId = SupabaseService.shared.getCurrentUser()?.id else { return }
        
        let walletTransaction = WalletTransaction(
            id: UUID(),
            userId: userId,
            transactionType: "purchase",
            amount: Int(transaction.payment.product.price.doubleValue * 100), // Convert to cents
            description: "In-App Purchase: \(transaction.payment.productIdentifier)",
            status: "confirmed",
            paymentMethod: "apple_pay",
            blockchainId: transaction.transactionIdentifier,
            createdAt: Date()
        )
        
        do {
            try await SupabaseService.shared.createWalletTransaction(walletTransaction)
        } catch {
            print("Failed to record transaction: \(error)")
        }
    }
}

// MARK: - Supporting Types
enum GiftType: String, CaseIterable {
    case flower = "flower"
    case rocket = "rocket"
    case gold = "gold"
    
    var productID: String {
        switch self {
        case .flower: return "com.invest.gift.flower"
        case .rocket: return "com.invest.gift.rocket"
        case .gold: return "com.invest.gift.gold"
        }
    }
    
    var price: Int {
        switch self {
        case .flower: return 100
        case .rocket: return 1000
        case .gold: return 5000
        }
    }
    
    var emoji: String {
        switch self {
        case .flower: return "🌸"
        case .rocket: return "🚀"
        case .gold: return "🏆"
        }
    }
    
    var description: String {
        switch self {
        case .flower: return "表達支持的小禮物"
        case .rocket: return "推動投資組合起飛"
        case .gold: return "最高等級的認可"
        }
    }
}

enum PaymentError: Error {
    case cannotMakePayments
    case productNotFound
    case transactionFailed
}