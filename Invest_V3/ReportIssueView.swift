//
//  ReportIssueView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/9.
//

import SwiftUI

struct ReportIssueView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var issueTitle = ""
    @State private var issueDescription = ""
    @State private var selectedIssueType: IssueType = .bug
    @State private var selectedSeverity: IssueSeverity = .medium
    @State private var stepsToReproduce = ""
    @State private var expectedBehavior = ""
    @State private var actualBehavior = ""
    @State private var showSubmissionSuccess = false
    @State private var attachScreenshot = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                    // 說明標頭
                    headerSection
                    
                    // 問題類型選擇
                    issueTypeSection
                    
                    // 嚴重程度選擇
                    severitySection
                    
                    // 基本資訊
                    basicInfoSection
                    
                    // 詳細資訊（Bug 特有）
                    if selectedIssueType == .bug {
                        detailedInfoSection
                    }
                    
                    // 額外選項
                    additionalOptionsSection
                    
                    // 提交按鈕
                    submitButton
                    
                    // 免責聲明
                    disclaimerSection
                }
                .padding(DesignTokens.spacingMD)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("回報問題")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                    .foregroundColor(.brandGreen)
                }
            }
        }
        .alert("提交成功", isPresented: $showSubmissionSuccess) {
            Button("確定") {
                dismiss()
            }
        } message: {
            Text("感謝您的回報！我們會盡快處理您提交的問題。")
        }
    }
    
    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.title2)
                    .foregroundColor(.orange)
                
                Text("幫助我們改進")
                    .font(DesignTokens.sectionHeader)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
            }
            
            Text("發現 Bug 或有改進建議嗎？請詳細描述問題，這將幫助我們更快速地解決問題並提升應用程式品質。")
                .font(DesignTokens.bodyText)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.spacingMD)
        .background(
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.orange.opacity(0.05),
                    Color.orange.opacity(0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(DesignTokens.cornerRadiusLG)
    }
    
    private var issueTypeSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("問題類型")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignTokens.spacingSM) {
                    ForEach(IssueType.allCases, id: \.self) { type in
                        IssueTypeChip(
                            type: type,
                            isSelected: selectedIssueType == type
                        ) {
                            selectedIssueType = type
                        }
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
            }
        }
    }
    
    private var severitySection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("嚴重程度")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(spacing: DesignTokens.spacingXS) {
                ForEach(IssueSeverity.allCases, id: \.self) { severity in
                    SeverityRow(
                        severity: severity,
                        isSelected: selectedSeverity == severity
                    ) {
                        selectedSeverity = severity
                    }
                }
            }
        }
    }
    
    private var basicInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("基本資訊")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // 問題標題
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text("問題標題 *")
                        .font(DesignTokens.captionBold)
                        .foregroundColor(.secondary)
                    
                    TextField("簡短描述您遇到的問題", text: $issueTitle)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // 問題描述
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text("詳細描述 *")
                        .font(DesignTokens.captionBold)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $issueDescription)
                        .frame(height: 100)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(Color(.systemBackground))
        .cornerRadius(DesignTokens.cornerRadius)
    }
    
    private var detailedInfoSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingMD) {
            Text("Bug 詳細資訊")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                // 重現步驟
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text("重現步驟")
                        .font(DesignTokens.captionBold)
                        .foregroundColor(.secondary)
                    
                    TextEditor(text: $stepsToReproduce)
                        .frame(height: 80)
                        .padding(8)
                        .background(Color(.secondarySystemGroupedBackground))
                        .cornerRadius(8)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color(.separator), lineWidth: 1)
                        )
                }
                
                // 預期行為
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text("預期行為")
                        .font(DesignTokens.captionBold)
                        .foregroundColor(.secondary)
                    
                    TextField("您期望應用程式如何運作", text: $expectedBehavior)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                // 實際行為
                VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
                    Text("實際行為")
                        .font(DesignTokens.captionBold)
                        .foregroundColor(.secondary)
                    
                    TextField("實際上發生了什麼", text: $actualBehavior)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(Color(.systemBackground))
        .cornerRadius(DesignTokens.cornerRadius)
    }
    
    private var additionalOptionsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
            Text("其他選項")
                .font(DesignTokens.bodyMedium)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Toggle(isOn: $attachScreenshot) {
                HStack {
                    Image(systemName: "camera")
                        .foregroundColor(.brandGreen)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("附加截圖")
                            .font(DesignTokens.bodySmall)
                            .foregroundColor(.primary)
                        
                        Text("提交後我們會聯繫您獲取截圖")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .toggleStyle(SwitchToggleStyle(tint: .brandGreen))
            .padding(DesignTokens.spacingSM)
            .background(Color(.systemBackground))
            .cornerRadius(DesignTokens.cornerRadius)
        }
    }
    
    private var submitButton: some View {
        Button("提交問題回報") {
            submitIssue()
        }
        .font(DesignTokens.bodyMedium)
        .fontWeight(.semibold)
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.spacingMD)
        .background(canSubmit ? Color.brandGreen : Color.gray)
        .cornerRadius(DesignTokens.cornerRadius)
        .disabled(!canSubmit)
    }
    
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.spacingXS) {
            HStack {
                Image(systemName: "info.circle")
                    .foregroundColor(.blue)
                
                Text("注意事項")
                    .font(DesignTokens.captionBold)
                    .foregroundColor(.primary)
            }
            
            Text("• 請勿在回報中包含個人敏感資訊\n• 我們會在48小時內回覆您的問題\n• 重複的問題回報可能會被合併處理")
                .font(.caption2)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.spacingSM)
        .background(Color.blue.opacity(0.05))
        .cornerRadius(DesignTokens.cornerRadius)
    }
    
    private var canSubmit: Bool {
        !issueTitle.isEmpty && !issueDescription.isEmpty
    }
    
    private func submitIssue() {
        // 觸覺反饋
        let impactFeedback = UINotificationFeedbackGenerator()
        impactFeedback.notificationOccurred(.success)
        
        // 模擬提交過程
        showSubmissionSuccess = true
    }
}

