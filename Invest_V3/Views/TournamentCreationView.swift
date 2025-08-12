//
//  TournamentCreationView.swift
//  Invest_V3
//
//  錦標賽創建視圖 - 支援完整的錦標賽創建流程
//

import SwiftUI

struct TournamentCreationView: View {
    @StateObject private var workflowService: TournamentWorkflowService
    @Environment(\.dismiss) private var dismiss
    
    // MARK: - 表單狀態
    @State private var tournamentName: String = ""
    @State private var description: String = ""
    @State private var startDate: Date = Date().addingTimeInterval(86400) // 明天
    @State private var endDate: Date = Date().addingTimeInterval(86400 * 7) // 一週後
    @State private var entryCapital: Double = 1000000 // 100萬初始資金
    @State private var maxParticipants: Int = 100
    @State private var feeTokens: Int = 0
    @State private var returnMetric: String = "twr"
    @State private var resetMode: String = "monthly"
    
    // 進階規則設定
    @State private var showAdvancedRules: Bool = false
    @State private var allowShortSelling: Bool = false
    @State private var maxPositionSize: Double = 0.3 // 30%
    @State private var selectedInstruments: Set<String> = ["stocks", "etfs"]
    @State private var tradingStartTime: String = "09:00"
    @State private var tradingEndTime: String = "16:00"
    @State private var maxDrawdown: Double = 0.2 // 20%
    @State private var maxLeverage: Double = 1.0
    @State private var maxDailyTrades: Int = 50
    
    // UI 狀態
    @State private var showingAlert: Bool = false
    @State private var alertMessage: String = ""
    @State private var isCreating: Bool = false
    
