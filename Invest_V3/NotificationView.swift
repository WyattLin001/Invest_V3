import SwiftUI

struct NotificationView: View {
    @StateObject private var viewModel = NotificationViewModel()
    @Environment(\.dismiss) private var dismiss
    @State private var showGroupInvite = false
    @State private var showTradingDetail = false
    @State private var showRankingDetail = false
    @State private var selectedNotification: AppNotification?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // 頂部導航欄
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.title2)
                            .foregroundColor(.gray600)
                    }
                    .accessibilityLabel("關閉通知頁面")
                    .accessibilityHint("點擊關閉通知頁面並返回上一頁")
                    
                    Spacer()
                    
                    Text("通知")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.gray900)
                    
                    Spacer()
                    
                    Button(action: { viewModel.markAllAsRead() }) {
                        Text("全部已讀")
                            .font(.footnote)
                            .foregroundColor(.brandGreen)
                    }
                    .opacity(viewModel.hasUnreadNotifications ? 1 : 0)
                    .accessibilityLabel("標記所有通知為已讀")
                    .accessibilityHint("點擊將所有未讀通知標記為已讀狀態")
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color.white)
                .overlay(
                    Rectangle()
                        .frame(height: 1)
                        .foregroundColor(.gray300),
                    alignment: .bottom
                )
                
                // 通知內容
                if viewModel.isLoading {
                    Spacer()
                    ProgressView()
                        .scaleEffect(1.5)
                    Spacer()
                } else if viewModel.notifications.isEmpty {
                    // 空狀態
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "bell.slash")
                            .font(.system(size: 60))
                            .foregroundColor(.gray400)
                        
                        Text("目前沒有通知")
                            .font(.title3)
                            .fontWeight(.medium)
                            .foregroundColor(.gray600)
                        
                        Text("當有新的群組邀請、交易提醒或排名更新時，會在這裡顯示")
                            .font(.body)
                            .foregroundColor(.gray500)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                    Spacer()
                } else {
                    // 通知列表
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(viewModel.notifications) { notification in
                                NotificationRowView(notification: notification) {
                                    handleNotificationTap(notification)
                                }
                                
                                if notification.id != viewModel.notifications.last?.id {
                                    Divider()
                                        .padding(.leading, 60)
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .background(Color.gray100)
        }
        .sheet(isPresented: $showGroupInvite) {
            if let notification = selectedNotification {
                GroupInviteDetailView(notification: notification)
            }
        }
        .sheet(isPresented: $showTradingDetail) {
            if let notification = selectedNotification {
                TradingAlertDetailView(notification: notification)
            }
        }
        .sheet(isPresented: $showRankingDetail) {
            if let notification = selectedNotification {
                RankingUpdateDetailView(notification: notification)
            }
        }
        .onAppear {
            Task {
                await viewModel.loadNotifications()
            }
        }
    }
    
    // MARK: - Navigation Handler
    private func handleNotificationTap(_ notification: AppNotification) {
        // 標記為已讀
        viewModel.markAsRead(notification.id)
        
        // 設定選中的通知
        selectedNotification = notification
        
        // 根據通知類型跳轉到相應頁面
        switch notification.type {
        case .groupInvite:
            showGroupInvite = true
        case .tradingAlert:
            showTradingDetail = true
        case .rankingUpdate:
            showRankingDetail = true
        case .systemAlert:
            // 系統訊息通常只需要顯示，不需要特殊跳轉
            break
        case .hostMessage, .chatMessage, .investmentUpdate, .marketNews, .stockPriceAlert:
            // 其他類型可以之後實現
            break
        }
    }
}

// MARK: - 通知行視圖
struct NotificationRowView: View {
    let notification: AppNotification
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // 通知圖標
                ZStack {
                    Circle()
                        .fill(Color.blue) // 暫時使用固定顏色
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: notification.type.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                .accessibilityLabel("\(notification.type.rawValue)通知圖標")
                
                // 通知內容
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.subheadline)
                            .fontWeight(notification.isRead ? .medium : .semibold)
                            .foregroundColor(.gray900)
                            .lineLimit(1)
                        
                        Spacer()
                        
                        Text(timeAgoString(from: notification.createdAt))
                            .font(.caption)
                            .foregroundColor(.gray500)
                    }
                    
                    Text(notification.message)
                        .font(.caption)
                        .foregroundColor(.gray600)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
                
                // 未讀指示器
                if !notification.isRead {
                    Circle()
                        .fill(Color.brandGreen)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(notification.isRead ? Color.clear : Color.brandGreen.opacity(0.05))
        }
        .buttonStyle(PlainButtonStyle())
        .accessibilityLabel("\(notification.title), \(notification.message)")
        .accessibilityHint(notification.isRead ? "已讀通知，點擊查看詳細內容" : "未讀通知，點擊查看詳細內容並標記為已讀")
        .accessibilityValue(notification.isRead ? "已讀" : "未讀")
    }
    
    private func timeAgoString(from date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        
        if interval < 60 {
            return "剛剛"
        } else if interval < 3600 {
            return "\(Int(interval / 60))分鐘前"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))小時前"
        } else {
            return "\(Int(interval / 86400))天前"
        }
    }
}

