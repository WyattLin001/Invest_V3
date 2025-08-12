//
//  TournamentJoinView.swift
//  Invest_V3
//
//  錦標賽參與視圖 - 用戶加入錦標賽的界面
//

import SwiftUI

struct TournamentJoinView: View {
    let tournament: Tournament
    @StateObject private var workflowService: TournamentWorkflowService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 狀態
    @State private var isJoining: Bool = false
    @State private var showingConfirmation: Bool = false
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var alertTitle: String = ""
    
    // 用戶信息（模擬）
    private let currentUserId = UUID() // 在實際應用中從用戶服務獲取
    
    init(tournament: Tournament, workflowService: TournamentWorkflowService) {
        self.tournament = tournament
        self._workflowService = StateObject(wrappedValue: workflowService)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    tournamentHeaderSection
                    tournamentDetailsSection
                    rulesSection
                    requirementsSection
                    participantsSection
                    joinButtonSection
                }
                .padding()
            }
            .navigationTitle("加入錦標賽")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                    .disabled(isJoining)
                }
            }
        }
        .alert(alertTitle, isPresented: $showingAlert) {
            Button("確定") { }
        } message: {
            Text(alertMessage)
        }
        .confirmationDialog("確認加入錦標賽", isPresented: $showingConfirmation, titleVisibility: .visible) {
            Button("確認加入") {
                joinTournament()
            }
            
            Button("取消", role: .cancel) { }
        } message: {
            Text(confirmationMessage)
        }
        .onChange(of: workflowService.successMessage) { message in
            if let message = message {
                alertTitle = "成功"
                alertMessage = message
                showingAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        }
        .onChange(of: workflowService.errorMessage) { message in
            if let message = message {
                alertTitle = "錯誤"
                alertMessage = message
                showingAlert = true
            }
        }
    }
    
    // MARK: - 視圖組件
    
    private var tournamentHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(tournament.name)
                        .font(.title)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    HStack {
                        statusBadge
                        
                        Spacer()
                        
                        Text("ID: \(tournament.id.uuidString.prefix(8))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .monospaced()
                    }
                }
                
                Spacer()
            }
            
            Text(tournament.description)
                .font(.body)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
        )
    }
    
    private var statusBadge: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)
            
            Text(tournament.status.displayName)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(statusColor)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            Capsule()
                .fill(statusColor.opacity(0.1))
        )
    }
    
    private var statusColor: Color {
        switch tournament.status {
        case .upcoming:
            return .blue
        case .active:
            return .green
        case .ended:
            return .gray
        case .cancelled:
            return .red
        case .settling:
            return .orange
        }
    }
    
    private var tournamentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("錦標賽詳情")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                detailRow(icon: "calendar", title: "開始時間", value: formatDate(tournament.startDate))
                detailRow(icon: "calendar.badge.clock", title: "結束時間", value: formatDate(tournament.endDate))
                detailRow(icon: "dollarsign.circle", title: "初始資金", value: formatCurrency(tournament.entryCapital))
                detailRow(icon: "person.3", title: "參與人數", value: "\(tournament.currentParticipants)/\(tournament.maxParticipants)")
                
                if tournament.feeTokens > 0 {
                    detailRow(icon: "star.circle", title: "入場費", value: "\(tournament.feeTokens) 代幣")
                } else {
                    detailRow(icon: "gift", title: "入場費", value: "免費")
                }
                
                detailRow(icon: "chart.line.uptrend.xyaxis", title: "評估指標", value: tournament.returnMetric.uppercased())
                detailRow(icon: "arrow.clockwise", title: "重置週期", value: tournament.resetMode)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("競賽規則")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let rules = tournament.rules {
                VStack(alignment: .leading, spacing: 8) {
                    ruleItem(
                        icon: rules.allowShortSelling ? "checkmark.circle.fill" : "xmark.circle.fill",
                        text: rules.allowShortSelling ? "允許做空交易" : "不允許做空交易",
                        color: rules.allowShortSelling ? .green : .red
                    )
                    
                    ruleItem(
                        icon: "percent",
                        text: "單一持股上限: \(Int(rules.maxPositionSize * 100))%",
                        color: .blue
                    )
                    
                    ruleItem(
                        icon: "clock",
                        text: "交易時間: \(rules.tradingHours.startTime) - \(rules.tradingHours.endTime)",
                        color: .orange
                    )
                    
                    ruleItem(
                        icon: "exclamationmark.triangle",
                        text: "最大回撤限制: \(Int(rules.riskLimits.maxDrawdown * 100))%",
                        color: .red
                    )
                    
                    ruleItem(
                        icon: "arrow.up.right",
                        text: "最大槓桿: \(String(format: "%.1f", rules.riskLimits.maxLeverage))x",
                        color: .purple
                    )
                    
                    if !rules.allowedInstruments.isEmpty {
                        ruleItem(
                            icon: "list.bullet",
                            text: "允許投資: \(rules.allowedInstruments.joined(separator: ", "))",
                            color: .green
                        )
                    }
                }
            } else {
                Text("使用標準競賽規則")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var requirementsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("參與要求")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                requirementItem(
                    icon: "checkmark.circle.fill",
                    text: "完成用戶註冊",
                    isMet: true
                )
                
                requirementItem(
                    icon: tournament.feeTokens > 0 ? "star.circle" : "checkmark.circle.fill",
                    text: tournament.feeTokens > 0 ? "支付 \(tournament.feeTokens) 代幣入場費" : "免費參與",
                    isMet: tournament.feeTokens == 0 // 簡化判斷
                )
                
                requirementItem(
                    icon: tournament.status.canJoin ? "checkmark.circle.fill" : "xmark.circle.fill",
                    text: "錦標賽處於報名狀態",
                    isMet: tournament.status.canJoin
                )
                
                requirementItem(
                    icon: canJoinByCapacity ? "checkmark.circle.fill" : "xmark.circle.fill",
                    text: "錦標賽未滿員",
                    isMet: canJoinByCapacity
                )
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("參與者統計")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Text("\(tournament.currentParticipants)/\(tournament.maxParticipants)")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
            }
            
            ProgressView(value: Double(tournament.currentParticipants), total: Double(tournament.maxParticipants))
                .progressViewStyle(LinearProgressViewStyle(tint: .blue))
            
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("已報名")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(tournament.currentParticipants)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.blue)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("剩餘名額")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("\(tournament.maxParticipants - tournament.currentParticipants)")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    private var joinButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: {
                showingConfirmation = true
            }) {
                HStack {
                    if isJoining {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "person.badge.plus")
                    }
                    
                    Text(isJoining ? "加入中..." : joinButtonText)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(canJoin && !isJoining ? .blue : .gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!canJoin || isJoining)
            
            if !canJoin {
                Text(joinDisabledReason)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else {
                Text("加入後將獲得 \(formatCurrency(tournament.entryCapital)) 虛擬資金進行投資競賽")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - 輔助視圖
    
    private func detailRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .frame(width: 20)
            
            Text(title)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(value)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
        }
        .font(.subheadline)
    }
    
    private func ruleItem(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
    }
    
    private func requirementItem(icon: String, text: String, isMet: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(isMet ? .green : .red)
                .frame(width: 16)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(isMet ? .primary : .secondary)
            
            Spacer()
        }
    }
    
    // MARK: - 計算屬性
    
    private var canJoin: Bool {
        return tournament.status.canJoin && canJoinByCapacity
    }
    
    private var canJoinByCapacity: Bool {
        return tournament.currentParticipants < tournament.maxParticipants
    }
    
    private var joinButtonText: String {
        if !tournament.status.canJoin {
            return "錦標賽已開始"
        } else if !canJoinByCapacity {
            return "名額已滿"
        } else {
            return "加入錦標賽"
        }
    }
    
    private var joinDisabledReason: String {
        if !tournament.status.canJoin {
            return "錦標賽已開始或結束，無法加入"
        } else if !canJoinByCapacity {
            return "錦標賽參與人數已達上限"
        } else {
            return ""
        }
    }
    
    private var confirmationMessage: String {
        var message = "確認要加入 '\(tournament.name)' 錦標賽嗎？\n\n"
        message += "• 您將獲得 \(formatCurrency(tournament.entryCapital)) 虛擬資金\n"
        
        if tournament.feeTokens > 0 {
            message += "• 需要支付 \(tournament.feeTokens) 代幣入場費\n"
        } else {
            message += "• 免費參與\n"
        }
        
        message += "• 錦標賽將於 \(formatDate(tournament.startDate)) 開始"
        
        return message
    }
    
    // MARK: - 方法
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
    
    private func formatCurrency(_ amount: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.locale = Locale(identifier: "zh_TW")
        formatter.currencyCode = "TWD"
        return formatter.string(from: NSNumber(value: amount)) ?? "$\(amount)"
    }
    
    private func joinTournament() {
        isJoining = true
        
        Task {
            do {
                _ = try await workflowService.joinTournament(
                    tournamentId: tournament.id,
                    userId: currentUserId
                )
                
                await MainActor.run {
                    isJoining = false
                }
            } catch {
                await MainActor.run {
                    isJoining = false
                    alertTitle = "加入失敗"
                    alertMessage = error.localizedDescription
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - 預覽

struct TournamentJoinView_Previews: PreviewProvider {
    static var previews: some View {
        let sampleTournament = Tournament(
            id: UUID(),
            name: "科技股挑戰賽",
            description: "專注科技股的投資競賽，測試你的選股能力和風險管理技巧。",
            status: .upcoming,
            startDate: Date().addingTimeInterval(86400),
            endDate: Date().addingTimeInterval(86400 * 7),
            entryCapital: 1000000,
            maxParticipants: 100,
            currentParticipants: 45,
            feeTokens: 100,
            returnMetric: "twr",
            resetMode: "monthly",
            createdAt: Date(),
            rules: TournamentRules(
                allowShortSelling: true,
                maxPositionSize: 0.3,
                allowedInstruments: ["stocks", "etfs"],
                tradingHours: TradingHours(
                    startTime: "09:00",
                    endTime: "16:00",
                    timeZone: "Asia/Taipei"
                ),
                riskLimits: RiskLimits(
                    maxDrawdown: 0.2,
                    maxLeverage: 2.0,
                    maxDailyTrades: 50
                )
            )
        )
        
        TournamentJoinView(
            tournament: sampleTournament,
            workflowService: TournamentWorkflowService(
                tournamentService: TournamentService(),
                tradeService: TournamentTradeService(),
                walletService: TournamentWalletService(),
                rankingService: TournamentRankingService(),
                businessService: TournamentBusinessService()
            )
        )
    }
}