    init(workflowService: TournamentWorkflowService) {
        self._workflowService = StateObject(wrappedValue: workflowService)
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    headerSection
                    basicInfoSection
                    dateSection
                    capitalSection
                    participantsSection
                    advancedRulesSection
                    
                    if showAdvancedRules {
                        rulesDetailsSection
                    }
                    
                    createButtonSection
                }
                .padding()
            }
            .navigationTitle("創建錦標賽")
            .navigationBarTitleDisplayMode(.large)
            .navigationBarBackButtonHidden(isCreating)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
            }
        }
        .alert("提示", isPresented: $showingAlert) {
            Button("確定") { }
        } message: {
            Text(alertMessage)
        }
        .onChange(of: workflowService.successMessage) { message in
            if let message = message {
                alertMessage = message
                showingAlert = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    dismiss()
                }
            }
        }
        .onChange(of: workflowService.errorMessage) { message in
            if let message = message {
                alertMessage = message
                showingAlert = true
            }
        }
    }
    
    // MARK: - 視圖組件
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("創建新錦標賽")
                .font(.title2)
                .fontWeight(.bold)
            
            Text("設置錦標賽參數，吸引更多投資者參與競賽")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("基本信息")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("錦標賽名稱")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("輸入錦標賽名稱", text: $tournamentName)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(isCreating)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("描述")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("描述錦標賽規則和目標", text: $description, axis: .vertical)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .lineLimit(3...6)
                        .disabled(isCreating)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var dateSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("時間設定")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("開始時間")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    DatePicker("開始時間", selection: $startDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(CompactDatePickerStyle())
                        .disabled(isCreating)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("結束時間")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    DatePicker("結束時間", selection: $endDate, displayedComponents: [.date, .hourAndMinute])
                        .datePickerStyle(CompactDatePickerStyle())
                        .disabled(isCreating)
                }
                
                if endDate <= startDate {
                    Text("結束時間必須晚於開始時間")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var capitalSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("資金設定")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("初始資金")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    HStack {
                        Text("$")
                            .foregroundColor(.secondary)
                        
                        TextField("1000000", value: $entryCapital, format: .number)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .keyboardType(.numberPad)
                            .disabled(isCreating)
                    }
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("入場費 (代幣)")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("0", value: $feeTokens, format: .number)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .keyboardType(.numberPad)
                        .disabled(isCreating)
                }
                
                Text("初始資金：每位參賽者的虛擬起始資金\n入場費：參賽需要支付的代幣數量（0表示免費）")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("參與者設定")
                .font(.headline)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("最大參與人數")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Stepper(value: $maxParticipants, in: 10...1000, step: 10) {
                        Text("\(maxParticipants) 人")
                            .fontWeight(.medium)
                    }
                    .disabled(isCreating)
                }
                
                Text("建議設定合理的參與人數以確保競爭性和系統性能")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var advancedRulesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showAdvancedRules.toggle()
                }
            }) {
                HStack {
                    Text("進階規則設定")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: showAdvancedRules ? "chevron.up" : "chevron.down")
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showAdvancedRules ? 180 : 0))
                }
            }
            .disabled(isCreating)
            
            if !showAdvancedRules {
                Text("點擊展開設定交易規則、風險限制等進階選項")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
    
    private var rulesDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            // 交易規則
            VStack(alignment: .leading, spacing: 12) {
                Text("交易規則")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                Toggle("允許做空交易", isOn: $allowShortSelling)
                    .disabled(isCreating)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("單一持股上限")
                        .font(.caption)
                    
                    Slider(value: $maxPositionSize, in: 0.1...1.0, step: 0.05) {
                        Text("持股上限")
                    } minimumValueLabel: {
                        Text("10%")
                            .font(.caption)
                    } maximumValueLabel: {
                        Text("100%")
                            .font(.caption)
                    }
                    .disabled(isCreating)
                    
                    Text("目前設定: \(Int(maxPositionSize * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            // 允許的金融商品
            VStack(alignment: .leading, spacing: 12) {
                Text("允許的投資標的")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    Toggle("股票", isOn: Binding(
                        get: { selectedInstruments.contains("stocks") },
                        set: { isOn in
                            if isOn {
                                selectedInstruments.insert("stocks")
                            } else {
                                selectedInstruments.remove("stocks")
                            }
                        }
                    ))
                    .disabled(isCreating)
                    
                    Toggle("ETF", isOn: Binding(
                        get: { selectedInstruments.contains("etfs") },
                        set: { isOn in
                            if isOn {
                                selectedInstruments.insert("etfs")
                            } else {
                                selectedInstruments.remove("etfs")
                            }
                        }
                    ))
                    .disabled(isCreating)
                    
                    Toggle("期貨", isOn: Binding(
                        get: { selectedInstruments.contains("futures") },
                        set: { isOn in
                            if isOn {
                                selectedInstruments.insert("futures")
                            } else {
                                selectedInstruments.remove("futures")
                            }
                        }
                    ))
                    .disabled(isCreating)
                }
            }
            
            Divider()
            
            // 交易時間
            VStack(alignment: .leading, spacing: 12) {
                Text("交易時間")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("開始時間")
                            .font(.caption)
                        
                        TextField("09:00", text: $tradingStartTime)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isCreating)
                    }
                    
                    Text("至")
                        .foregroundColor(.secondary)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("結束時間")
                            .font(.caption)
                        
                        TextField("16:00", text: $tradingEndTime)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .disabled(isCreating)
                    }
                }
            }
            
            Divider()
            
            // 風險限制
            VStack(alignment: .leading, spacing: 12) {
                Text("風險限制")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("最大回撤限制")
                            .font(.caption)
                        
                        Slider(value: $maxDrawdown, in: 0.05...0.5, step: 0.05) {
                            Text("最大回撤")
                        } minimumValueLabel: {
                            Text("5%")
                                .font(.caption)
                        } maximumValueLabel: {
                            Text("50%")
                                .font(.caption)
                        }
                        .disabled(isCreating)
                        
                        Text("目前設定: \(Int(maxDrawdown * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("最大槓桿")
                            .font(.caption)
                        
                        Stepper(value: $maxLeverage, in: 1.0...5.0, step: 0.5) {
                            Text("\(String(format: "%.1f", maxLeverage))x")
                        }
                        .disabled(isCreating)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("單日最大交易次數")
                            .font(.caption)
                        
                        Stepper(value: $maxDailyTrades, in: 10...200, step: 10) {
                            Text("\(maxDailyTrades) 次")
                        }
                        .disabled(isCreating)
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemGray5))
        .cornerRadius(12)
    }
    
    private var createButtonSection: some View {
        VStack(spacing: 12) {
            Button(action: createTournament) {
                HStack {
                    if isCreating {
                        ProgressView()
                            .scaleEffect(0.8)
                            .foregroundColor(.white)
                    } else {
                        Image(systemName: "plus.circle.fill")
                    }
                    
                    Text(isCreating ? "創建中..." : "創建錦標賽")
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(isFormValid && !isCreating ? Color.blue : Color.gray)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || isCreating)
            
            Text("創建後將自動開放報名，錦標賽將按設定時間自動開始")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }
    
    // MARK: - 計算屬性
    
    private var isFormValid: Bool {
        !tournamentName.isEmpty &&
        !description.isEmpty &&
        endDate > startDate &&
        entryCapital > 0 &&
        maxParticipants > 0
    }
    
    // MARK: - 方法
    
    private func createTournament() {
        isCreating = true
        
        let rules = TournamentRules(
            allowShortSelling: allowShortSelling,
            maxPositionSize: maxPositionSize,
            allowedInstruments: Array(selectedInstruments),
            tradingHours: TradingHours(
                startTime: tradingStartTime,
                endTime: tradingEndTime,
                timeZone: "Asia/Taipei"
            ),
            riskLimits: RiskLimits(
                maxDrawdown: maxDrawdown,
                maxLeverage: maxLeverage,
                maxDailyTrades: maxDailyTrades
            )
        )
        
        let parameters = TournamentCreationParameters(
            name: tournamentName,
            description: description,
            startDate: startDate,
            endDate: endDate,
            entryCapital: entryCapital,
            maxParticipants: maxParticipants,
            feeTokens: feeTokens,
            returnMetric: returnMetric,
            resetMode: resetMode,
            rules: rules
        )
        
        Task {
            do {
                _ = try await workflowService.createTournament(parameters)
                
                await MainActor.run {
                    isCreating = false
                }
            } catch {
                await MainActor.run {
                    isCreating = false
                    alertMessage = "創建失敗: \(error.localizedDescription)"
                    showingAlert = true
                }
            }
        }
    }
}

// MARK: - 預覽

struct TournamentCreationView_Previews: PreviewProvider {
    static var previews: some View {
        TournamentCreationView(
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