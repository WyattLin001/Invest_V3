import SwiftUI

struct TradingAuthView: View {
    @ObservedObject private var tradingService = TradingService.shared
    @State private var phoneNumber = ""
    @State private var otp = ""
    @State private var inviteCode = ""
    @State private var isOTPSent = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showInviteCode = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Logo 和標題
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 60))
                        .foregroundColor(Color.brandGreen)
                    
                    Text("投資模擬交易平台")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                    
                    Text("體驗真實的股票交易模擬")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 40)
                
                Spacer()
                
                // 主要表單
                VStack(spacing: 20) {
                    if !isOTPSent {
                        // 手機號碼輸入階段
                        phoneInputSection
                    } else {
                        // OTP 驗證階段
                        otpInputSection
                    }
                    
                    // 邀請碼區域
                    if showInviteCode {
                        inviteCodeSection
                    }
                    
                    // 主要按鈕
                    actionButton
                    
                    // 切換邀請碼顯示
                    if !isOTPSent {
                        toggleInviteCodeButton
                    }
                }
                .padding(.horizontal, 32)
                
                Spacer()
                
                // 底部資訊
                VStack(spacing: 8) {
                    Text("登入即表示您同意我們的")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    HStack(spacing: 4) {
                        Button("服務條款") {
                            // 開啟服務條款
                        }
                        .font(.caption)
                        .foregroundColor(Color.brandGreen)
                        
                        Text("和")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Button("隱私政策") {
                            // 開啟隱私政策
                        }
                        .font(.caption)
                        .foregroundColor(Color.brandGreen)
                    }
                }
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground))
            .navigationBarHidden(true)
        }
        .alert("錯誤", isPresented: $showError) {
            Button("確定", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .onChange(of: tradingService.error) { error in
            if let error = error {
                errorMessage = error
                showError = true
            }
        }
    }
    
    // MARK: - 手機號碼輸入區域
    private var phoneInputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("手機號碼")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                HStack {
                    Text("+886")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.leading, 16)
                    
                    TextField("請輸入手機號碼", text: $phoneNumber)
                        .keyboardType(.phonePad)
                        .textContentType(.telephoneNumber)
                }
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color(.systemGray4), lineWidth: 1)
                )
            }
            
            Text("我們將發送驗證碼到您的手機")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - OTP 輸入區域
    private var otpInputSection: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("驗證碼")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                TextField("請輸入6位數驗證碼", text: $otp)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color(.systemGray4), lineWidth: 1)
                    )
            }
            
            HStack {
                Text("已發送驗證碼到 +886\(phoneNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button("重新發送") {
                    Task {
                        try? await tradingService.sendOTP(phone: "+886\(phoneNumber)")
                    }
                }
                .font(.caption)
                .foregroundColor(Color.brandGreen)
            }
        }
    }
    
    // MARK: - 邀請碼區域
    private var inviteCodeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("邀請碼 (可選)")
                .font(.headline)
                .foregroundColor(.primary)
            
            TextField("輸入邀請碼可獲得NT$100,000獎勵", text: $inviteCode)
                .textCase(.uppercase)
                .padding()
                .background(Color(.systemBackground))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.brandGreen.opacity(0.3), lineWidth: 1)
                )
        }
    }
    
    // MARK: - 主要動作按鈕
    private var actionButton: some View {
        Button(action: performMainAction) {
            HStack {
                if tradingService.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text(isOTPSent ? "驗證並登入" : "發送驗證碼")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                Group {
                    if isFormValid {
                        Color.brandGreen
                    } else {
                        Color.gray.opacity(0.3)
                    }
                }
            )
            .foregroundColor(.white)
            .cornerRadius(12)
        }
        .disabled(!isFormValid || tradingService.isLoading)
    }
    
    // MARK: - 切換邀請碼按鈕
    private var toggleInviteCodeButton: some View {
        Button(action: {
            withAnimation(.easeInOut(duration: 0.3)) {
                showInviteCode.toggle()
            }
        }) {
            HStack {
                Image(systemName: showInviteCode ? "chevron.up" : "gift")
                Text(showInviteCode ? "隱藏邀請碼" : "有邀請碼？獲得NT$100,000獎勵")
                    .fontWeight(.medium)
            }
            .font(.subheadline)
            .foregroundColor(Color.brandGreen)
        }
    }
    
    // MARK: - 計算屬性
    private var isFormValid: Bool {
        if !isOTPSent {
            return phoneNumber.count >= 9 // 台灣手機號碼至少9位
        } else {
            return otp.count == 6 // OTP 6位數
        }
    }
    
    // MARK: - 動作方法
    private func performMainAction() {
        Task {
            do {
                if !isOTPSent {
                    // 發送 OTP
                    try await tradingService.sendOTP(phone: "+886\(phoneNumber)")
                    withAnimation {
                        isOTPSent = true
                    }
                } else {
                    // 驗證 OTP 並登入
                    try await tradingService.verifyOTP(
                        otp: otp,
                        inviteCode: inviteCode.isEmpty ? nil : inviteCode
                    )
                }
            } catch {
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}

// 顏色定義已移至 TradingColors.swift

#Preview {
    TradingAuthView()
}