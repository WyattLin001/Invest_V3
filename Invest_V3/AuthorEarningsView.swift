import SwiftUI

struct AuthorEarningsView: View {
    @StateObject private var viewModel = AuthorEarningsViewModel()
    @State private var showWithdrawalAnimation = false
    @State private var animationPhase = 0
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            Group {
                if viewModel.isLoading {
                    loadingState
                } else if viewModel.hasError {
                    errorState
                } else {
                    earningsContent
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemBackground))
        }
        .overlay(withdrawalAnimationOverlay)
        .onAppear {
            Task { await viewModel.loadData() }
        }
        .refreshable {
            await viewModel.refreshData()
        }
        .onChange(of: viewModel.isWithdrawalSuccessful) { success in
            if success {
                startWithdrawalAnimation()
            }
        }
    }

    // MARK: - Content
    private var earningsContent: some View {
        ScrollView {
            LazyVStack(spacing: EarningsDesignTokens.spacing16) {
                navigationHeader
                earningsCard
                withdrawalSection
            }
            .padding(.horizontal, EarningsDesignTokens.spacing16)
        }
        .background(Color(.systemBackground))
    }

    // MARK: - Navigation
    private var navigationHeader: some View {
        HStack {
            Text("創作者收益")
                .font(EarningsDesignTokens.largeTitle)
                .foregroundColor(.primary)
            Spacer()
            
            // 初始化數據按鈕 - 適用於所有用戶
            Button(action: { Task { await viewModel.initializeUserData() } }) {
                Image(systemName: "gear")
                    .foregroundColor(.orange)
                    .imageScale(.large)
            }
            .accessibilityLabel("初始化用戶數據")
            
            Button(action: { Task { await viewModel.refreshData() } }) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.accentColor)
                    .imageScale(.large)
            }
            .accessibilityLabel("重新整理收益資料")
        }
        .padding(.horizontal, EarningsDesignTokens.spacing16)
        .frame(height: 44)
    }

    // MARK: - Earnings Card
    private var earningsCard: some View {
        VStack(alignment: .leading, spacing: EarningsDesignTokens.spacing16) {
            Text("總收益")
                .font(EarningsDesignTokens.headline)
                .foregroundColor(.primary)
            HStack(alignment: .bottom, spacing: EarningsDesignTokens.spacing8) {
                Text("NT$")
                    .font(EarningsDesignTokens.body)
                    .foregroundColor(.secondary)
                Text("\(Int(viewModel.totalEarnings))")
                    .font(EarningsDesignTokens.largeTitle)
                    .foregroundColor(.primary)
            }
            VStack(spacing: EarningsDesignTokens.spacing8) {
                HStack {
                    earningsBreakdown("訂閱分潤", viewModel.subscriptionEarnings, .green)
                    Spacer()
                    earningsBreakdown("讀者抖內", viewModel.tipEarnings, .blue)
                }
                
                HStack {
                    earningsBreakdown("群組入會費", viewModel.groupEntryFeeEarnings, .orange)
                    Spacer()
                    earningsBreakdown("群組抖內", viewModel.groupTipEarnings, .purple)
                }
            }
        }
        .padding(EarningsDesignTokens.spacing16)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(EarningsDesignTokens.cornerRadius12)
        .shadow(color: EarningsDesignTokens.cardShadow,
                radius: EarningsDesignTokens.shadowRadius,
                x: EarningsDesignTokens.shadowOffset.width,
                y: EarningsDesignTokens.shadowOffset.height)
    }

    private func earningsBreakdown(_ title: String, _ value: Double, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: EarningsDesignTokens.spacing4) {
            Text(title)
                .font(EarningsDesignTokens.caption)
                .foregroundColor(.secondary)
            Text("NT$\(Int(value))")
                .font(EarningsDesignTokens.caption)
                .fontWeight(.medium)
                .foregroundColor(color)
        }
    }

    // MARK: - Withdrawal Section
    private var withdrawalSection: some View {
        VStack(alignment: .leading, spacing: EarningsDesignTokens.spacing16) {
            withdrawalProgress
            withdrawalButton
        }
    }

    private var withdrawalProgress: some View {
        VStack(alignment: .leading, spacing: EarningsDesignTokens.spacing8) {
            HStack {
                Text("提領進度")
                    .font(EarningsDesignTokens.body)
                Spacer()
                Text("\(Int(viewModel.withdrawableAmount))/1000")
                    .font(EarningsDesignTokens.caption)
                    .foregroundColor(.secondary)
            }
            ProgressView(value: viewModel.withdrawableAmount / 1000)
                .progressViewStyle(LinearProgressViewStyle(tint: .accentColor))
                .scaleEffect(x: 1, y: 2)
        }
    }

    private var withdrawalButton: some View {
        Button(action: {
            Task {
                await viewModel.initiateWithdrawal()
            }
        }) {
            HStack {
                if viewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title3)
                    Text("申請提領")
                        .font(EarningsDesignTokens.body)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(
                LinearGradient(colors: [.accentColor, .accentColor.opacity(0.8)],
                               startPoint: .leading,
                               endPoint: .trailing)
            )
            .cornerRadius(EarningsDesignTokens.cornerRadius12)
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(viewModel.withdrawableAmount < 1000 || viewModel.isLoading)
    }

    private var loadingState: some View {
        VStack(spacing: EarningsDesignTokens.spacing16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("載入收益資料...")
                .font(EarningsDesignTokens.body)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }

    private var errorState: some View {
        VStack(spacing: EarningsDesignTokens.spacing16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("載入失敗")
                .font(EarningsDesignTokens.headline)
            Button("重試") {
                Task { await viewModel.loadData() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    // MARK: - Withdrawal Animation
    
    @ViewBuilder
    private var withdrawalAnimationOverlay: some View {
        if showWithdrawalAnimation {
            ZStack {
                // 半透明背景
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                
                // 動畫內容
                VStack(spacing: 24) {
                    // 階段1: 錢幣圖示
                    if animationPhase >= 1 {
                        Image(systemName: "dollarsign.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                            .scaleEffect(animationPhase == 1 ? 1.2 : 1.0)
                            .animation(.spring(response: 0.6, dampingFraction: 0.8), value: animationPhase)
                    }
                    
                    // 階段2: 轉移動畫
                    if animationPhase >= 2 {
                        HStack(spacing: 40) {
                            VStack {
                                Image(systemName: "doc.text.fill")
                                    .font(.title)
                                    .foregroundColor(.blue)
                                Text("創作收益")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                            
                            // 動畫箭頭
                            Image(systemName: "arrow.right")
                                .font(.title2)
                                .foregroundColor(.white)
                                .scaleEffect(animationPhase == 2 ? 1.5 : 1.0)
                                .animation(.easeInOut(duration: 0.8).repeatCount(3, autoreverses: true), value: animationPhase)
                            
                            VStack {
                                Image(systemName: "wallet.pass.fill")
                                    .font(.title)
                                    .foregroundColor(.green)
                                Text("錢包")
                                    .font(.caption)
                                    .foregroundColor(.white)
                            }
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                    
                    // 階段3: 成功訊息
                    if animationPhase >= 3 {
                        VStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 50))
                                .foregroundColor(.green)
                                .scaleEffect(animationPhase == 3 ? 1.3 : 1.0)
                                .animation(.spring(response: 0.5, dampingFraction: 0.7), value: animationPhase)
                            
                            Text("提領成功！")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            
                            Text("代幣已轉入您的錢包")
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        .transition(.scale.combined(with: .opacity))
                    }
                }
                .padding(40)
            }
        }
    }
    
    // MARK: - Animation Functions
    
    private func startWithdrawalAnimation() {
        showWithdrawalAnimation = true
        animationPhase = 0
        
        // 階段1: 顯示錢幣圖示
        withAnimation(.easeInOut(duration: 0.5)) {
            animationPhase = 1
        }
        
        // 階段2: 轉移動畫 (1秒後)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.8)) {
                animationPhase = 2
            }
        }
        
        // 階段3: 成功訊息 (2.5秒後)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            withAnimation(.easeInOut(duration: 0.5)) {
                animationPhase = 3
            }
        }
        
        // 自動隱藏動畫 (4.5秒後)
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) {
            hideWithdrawalAnimation()
        }
    }
    
    private func hideWithdrawalAnimation() {
        withAnimation(.easeInOut(duration: 0.3)) {
            showWithdrawalAnimation = false
            animationPhase = 0
        }
    }
}

struct AuthorEarningsView_Previews: PreviewProvider {
    static var previews: some View {
        AuthorEarningsView()
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}