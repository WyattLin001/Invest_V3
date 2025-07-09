import SwiftUI

struct NotificationView: View {
    @StateObject private var viewModel = NotificationViewModel()
    @Environment(\.dismiss) private var dismiss
    
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
                                    viewModel.markAsRead(notification.id)
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
        .onAppear {
            Task {
                await viewModel.loadNotifications()
            }
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
                        .fill(Color(hex: notification.type.color))
                        .frame(width: 44, height: 44)
                    
                    Image(systemName: notification.type.iconName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
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
                id: UUID(),
                title: "群組邀請",
                message: "投資大師Tom 邀請您加入「科技股挑戰賽」",
                type: .groupInvite,
                isRead: false,
                createdAt: Date().addingTimeInterval(-300) // 5分鐘前
            ),
            AppNotification(
                id: UUID(),
                title: "排名更新",
                message: "恭喜！您在本週排行榜中上升了3個名次",
                type: .rankingUpdate,
                isRead: false,
                createdAt: Date().addingTimeInterval(-3600) // 1小時前
            ),
            AppNotification(
                id: UUID(),
                title: "交易提醒",
                message: "台積電(2330)達到您設定的目標價格 NT$580",
                type: .tradingAlert,
                isRead: true,
                createdAt: Date().addingTimeInterval(-7200) // 2小時前
            )
        ]
        
        isLoading = false
    }
    
    func markAsRead(_ notificationId: UUID) {
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

#Preview {
    NotificationView()
} 