// MARK: - 問題類型
enum IssueType: String, CaseIterable {
    case bug = "Bug回報"
    case feature = "功能請求"
    case improvement = "改進建議"
    case performance = "效能問題"
    case ui = "介面問題"
    case crash = "應用程式崩潰"
    
    var icon: String {
        switch self {
        case .bug: return "ant"
        case .feature: return "plus.circle"
        case .improvement: return "arrow.up.circle"
        case .performance: return "speedometer"
        case .ui: return "paintbrush"
        case .crash: return "exclamationmark.triangle"
        }
    }
    
    var color: Color {
        switch self {
        case .bug: return .red
        case .feature: return .blue
        case .improvement: return .green
        case .performance: return .orange
        case .ui: return .purple
        case .crash: return .pink
        }
    }
}

// MARK: - 嚴重程度
enum IssueSeverity: String, CaseIterable {
    case low = "低"
    case medium = "中"
    case high = "高"
    case critical = "緊急"
    
    var description: String {
        switch self {
        case .low: return "輕微問題，不影響主要功能"
        case .medium: return "一般問題，部分功能受影響"
        case .high: return "重要問題，主要功能受影響"
        case .critical: return "嚴重問題，應用程式無法使用"
        }
    }
    
    var color: Color {
        switch self {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        }
    }
    
    var icon: String {
        switch self {
        case .low: return "checkmark.circle"
        case .medium: return "minus.circle"
        case .high: return "exclamationmark.circle"
        case .critical: return "xmark.circle"
        }
    }
}

// MARK: - 支援組件
struct IssueTypeChip: View {
    let type: IssueType
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingXS) {
                Image(systemName: type.icon)
                    .font(.caption)
                
                Text(type.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, DesignTokens.spacingSM)
            .padding(.vertical, 8)
            .foregroundColor(isSelected ? .white : type.color)
            .background(isSelected ? type.color : type.color.opacity(0.1))
            .cornerRadius(20)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SeverityRow: View {
    let severity: IssueSeverity
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.spacingSM) {
                Image(systemName: severity.icon)
                    .font(.title3)
                    .foregroundColor(severity.color)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(severity.rawValue)
                        .font(DesignTokens.bodyMedium)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(severity.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.brandGreen)
                }
            }
            .padding(DesignTokens.spacingSM)
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

#Preview {
    ReportIssueView()
}