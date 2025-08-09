//
//  TutorialView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/9.
//

import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var currentStep = 0
    @State private var showCompletionCelebration = false
    
    private let tutorials = TutorialData.allTutorials
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 進度指示器
                progressIndicator
                
                // 教學內容
                TabView(selection: $currentStep) {
                    ForEach(tutorials.indices, id: \.self) { index in
                        TutorialStepView(tutorial: tutorials[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                
                // 底部控制按鈕
                bottomControls
            }
            .navigationTitle("使用教學")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("跳過") {
                        dismiss()
                    }
                    .foregroundColor(.brandGreen)
                }
            }
        }
        .overlay(
            // 完成慶祝動畫
            CompletionCelebrationView(isShowing: $showCompletionCelebration) {
                dismiss()
            }
        )
    }
    
    private var progressIndicator: some View {
        VStack(spacing: DesignTokens.spacingSM) {
            // 步驟指示點
            HStack(spacing: DesignTokens.spacingSM) {
                ForEach(0..<tutorials.count, id: \.self) { index in
                    Circle()
                        .fill(index <= currentStep ? Color.brandGreen : Color(.systemGray4))
                        .frame(width: 8, height: 8)
                        .scaleEffect(index == currentStep ? 1.3 : 1.0)
                        .animation(.easeInOut(duration: 0.3), value: currentStep)
                }
            }
            
            // 進度文字
            Text("\(currentStep + 1) / \(tutorials.count)")
                .font(DesignTokens.caption)
                .foregroundColor(.secondary)
        }
        .padding(DesignTokens.spacingMD)
    }
    
    private var bottomControls: some View {
        HStack {
            // 上一步按鈕
            Button(action: previousStep) {
                HStack(spacing: DesignTokens.spacingXS) {
                    Image(systemName: "chevron.left")
                        .font(.caption)
                    Text("上一步")
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .foregroundColor(.brandGreen)
                .overlay(
                    RoundedRectangle(cornerRadius: DesignTokens.cornerRadius)
                        .stroke(Color.brandGreen, lineWidth: 1)
                )
            }
            .disabled(currentStep == 0)
            .opacity(currentStep == 0 ? 0.5 : 1.0)
            
            Spacer()
            
            // 下一步/完成按鈕
            Button(action: nextStep) {
                HStack(spacing: DesignTokens.spacingXS) {
                    Text(currentStep == tutorials.count - 1 ? "完成教學" : "下一步")
                    if currentStep < tutorials.count - 1 {
                        Image(systemName: "chevron.right")
                            .font(.caption)
                    }
                }
                .padding(.horizontal, DesignTokens.spacingMD)
                .padding(.vertical, DesignTokens.spacingSM)
                .foregroundColor(.white)
                .background(Color.brandGreen)
                .cornerRadius(DesignTokens.cornerRadius)
            }
        }
        .padding(DesignTokens.spacingMD)
        .background(Color(.systemBackground))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color(.separator)),
            alignment: .top
        )
    }
    
    private func previousStep() {
        guard currentStep > 0 else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            currentStep -= 1
        }
        
        // 觸覺反饋
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
    
    private func nextStep() {
        if currentStep < tutorials.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                currentStep += 1
            }
        } else {
            // 完成教學
            showCompletionCelebration = true
            
            // 觸覺反饋
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
        }
        
        // 觸覺反饋
        let impactFeedback = UIImpactFeedbackGenerator(style: .light)
        impactFeedback.impactOccurred()
    }
}