// MARK: - 通知 ViewModel
@MainActor
class NotificationViewModel: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var isLoading = false
    
    var hasUnreadNotifications: Bool {
        notifications.contains { !$0.isRead }
    }
    
    func loadNotifications() async {
        isLoading = true
        
        // 模擬網路延遲
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // 模擬通知數據 - 實際應該從 Supabase 獲取
        self.notifications = [
            AppNotification(
                id: UUID().uuidString,
                title: "群組邀請",
                message: "投資大師Tom 邀請您加入「科技股挑戰賽」",
                type: .groupInvite,
                isRead: false,
                createdAt: Date().addingTimeInterval(-300) // 5分鐘前
            ),
            AppNotification(
                id: UUID().uuidString,
                title: "排名更新",
                message: "恭喜！您在本週排行榜中上升了3個名次",
                type: .rankingUpdate,
                isRead: false,
                createdAt: Date().addingTimeInterval(-3600) // 1小時前
            ),
            AppNotification(
                id: UUID().uuidString,
                title: "交易提醒",
                message: "台積電(2330)達到您設定的目標價格 NT$580",
                type: .tradingAlert,
                isRead: true,
                createdAt: Date().addingTimeInterval(-7200) // 2小時前
            )
        ]
        
        isLoading = false
    }
    
    func markAsRead(_ notificationId: String) {
        if let index = notifications.firstIndex(where: { $0.id == notificationId }) {
            notifications[index] = AppNotification(
                id: notifications[index].id,
                title: notifications[index].title,
                message: notifications[index].message,
                type: notifications[index].type,
                isRead: true,
                createdAt: notifications[index].createdAt
            )
        }
    }
    
    func markAllAsRead() {
        notifications = notifications.map { notification in
            AppNotification(
                id: notification.id,
                title: notification.title,
                message: notification.message,
                type: notification.type,
                isRead: true,
                createdAt: notification.createdAt
            )
        }
    }
}

// MARK: - Detail Views for Notifications

struct GroupInviteDetailView: View {
    let notification: AppNotification
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 群組邀請詳情
                VStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.brandGreen)
                    
                    Text("群組邀請")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(notification.message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // 操作按鈕
                VStack(spacing: 12) {
                    Button("接受邀請") {
                        // 處理接受邀請邏輯
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandGreen)
                    .accessibilityLabel("接受群組邀請")
                    .accessibilityHint("點擊接受邀請並加入群組")
                    
                    Button("拒絕") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("拒絕群組邀請")
                    .accessibilityHint("點擊拒絕邀請並關閉此頁面")
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("群組邀請")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct TradingAlertDetailView: View {
    let notification: AppNotification
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 交易提醒詳情
                VStack(spacing: 16) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.system(size: 60))
                        .foregroundColor(.brandOrange)
                    
                    Text("交易提醒")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(notification.message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // 操作按鈕
                VStack(spacing: 12) {
                    Button("查看詳細資訊") {
                        // 跳轉到股票詳情頁面
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.brandOrange)
                    .accessibilityLabel("查看股票詳細資訊")
                    .accessibilityHint("點擊查看相關股票的詳細資訊和價格走勢")
                    
                    Button("設定新提醒") {
                        // 打開提醒設定
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("設定新的價格提醒")
                    .accessibilityHint("點擊為此股票設定新的價格提醒條件")
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("交易提醒")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct RankingUpdateDetailView: View {
    let notification: AppNotification
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // 排名更新詳情
                VStack(spacing: 16) {
                    Image(systemName: "trophy.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.yellow)
                    
                    Text("排名更新")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text(notification.message)
                        .font(.body)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                // 操作按鈕
                VStack(spacing: 12) {
                    Button("查看完整排行榜") {
                        // 跳轉到排行榜頁面
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.yellow)
                    .accessibilityLabel("查看完整投資排行榜")
                    .accessibilityHint("點擊查看所有投資者的完整排名列表")
                    
                    Button("查看我的表現") {
                        // 跳轉到個人表現頁面
                        dismiss()
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("查看個人投資表現")
                    .accessibilityHint("點擊查看自己的詳細投資表現和統計數據")
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("排名更新")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    NotificationView()
} 