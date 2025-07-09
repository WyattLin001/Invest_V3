import SwiftUI

// MARK: - 支付選項視圖
struct PaymentOptionsView: View {
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("選擇支付方式")
                    .font(.title2)
                    .fontWeight(.bold)
                
                VStack(spacing: 16) {
                    PaymentOptionRow(title: "街口支付", icon: "creditcard")
                    PaymentOptionRow(title: "LINE Pay", icon: "creditcard.fill")
                    PaymentOptionRow(title: "Apple Pay", icon: "applelogo")
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("儲值")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }
}

struct PaymentOptionRow: View {
    let title: String
    let icon: String
    
    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.brandGreen)
            
            Text(title)
                .font(.headline)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(radius: 2)
    }
}

// MARK: - 平台會員訂閱視圖
struct SubscriptionView: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: String = "monthly"
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showSuccessMessage = false
    @State private var isSubscribed = false
    @State private var currentSubscription: PlatformSubscription?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                if isLoading {
                    ProgressView("載入中...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isSubscribed, let subscription = currentSubscription {
                    // 已訂閱狀態
                    subscribedStatusView(subscription: subscription)
                } else {
                    // 未訂閱狀態
                    subscriptionPlansView
                }
            }
            .padding()
            .navigationTitle("平台會員")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
            .onAppear {
                checkSubscriptionStatus()
            }
            .alert("訂閱成功", isPresented: $showSuccessMessage) {
                Button("確定") {
                    dismiss()
                }
            } message: {
                Text("歡迎成為平台會員！現在您可以無限閱讀所有付費文章。")
            }
        }
    }
    
    // MARK: - 訂閱方案選擇視圖
    private var subscriptionPlansView: some View {
        VStack(spacing: 24) {
            // 標題和描述
            VStack(spacing: 12) {
                Text("升級為平台會員")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray900)
                
                Text("無限閱讀所有付費文章，支持優質內容創作者")
                    .font(.body)
                    .foregroundColor(.gray600)
                    .multilineTextAlignment(.center)
            }
            
            // 會員權益
            VStack(alignment: .leading, spacing: 12) {
                Text("會員權益")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.gray900)
                
                VStack(alignment: .leading, spacing: 8) {
                    benefitRow(icon: "doc.text.fill", text: "無限閱讀所有付費文章")
                    benefitRow(icon: "star.fill", text: "支持優質內容創作者")
                    benefitRow(icon: "chart.line.uptrend.xyaxis", text: "獲得專業投資分析")
                    benefitRow(icon: "bell.fill", text: "優先獲得市場資訊")
                }
            }
            .padding()
            .background(Color.gray50)
            .cornerRadius(12)
            
            // 訂閱方案選擇
            VStack(spacing: 16) {
                PlatformSubscriptionPlan(
                    title: "月費會員",
                    price: "500 代幣",
                    period: "每月",
                    originalPrice: nil,
                    isRecommended: false,
                    isSelected: selectedPlan == "monthly"
                ) {
                    selectedPlan = "monthly"
                }
                
                PlatformSubscriptionPlan(
                    title: "年費會員",
                    price: "5,000 代幣",
                    period: "每年",
                    originalPrice: "6,000 代幣",
                    isRecommended: true,
                    isSelected: selectedPlan == "yearly"
                ) {
                    selectedPlan = "yearly"
                }
            }
            
            // 訂閱按鈕
            Button(action: handleSubscription) {
                HStack {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    Text(isLoading ? "處理中..." : "立即訂閱")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.brandGreen)
                .cornerRadius(12)
            }
            .disabled(isLoading)
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
            
            Spacer()
        }
    }
    
    // MARK: - 已訂閱狀態視圖
    private func subscribedStatusView(subscription: PlatformSubscription) -> some View {
        VStack(spacing: 24) {
            // 會員狀態
            VStack(spacing: 16) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.brandGreen)
                
                Text("您已是平台會員")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray900)
                
                Text("享受無限制閱讀所有付費文章")
                    .font(.body)
                    .foregroundColor(.gray600)
                    .multilineTextAlignment(.center)
            }
            
            // 訂閱詳情
            VStack(spacing: 16) {
                subscriptionDetailRow(
                    title: "訂閱類型",
                    value: subscription.subscriptionType == "monthly" ? "月費會員" : "年費會員"
                )
                
                subscriptionDetailRow(
                    title: "到期時間",
                    value: DateFormatter.shortDate.string(from: subscription.endDate)
                )
                
                subscriptionDetailRow(
                    title: "剩餘天數",
                    value: "\(subscription.remainingDays) 天"
                )
            }
            .padding()
            .background(Color.gray50)
            .cornerRadius(12)
            
            Spacer()
        }
    }
    
    // MARK: - 輔助視圖
    private func benefitRow(icon: String, text: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.brandGreen)
                .frame(width: 20)
            
            Text(text)
                .font(.body)
                .foregroundColor(.gray700)
            
            Spacer()
        }
    }
    
    private func subscriptionDetailRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.body)
                .foregroundColor(.gray600)
            
            Spacer()
            
            Text(value)
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(.gray900)
        }
    }
    
    // MARK: - 業務邏輯
    private func checkSubscriptionStatus() {
        isLoading = true
        Task {
            do {
                currentSubscription = try await SupabaseService.shared.getPlatformSubscription()
                isSubscribed = currentSubscription != nil
            } catch {
                print("❌ 檢查訂閱狀態失敗: \(error)")
                errorMessage = "載入訂閱狀態失敗"
            }
            isLoading = false
        }
    }
    
    private func handleSubscription() {
        isLoading = true
        errorMessage = nil
        
        Task {
            do {
                let subscription = try await SupabaseService.shared.subscribeToPlatform(subscriptionType: selectedPlan)
                currentSubscription = subscription
                isSubscribed = true
                showSuccessMessage = true
            } catch {
                errorMessage = error.localizedDescription
                print("❌ 訂閱失敗: \(error)")
            }
            isLoading = false
        }
    }
}