// MARK: - 教學步驟視圖
struct TutorialStepView: View {
    let tutorial: TutorialStep
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.spacingLG) {
                // 圖示和標題
                VStack(spacing: DesignTokens.spacingMD) {
                    Image(systemName: tutorial.icon)
                        .font(.system(size: 60))
                        .foregroundColor(.brandGreen)
                        .padding(DesignTokens.spacingMD)
                        .background(
                            Circle()
                                .fill(Color.brandGreen.opacity(0.1))
                        )
                    
                    Text(tutorial.title)
                        .font(DesignTokens.titleMedium)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                
                // 描述
                Text(tutorial.description)
                    .font(DesignTokens.bodyText)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineSpacing(4)
                
                // 步驟列表
                if !tutorial.steps.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                        Text("操作步驟：")
                            .font(DesignTokens.bodyMedium)
                            .fontWeight(.semibold)
                            .foregroundColor(.primary)
                        
                        ForEach(tutorial.steps.indices, id: \.self) { index in
                            HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
                                Text("\(index + 1)")
                                    .font(DesignTokens.captionBold)
                                    .foregroundColor(.white)
                                    .frame(width: 20, height: 20)
                                    .background(Circle().fill(Color.brandGreen))
                                
                                Text(tutorial.steps[index])
                                    .font(DesignTokens.bodySmall)
                                    .foregroundColor(.primary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(DesignTokens.spacingMD)
                    .background(Color(.secondarySystemGroupedBackground))
                    .cornerRadius(DesignTokens.cornerRadius)
                }
                
                // 提示
                if !tutorial.tips.isEmpty {
                    VStack(alignment: .leading, spacing: DesignTokens.spacingSM) {
                        HStack {
                            Image(systemName: "lightbulb")
                                .foregroundColor(.orange)
                            Text("小提示")
                                .font(DesignTokens.bodyMedium)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                        }
                        
                        ForEach(tutorial.tips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: DesignTokens.spacingSM) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.brandGreen)
                                    .font(.caption)
                                
                                Text(tip)
                                    .font(DesignTokens.bodySmall)
                                    .foregroundColor(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(DesignTokens.spacingMD)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(DesignTokens.cornerRadius)
                }
            }
            .padding(DesignTokens.spacingMD)
        }
    }
}

// MARK: - 完成慶祝視圖
struct CompletionCelebrationView: View {
    @Binding var isShowing: Bool
    let onComplete: () -> Void
    
    @State private var animationScale: CGFloat = 0.1
    @State private var animationOpacity: Double = 0
    
    var body: some View {
        if isShowing {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        dismissCelebration()
                    }
                
                VStack(spacing: DesignTokens.spacingLG) {
                    // 慶祝圖示
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.brandGreen)
                        .scaleEffect(animationScale)
                        .opacity(animationOpacity)
                    
                    // 恭喜文字
                    VStack(spacing: DesignTokens.spacingSM) {
                        Text("🎉 恭喜完成！")
                            .font(DesignTokens.titleMedium)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Text("您已經掌握了股圈的基本使用方法")
                            .font(DesignTokens.bodyText)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    
                    // 開始使用按鈕
                    Button("開始投資學習之旅") {
                        dismissCelebration()
                    }
                    .font(DesignTokens.bodyMedium)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignTokens.spacingLG)
                    .padding(.vertical, DesignTokens.spacingMD)
                    .background(Color.brandGreen)
                    .cornerRadius(DesignTokens.cornerRadiusLG)
                }
                .padding(DesignTokens.spacingLG)
                .background(Color(.systemBackground))
                .cornerRadius(DesignTokens.cornerRadiusLG)
                .shadow(color: Color.black.opacity(0.1), radius: 10, x: 0, y: 5)
                .scaleEffect(animationScale)
                .opacity(animationOpacity)
            }
            .onAppear {
                withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                    animationScale = 1.0
                    animationOpacity = 1.0
                }
            }
        }
    }
    
    private func dismissCelebration() {
        withAnimation(.easeInOut(duration: 0.3)) {
            animationScale = 0.1
            animationOpacity = 0.0
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isShowing = false
            onComplete()
        }
    }
}

// MARK: - 教學數據結構
struct TutorialStep {
    let title: String
    let description: String
    let icon: String
    let steps: [String]
    let tips: [String]
}

