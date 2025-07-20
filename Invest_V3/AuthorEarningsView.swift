import SwiftUI

struct AuthorEarningsView: View {
    @StateObject private var viewModel = AuthorEarningsViewModel()

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
        .onAppear {
            Task { await viewModel.loadData() }
        }
        .refreshable {
            await viewModel.refreshData()
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
            HStack {
                earningsBreakdown("訂閱分潤", viewModel.subscriptionEarnings, .green)
                Spacer()
                earningsBreakdown("讀者抖內", viewModel.tipEarnings, .blue)
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