// MARK: - 平台訂閱方案卡片
struct PlatformSubscriptionPlan: View {
    let title: String
    let price: String
    let period: String
    let originalPrice: String?
    let isRecommended: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(title)
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.gray900)
                            
                            if isRecommended {
                                Text("推薦")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.brandOrange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        HStack(alignment: .bottom, spacing: 4) {
                            Text(price)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.brandGreen)
                            
                            Text(period)
                                .font(.caption)
                                .foregroundColor(.gray600)
                            
                            if let originalPrice = originalPrice {
                                Text(originalPrice)
                                    .font(.caption)
                                    .foregroundColor(.gray400)
                                    .strikethrough()
                            }
                        }
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(isSelected ? .brandGreen : .gray400)
                }
            }
            .padding()
            .background(isSelected ? Color.brandGreen.opacity(0.1) : Color.white)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? Color.brandGreen : Color.gray300, lineWidth: isSelected ? 2 : 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 日期格式化擴展
extension DateFormatter {
    static let shortDate: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        formatter.locale = Locale(identifier: "zh_TW")
        return formatter
    }()
}

// MARK: - 禮物購買視圖
struct GiftPurchaseView: View {
    let gift: GiftItem
    @Binding var quantity: Int
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text(gift.icon)
                    .font(.system(size: 80))
                
                Text(gift.name)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(gift.description)
                    .font(.body)
                    .foregroundColor(.gray)
                
                HStack {
                    Text("數量:")
                    Stepper(value: $quantity, in: 1...10) {
                        Text("\(quantity)")
                            .font(.headline)
                    }
                }
                
                Text("總計: \(TokenSystem.formatTokens((gift.price * Double(quantity)).ntdToTokens()))")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.brandGreen)
                
                Button("購買") {
                    // 處理購買邏輯
                    dismiss()
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.brandGreen)
                .foregroundColor(.white)
                .cornerRadius(12)
                
                Spacer()
            }
            .padding()
            .navigationTitle("購買禮物")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("關閉") { dismiss() }
                }
            }
        }
    }
} 