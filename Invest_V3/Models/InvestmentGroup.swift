//
//  InvestmentGroup.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import Foundation

struct InvestmentGroup: Identifiable, Codable {
    let id: UUID
    let name: String
    let host: String
    let returnRate: Double
    let entryFee: String
    let memberCount: Int
    let category: String
    let createdAt: Date?
    let updatedAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, name, host, category
        case returnRate = "return_rate"
        case entryFee = "entry_fee"
        case memberCount = "member_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

extension InvestmentGroup {
    static let sampleData = [
        InvestmentGroup(
            id: UUID(),
            name: "科技股投資俱樂部",
            host: "張投資",
            returnRate: 15.5,
            entryFee: "1000 NTD",
            memberCount: 25,
            category: "科技股",
            createdAt: Date(),
            updatedAt: Date()
        ),
        InvestmentGroup(
            id: UUID(),
            name: "價值投資學院",
            host: "李分析師",
            returnRate: 12.3,
            entryFee: "2000 NTD",
            memberCount: 18,
            category: "價值投資",
            createdAt: Date(),
            updatedAt: Date()
        ),
        InvestmentGroup(
            id: UUID(),
            name: "加密貨幣先鋒",
            host: "王區塊",
            returnRate: 28.7,
            entryFee: "5000 NTD",
            memberCount: 12,
            category: "加密貨幣",
            createdAt: Date(),
            updatedAt: Date()
        )
    ]
}