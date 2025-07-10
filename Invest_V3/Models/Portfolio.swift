//
//  Portfolio.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import Foundation

struct Portfolio: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let symbol: String
    let shares: Double
    let averagePrice: Double
    let currentValue: Double
    let returnRate: Double
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, shares
        case userId = "user_id"
        case averagePrice = "average_price"
        case currentValue = "current_value"
        case returnRate = "return_rate"
        case updatedAt = "updated_at"
    }
}

struct PortfolioTransaction: Identifiable, Codable {
    let id: UUID
    let userId: UUID
    let symbol: String
    let action: String // "buy" or "sell"
    let amount: Double
    let price: Double?
    let executedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, symbol, action, amount, price
        case userId = "user_id"
        case executedAt = "executed_at"
    }
}

extension Portfolio {
    static let sampleData = [
        Portfolio(
            id: UUID(),
            userId: UUID(),
            symbol: "AAPL",
            shares: 10.0,
            averagePrice: 150.0,
            currentValue: 1750.0,
            returnRate: 16.67,
            updatedAt: Date()
        ),
        Portfolio(
            id: UUID(),
            userId: UUID(),
            symbol: "TSLA",
            shares: 5.0,
            averagePrice: 200.0,
            currentValue: 1200.0,
            returnRate: 20.0,
            updatedAt: Date()
        ),
        Portfolio(
            id: UUID(),
            userId: UUID(),
            symbol: "NVDA",
            shares: 3.0,
            averagePrice: 400.0,
            currentValue: 1350.0,
            returnRate: 12.5,
            updatedAt: Date()
        )
    ]
}