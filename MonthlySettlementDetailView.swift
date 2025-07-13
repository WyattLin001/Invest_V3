import SwiftUI

// MARK: - 月度結算詳情視圖
struct MonthlySettlementDetailView: View {
    let settlement: MonthlySettlement
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 結算概覽
                    settlementOverviewCard()
                    
                    // 收益明細
                    revenueBreakdownCard()
                    
                    // 結算時間線
                    settlementTimelineCard()
                    
                    // 結算說明
                    settlementNotesCard()
                }
                .padding(16)
            }
            .navigationTitle("結算詳情")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - 結算概覽卡片
    private func settlementOverviewCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(settlement.settlementPeriod)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text("結算金額")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(settlement.settlementStatus.icon)
                        .font(.title2)
                    
                    Text(settlement.settlementStatus.displayName)
                        .font(.caption)
                        .foregroundColor(Color(hex: settlement.settlementStatus.color))
                }
            }
            
            Text(settlement.formattedTotalEarnings)
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#00B900"))
            
            // 總收益資訊
            VStack(spacing: 8) {
                HStack {
                    Text("總收入")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settlement.formattedGrossRevenue)
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("平台抽成")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(settlement.formattedPlatformFee)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color(hex: "#DC3545"))
                }
                
                Divider()
                
                HStack {
                    Text("創作者收益")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Spacer()
                    Text(settlement.formattedTotalEarnings)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#00B900"))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 收益明細卡片
    private func revenueBreakdownCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("收益明細")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // 訂閱收益
                if settlement.subscriptionRevenue > 0 {
                    revenueBreakdownItem(
                        icon: "person.2.fill",
                        title: "訂閱分潤",
                        amount: settlement.subscriptionRevenue,
                        color: Color(hex: "#00B900"),
                        description: "平台抽成 30%"
                    )
                }
                
                // 抖內收益
                if settlement.donationRevenue > 0 {
                    revenueBreakdownItem(
                        icon: "heart.fill",
                        title: "抖內收益",
                        amount: settlement.donationRevenue,
                        color: Color(hex: "#FD7E14"),
                        description: "平台抽成 10%"
                    )
                }
                
                // 付費閱讀收益
                if settlement.paidReadingRevenue > 0 {
                    revenueBreakdownItem(
                        icon: "book.fill",
                        title: "付費閱讀",
                        amount: settlement.paidReadingRevenue,
                        color: Color(hex: "#007BFF"),
                        description: "平台抽成 30%"
                    )
                }
                
                // 獎金收益
                if settlement.bonusRevenue > 0 {
                    revenueBreakdownItem(
                        icon: "star.fill",
                        title: "獎金收益",
                        amount: settlement.bonusRevenue,
                        color: Color(hex: "#FFC107"),
                        description: "無抽成"
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 收益明細項目
    private func revenueBreakdownItem(
        icon: String,
        title: String,
        amount: Int,
        color: Color,
        description: String
    ) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text("NT$\(amount)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
        }
        .padding(.vertical, 4)
    }
    
    // MARK: - 結算時間線卡片
    private func settlementTimelineCard() -> some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("結算進度")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // 建立結算
                timelineItem(
                    title: "建立結算",
                    date: settlement.createdAt,
                    status: .completed,
                    description: "系統自動建立結算記錄"
                )
                
                // 處理中
                if let processedAt = settlement.processedAt {
                    timelineItem(
                        title: "開始處理",
                        date: processedAt,
                        status: .completed,
                        description: "結算資料處理完成"
                    )
                }
                
                // 支付完成
                if let paidAt = settlement.paidAt {
                    timelineItem(
                        title: "支付完成",
                        date: paidAt,
                        status: .completed,
                        description: "款項已轉入您的帳戶"
                    )
                } else {
                    timelineItem(
                        title: "等待支付",
                        date: nil,
                        status: getCurrentStatus(),
                        description: "等待審核並處理支付"
                    )
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 時間線項目
    private func timelineItem(
        title: String,
        date: Date?,
        status: TimelineStatus,
        description: String
    ) -> some View {
        HStack {
            VStack {
                Circle()
                    .fill(status.color)
                    .frame(width: 12, height: 12)
                
                if status != .pending {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 2, height: 24)
                }
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                
                if let date = date {
                    Text(date, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
    }
    
    // MARK: - 結算說明卡片
    private func settlementNotesCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("結算說明")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("• 結算時間：每月最後一天自動執行")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• 訂閱分潤：平台抽成30%，作者獲得70%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• 抖內收益：平台抽成10%，作者獲得90%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• 付費閱讀：平台抽成30%，作者獲得70%")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("• 獎金收益：無平台抽成，作者獲得100%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if settlement.isEligibleForWithdrawal {
                Text("✅ 此結算金額達到提領門檻（NT$1,000），可申請提領")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#00B900"))
                    .padding(.top, 8)
            } else {
                Text("⚠️ 此結算金額未達提領門檻（NT$1,000），將累積至下次結算")
                    .font(.caption)
                    .foregroundColor(Color(hex: "#FFC107"))
                    .padding(.top, 8)
            }
            
            if let notes = settlement.notes {
                Text("備註：\(notes)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - 輔助方法
    private func getCurrentStatus() -> TimelineStatus {
        switch settlement.settlementStatus {
        case .pending:
            return .pending
        case .processing:
            return .processing
        case .completed:
            return .completed
        case .paid:
            return .completed
        case .failed:
            return .failed
        case .cancelled:
            return .failed
        }
    }
}

// MARK: - 時間線狀態
enum TimelineStatus {
    case pending
    case processing
    case completed
    case failed
    
    var displayName: String {
        switch self {
        case .pending: return "待處理"
        case .processing: return "處理中"
        case .completed: return "已完成"
        case .failed: return "失敗"
        }
    }
    
    var color: Color {
        switch self {
        case .pending: return Color.gray
        case .processing: return Color(hex: "#007BFF")
        case .completed: return Color(hex: "#00B900")
        case .failed: return Color(hex: "#DC3545")
        }
    }
}

// MARK: - 預覽
struct MonthlySettlementDetailView_Previews: PreviewProvider {
    static var previews: some View {
        MonthlySettlementDetailView(
            settlement: MonthlySettlement(
                authorId: UUID(),
                settlementYear: 2024,
                settlementMonth: 1,
                totalGrossRevenue: 150000,
                totalPlatformFee: 30000,
                totalCreatorEarnings: 120000,
                subscriptionRevenue: 80000,
                donationRevenue: 30000,
                paidReadingRevenue: 10000,
                bonusRevenue: 0,
                status: .completed,
                processedAt: Date(),
                paidAt: Date()
            )
        )
    }
}