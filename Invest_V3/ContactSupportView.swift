//
//  ContactSupportView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/9.
//

import SwiftUI
import MessageUI

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedContactMethod: ContactMethod = .email
    @State private var subject = ""
    @State private var message = ""
    @State private var showMailComposer = false
    @State private var showAlert = false
    @State private var alertMessage = ""
    @State private var selectedCategory: SupportCategory = .general
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                    // 標題說明
                    headerSection
                    
                    // 聯繫方式選擇
                    contactMethodSection
                    
                    // 問題分類
                    categorySectionView
                    
                    // 快速聯繫選項
                    quickContactSection
                    
                    // 聯繫表單（當選擇 App 內聯繫時）
                    if selectedContactMethod == .inApp {
                        contactFormSection
                    }
                    
                    // 營業時間資訊
                    businessHoursSection
                }
                .padding(DesignTokens.spacingMD)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("聯繫支援")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .foregroundColor(.brandGreen)
                }
            }
        }
        .sheet(isPresented: $showMailComposer) {
            MailComposerView(
                subject: generateEmailSubject(),
                messageBody: generateEmailBody(),
                isShowing: $showMailComposer
            )
        }
        .alert("提示", isPresented: $showAlert) {
            Button("確定") {}
        } message: {
            Text(alertMessage)
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Image(systemName: "headphones.circle.fill")
                    .font(.title2)
                    .foregroundColor(.brandGreen)
                
                Text("我們隨時為您服務")
                    .font(DesignTokens.sectionHeader)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Spacer()
            }
            
            Text("遇到問題或需要協助？選擇最適合的聯繫方式，我們的專業團隊將盡快為您解答。")
                .font(DesignTokens.bodyText)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.spacingMD)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.brandGreen.opacity(0.05),
                    Color.brandGreen.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignTokens.cornerRadiusLG)
    }
    
    private var contactMethodSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("選擇聯繫方式")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignTokens.spacingXS) {
                ForEach(ContactMethod.allCases, id: \.self) { method in
                    ContactMethodRow(
                        method: method,
                        isSelected: selectedContactMethod == method
                    ) {
                        selectedContactMethod = method
                        handleContactMethodSelection(method)
                    }
                }
            }
        }
    }
    
    private var categorySectionView: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("問題分類")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(SupportCategory.allCases, id: \.self) { category in
                        CategoryChip(
                            category: category,
                            isSelected: selectedCategory == category
                        ) {
                            selectedCategory = category
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
            }
        }
    }
    
    private var quickContactSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("快速聯繫")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignTokens.spacingXS) {
                QuickContactRow(
                    icon: "envelope.fill",
                    title: "客服信箱",
                    subtitle: "support@invest-v3.com",
                    action: {
                        openEmail()
                    }
                )
                
                QuickContactRow(
                    icon: "phone.fill",
                    title: "客服專線",
                    subtitle: "0800-123-456",
                    action: {
                        callSupport()
                    }
                )
                
                QuickContactRow(
                    icon: "message.fill",
                    title: "線上客服",
                    subtitle: "即時線上協助",
                    action: {
                        // 模擬開啟線上客服
                        alertMessage = "線上客服功能開發中，請使用其他聯繫方式"
                        showAlert = true
                    }
                )
            }
        }
    }
    
    private var contactFormSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("詳細描述問題")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignTokens.spacingSM) {
                // 主題輸入
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text("問題主題")
                        .font(DesignTokens.captionBold)
                        .foregroundColor(.secondary)
                    
                    TextField("請簡述您遇到的問題", text: $subject)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // 詳細描述
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text("詳細描述")
                        .font(DesignTokens.captionBold)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $message)
                        .frame(height: 120)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
            }
            
            // 提交按鈕
            Button("提交問題") {
                submitInAppSupport()
            }
            .font(DesignTokens.bodyMedium)
            .fontWeight(.semibold)
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, DesignTokens.spacingMD)
            .background(subject.isEmpty || message.isEmpty ? Color.gray : Color.brandGreen)
            .cornerRadius(DesignTokens.cornerRadius)
            .disabled(subject.isEmpty || message.isEmpty)
        }
        .padding(DesignTokens.spacingMD)
        .background(Color(.systemBackground))
        .cornerRadius(DesignTokens.cornerRadius)
    }
    
    private var businessHoursSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("服務時間")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                ServiceTimeRow(
                    service: "客服專線",
                    time: "週一至週五 09:00 - 18:00"
                )
                
                ServiceTimeRow(
                    service: "線上客服",
                    time: "週一至週日 24小時"
                )
                
                ServiceTimeRow(
                    service: "電子郵件",
                    time: "24小時內回覆"
                )
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(Color(.systemBackground))
        .cornerRadius(DesignTokens.cornerRadius)
    }
    
    // MARK: - Helper Functions
    
    private func handleContactMethodSelection(_ method: ContactMethod) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
        
        switch method {
        case .email:
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                showMailComposer = true
            }
        case .phone:
            callSupport()
        case .inApp:
            // 顯示表單
            break
        }
    }
    
    private func openEmail() {
        if let url = URL(string: "mailto:support@invest-v3.com?subject=\(generateEmailSubject())&body=\(generateEmailBody())") {
            UIApplication.shared.open(url)
        }
    }
    
    private func callSupport() {
        if let url = URL(string: "tel://0800123456") {
            UIApplication.shared.open(url)
        }
    }
    
    private func submitInAppSupport() {
        // 模擬提交支援請求
        let impactFeedback = UINotificationFeedbackGenerator()
        impactFeedback.notificationOccurred(.success)
        
        alertMessage = "您的問題已成功提交！我們會在24小時內回覆您。"
        showAlert = true
        
        // 清空表單
        subject = ""
        message = ""
    }
    
    private func generateEmailSubject() -> String {
        return "[\(selectedCategory.rawValue)] \(subject.isEmpty ? "需要協助" : subject)"
    }
    
    private func generateEmailBody() -> String {
        let deviceInfo = """
        
        ---
        系統資訊：
        App版本：Invest_V3 v1.0
        設備型號：\(UIDevice.current.model)
        系統版本：\(UIDevice.current.systemVersion)
        問題分類：\(selectedCategory.rawValue)
        """
        
        return message + deviceInfo
    }
}

