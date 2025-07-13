import SwiftUI

// MARK: - 提領申請視圖
struct WithdrawalRequestView: View {
    @StateObject private var creatorService = CreatorRevenueService()
    @Environment(\.presentationMode) var presentationMode
    
    let authorId: UUID
    let availableBalance: Int
    
    @State private var selectedMethod: WithdrawalMethod = .bankTransfer
    @State private var withdrawalAmount: String = ""
    @State private var bankAccount: String = ""
    @State private var bankCode: String = ""
    @State private var accountHolder: String = ""
    @State private var phoneNumber: String = ""
    @State private var email: String = ""
    @State private var reason: String = ""
    @State private var showingConfirmation = false
    @State private var isSubmitting = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 餘額資訊
                    balanceInfoCard()
                    
                    // 提領方式選擇
                    withdrawalMethodSection()
                    
                    // 提領金額
                    withdrawalAmountSection()
                    
                    // 收款資訊
                    paymentInfoSection()
                    
                    // 聯繫資訊
                    contactInfoSection()
                    
                    // 申請原因
                    reasonSection()
                    
                    // 手續費說明
                    feeInfoSection()
                    
                    // 提交按鈕
                    submitButton()
                }
                .padding(16)
            }
            .navigationTitle("申請提領")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .confirmationDialog("確認提領申請", isPresented: $showingConfirmation) {
                Button("確認提領") {
                    Task {
                        await submitWithdrawal()
                    }
                }
                .disabled(isSubmitting)
                
                Button("取消", role: .cancel) { }
            } message: {
                Text("確定要申請提領 \(formattedAmount) 嗎？")
            }
        }
    }
    
    // MARK: - 餘額資訊卡片
    private func balanceInfoCard() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("可提領餘額")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("NT$\(availableBalance / 100)")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color(hex: "#00B900"))
            
            Text("最低提領金額 NT$1,000")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemBackground))
                .shadow(color: Color.black.opacity(0.1), radius: 2, x: 0, y: 1)
        )
    }
    
    // MARK: - 提領方式選擇
    private func withdrawalMethodSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提領方式")
                .font(.headline)
                .fontWeight(.semibold)
            
            ForEach(WithdrawalMethod.allCases, id: \.self) { method in
                withdrawalMethodRow(method: method)
            }
        }
    }
    
    private func withdrawalMethodRow(method: WithdrawalMethod) -> some View {
        Button(action: {
            selectedMethod = method
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(method.icon)
                            .font(.title2)
                        
                        Text(method.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                    }
                    
                    HStack {
                        Text("手續費: \(method.formattedFee)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                        
                        Text("處理時間: \(method.processingTime)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                if selectedMethod == method {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(hex: "#00B900"))
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(selectedMethod == method ? Color(hex: "#00B900") : Color.gray.opacity(0.3), lineWidth: 2)
                    .fill(selectedMethod == method ? Color(hex: "#00B900").opacity(0.05) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - 提領金額
    private func withdrawalAmountSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("提領金額")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("NT$")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    TextField("請輸入提領金額", text: $withdrawalAmount)
                        .font(.title2)
                        .fontWeight(.medium)
                        .keyboardType(.numberPad)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
                
                HStack {
                    Text("最低: NT$\(selectedMethod.minimumAmount / 100)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("最高: NT$\(selectedMethod.maximumAmount / 100)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                // 快速金額選擇
                HStack {
                    ForEach([1000, 2000, 5000], id: \.self) { amount in
                        Button(action: {
                            withdrawalAmount = "\(amount)"
                        }) {
                            Text("NT$\(amount)")
                                .font(.caption)
                                .foregroundColor(Color(hex: "#007BFF"))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(hex: "#007BFF"), lineWidth: 1)
                                )
                        }
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        withdrawalAmount = "\(availableBalance / 100)"
                    }) {
                        Text("全部")
                            .font(.caption)
                            .foregroundColor(Color(hex: "#007BFF"))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(hex: "#007BFF"), lineWidth: 1)
                            )
                    }
                }
            }
        }
    }
    
    // MARK: - 收款資訊
    private func paymentInfoSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("收款資訊")
                .font(.headline)
                .fontWeight(.semibold)
            
            switch selectedMethod {
            case .bankTransfer:
                bankTransferFields()
            case .digitalWallet:
                digitalWalletFields()
            case .cryptocurrency:
                cryptocurrencyFields()
            }
        }
    }
    
    private func bankTransferFields() -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("銀行代碼")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("例如: 004", text: $bankCode)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("銀行帳號")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("請輸入銀行帳號", text: $bankAccount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.numberPad)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("戶名")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("請輸入戶名", text: $accountHolder)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
        }
    }
    
    private func digitalWalletFields() -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("手機號碼")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("請輸入手機號碼", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("電子郵件")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("請輸入電子郵件", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
            }
        }
    }
    
    private func cryptocurrencyFields() -> some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("錢包地址")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("請輸入錢包地址", text: $bankAccount)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .font(.system(.body, design: .monospaced))
            }
            
            Text("⚠️ 請確認錢包地址正確，轉帳後無法復原")
                .font(.caption)
                .foregroundColor(Color(hex: "#FD7E14"))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(hex: "#FD7E14").opacity(0.1))
                )
        }
    }
    
    // MARK: - 聯繫資訊
    private func contactInfoSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("聯繫資訊")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("電子郵件")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("請輸入電子郵件", text: $email)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.emailAddress)
            }
            
            VStack(alignment: .leading, spacing: 8) {
                Text("手機號碼")
                    .font(.subheadline)
                    .fontWeight(.medium)
                TextField("請輸入手機號碼", text: $phoneNumber)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .keyboardType(.phonePad)
            }
        }
    }
    
    // MARK: - 申請原因
    private func reasonSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("申請原因（選填）")
                .font(.headline)
                .fontWeight(.semibold)
            
            TextField("請輸入申請原因", text: $reason, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(minHeight: 80)
        }
    }
    
    // MARK: - 手續費說明
    private func feeInfoSection() -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("手續費說明")
                .font(.subheadline)
                .fontWeight(.medium)
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("提領金額:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formattedAmount)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("手續費:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(selectedMethod.formattedFee)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                
                Divider()
                
                HStack {
                    Text("實際到帳:")
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                    Text(formattedActualAmount)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(Color(hex: "#00B900"))
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
        )
    }
    
    // MARK: - 提交按鈕
    private func submitButton() -> some View {
        Button(action: {
            showingConfirmation = true
        }) {
            HStack {
                if isSubmitting {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                }
                
                Text(isSubmitting ? "提交中..." : "提交申請")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isFormValid && !isSubmitting ? Color(hex: "#00B900") : Color.gray)
            )
        }
        .disabled(!isFormValid || isSubmitting)
    }
    
    // MARK: - 計算屬性
    private var formattedAmount: String {
        let amount = Int(withdrawalAmount) ?? 0
        return "NT$\(amount)"
    }
    
    private var formattedActualAmount: String {
        let amount = Int(withdrawalAmount) ?? 0
        let actualAmount = amount - selectedMethod.feeAmount / 100
        return "NT$\(actualAmount)"
    }
    
    private var isFormValid: Bool {
        guard let amount = Int(withdrawalAmount),
              amount >= selectedMethod.minimumAmount / 100,
              amount <= selectedMethod.maximumAmount / 100,
              amount <= availableBalance / 100 else {
            return false
        }
        
        switch selectedMethod {
        case .bankTransfer:
            return !bankCode.isEmpty && !bankAccount.isEmpty && !accountHolder.isEmpty
        case .digitalWallet:
            return !phoneNumber.isEmpty && !email.isEmpty
        case .cryptocurrency:
            return !bankAccount.isEmpty // 使用 bankAccount 存儲錢包地址
        }
    }
    
    // MARK: - 提交提領申請
    private func submitWithdrawal() async {
        isSubmitting = true
        defer { isSubmitting = false }
        
        guard let amount = Int(withdrawalAmount) else { return }
        
        do {
            let _ = try await creatorService.submitWithdrawalRequest(
                userId: authorId,
                amount: amount * 100, // 轉換為分
                method: selectedMethod,
                bankAccount: selectedMethod == .bankTransfer ? bankAccount : selectedMethod == .cryptocurrency ? bankAccount : nil,
                bankCode: selectedMethod == .bankTransfer ? bankCode : nil,
                accountHolder: selectedMethod == .bankTransfer ? accountHolder : nil,
                phoneNumber: selectedMethod == .digitalWallet ? phoneNumber : phoneNumber,
                email: email,
                reason: reason.isEmpty ? nil : reason
            )
            
            presentationMode.wrappedValue.dismiss()
            
        } catch {
            print("提交提領申請失敗: \(error)")
        }
    }
}

// MARK: - 預覽
struct WithdrawalRequestView_Previews: PreviewProvider {
    static var previews: some View {
        WithdrawalRequestView(authorId: UUID(), availableBalance: 500000)
    }
}