// MARK: - 教學數據
struct TutorialData {
    static let allTutorials: [TutorialStep] = [
        TutorialStep(
            title: "歡迎來到股圈",
            description: "股圈是台灣首創的投資知識分享平台，讓您在安全的模擬環境中學習投資，並與專業投資者交流心得。",
            icon: "hand.wave.fill",
            steps: [
                "使用您的 Email 或手機號碼註冊帳號",
                "完成身份驗證流程",
                "設定您的投資偏好和風險承受度",
                "獲得 100 萬虛擬資金開始學習"
            ],
            tips: [
                "註冊完成後會自動獲得虛擬資金",
                "所有交易都是模擬的，不涉及真實金錢"
            ]
        ),
        
        TutorialStep(
            title: "開始模擬投資",
            description: "使用我們提供的虛擬資金進行模擬投資，體驗真實的股票交易流程，學習投資技巧。",
            icon: "chart.line.uptrend.xyaxis",
            steps: [
                "點擊首頁的「投資面板」按鈕",
                "搜尋您想投資的股票",
                "查看股票資訊和技術分析",
                "決定買入數量並下單",
                "追蹤您的投資組合表現"
            ],
            tips: [
                "建議先從知名大型股開始練習",
                "注意設定停損和停利點",
                "定期檢視您的投資組合"
            ]
        ),
        
        TutorialStep(
            title: "參與投資錦標賽",
            description: "加入刺激的投資錦標賽，與其他投資者比拼技巧，贏取豐厚獎勵，提升您的投資實力。",
            icon: "trophy.fill",
            steps: [
                "瀏覽「錦標賽」頁面查看進行中的比賽",
                "選擇適合的錦標賽報名參加",
                "使用錦標賽專用資金進行投資",
                "密切關注排行榜和自己的表現",
                "比賽結束後查看成績和獲得獎勵"
            ],
            tips: [
                "新手建議先參加新手友善的錦標賽",
                "不同錦標賽有不同的規則和期間",
                "表現優秀可獲得徽章和專家認證"
            ]
        ),
        
        TutorialStep(
            title: "關注投資專家",
            description: "發現並關注優秀的投資專家，學習他們的投資策略，閱讀深度分析文章。",
            icon: "person.2.fill",
            steps: [
                "瀏覽「專家推薦」或「排行榜」",
                "查看專家的投資績效和文章",
                "點擊「關注」按鈕追蹤專家動態",
                "閱讀專家發布的投資分析",
                "參與文章討論和互動"
            ],
            tips: [
                "關注多位不同風格的專家",
                "注意查看專家的歷史績效",
                "積極參與討論可以學到更多"
            ]
        ),
        
        TutorialStep(
            title: "錢包與付費內容",
            description: "了解平台的代幣系統，學習如何購買付費內容，支持優質創作者。",
            icon: "creditcard.fill",
            steps: [
                "進入「錢包」頁面查看餘額",
                "根據需要購買平台代幣",
                "使用代幣訂閱專家內容",
                "購買付費文章和專家諮詢",
                "查看消費記錄和管理訂閱"
            ],
            tips: [
                "代幣可用於多種付費服務",
                "訂閱專家可享受更多優質內容",
                "支持創作者有助於平台生態發展"
            ]
        ),
        
        TutorialStep(
            title: "成為內容創作者",
            description: "如果您有投資經驗和見解，可以申請成為創作者，分享知識並獲得收益。",
            icon: "pencil.and.outline",
            steps: [
                "累積一定的投資經驗和績效",
                "在「設定」中申請創作者資格",
                "通過平台的創作能力評估",
                "開始發布投資分析文章",
                "透過付費內容獲得收益"
            ],
            tips: [
                "創作者收益分潤高達70%",
                "優質內容會獲得平台推薦",
                "建立個人品牌提升影響力"
            ]
        )
    ]
}

#Preview {
    TutorialView()
}