// MARK: - 支援分類
enum SupportCategory: String, CaseIterable {
    case general = "一般問題"
    case account = "帳戶問題"
    case trading = "交易問題"
    case payment = "付款問題"
    case technical = "技術問題"
    case content = "內容問題"
    case bug = "Bug回報"
    
    var icon: String {
        switch self {
        case .general: return "questionmark.circle"
        case .account: return "person.circle"
        case .trading: return "chart.line.uptrend.xyaxis"
        case .payment: return "creditcard"
        case .technical: return "wrench.and.screwdriver"
        case .content: return "doc.text"
        case .bug: return "ant"
        }
    }
    
    var color: Color {
        switch self {
        case .general: return .blue
        case .account: return .green
        case .trading: return .orange
        case .payment: return .purple
        case .technical: return .red
        case .content: return .mint
        case .bug: return .pink
        }
    }
}

// MARK: - 聯繫方式
enum ContactMethod: String, CaseIterable {
    case email = "電子郵件"
    case phone = "電話聯繫"
    case inApp = "App內聯繫"
    
    var icon: String {
        switch self {
        case .email: return "envelope.fill"
        case .phone: return "phone.fill"
        case .inApp: return "message.fill"
        }
    }
    
    var description: String {
        switch self {
        case .email: return "透過郵件詳細描述問題"
        case .phone: return "直接撥打客服專線"
        case .inApp: return "在應用程式內提交問題"
        }
    }
}

// MARK: - 支援組件
struct ContactMethodRow: View {
    let method: ContactMethod
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: method.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .brandGreen : .secondary)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(method.rawValue)
                        .font(DesignTokens.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.brandGreen)
                }
            }
            .padding(DesignTokens.spacingMD)
            .background(Color(.systemBackground))
            .cornerRadius(DesignTokens.cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                    .stroke(isSelected ? Color.brandGreen : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct CategoryChip: View {
    let category: SupportCategory
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingXS) {
                Image(systemName: category.icon)
                    .font(.caption)
                
                Text(category.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, 6)
            .foregroundColor(isSelected ? .white : category.color)
            .background(isSelected ? category.color : category.color.opacity(0.1))
            .cornerRadius(16)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct QuickContactRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.brandGreen)
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(DesignTokens.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.tertiaryLabel)
            }
            .padding(DesignTokens.spacingSM)
            .background(Color(.systemBackground))
            .cornerRadius(DesignTokens.cornerRadius)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ServiceTimeRow: View {
    let service: String
    let time: String
    
    var body: some View {
        HStack {
            Text(service)
                .font(DesignTokens.bodySmall)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(time)
                .font(DesignTokens.bodySmall)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Mail Composer
struct MailComposerView: UIViewControllerRepresentable {
    let subject: String
    let messageBody: String
    @Binding var isShowing: Bool
    
    func makeUIViewController(context: Context) -> MFMailComposeViewController {
        let composer = MFMailComposeViewController()
        composer.mailComposeDelegate = context.coordinator
        composer.setToRecipients(["support@invest-v3.com"])
        composer.setSubject(subject)
        composer.setMessageBody(messageBody, isHTML: false)
        return composer
    }
    
    func updateUIViewController(_ uiViewController: MFMailComposeViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MFMailComposeViewControllerDelegate {
        var parent: MailComposerView
        
        init(_ parent: MailComposerView) {
            self.parent = parent
        }
        
        func mailComposeController(_ controller: MFMailComposeViewController, didFinishWith result: MFMailComposeResult, error: Error?) {
            parent.isShowing = false
        }
    }
}

#Preview {
    ContactSupportView()
}