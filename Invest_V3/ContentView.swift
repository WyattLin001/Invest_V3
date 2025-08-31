import SwiftUI
import UIKit

struct ContentView: View {
    @State private var selectedTab = 0  // 預設選中首頁 (0)
    @State private var selectedGroupId: UUID?
    @EnvironmentObject var authService: AuthenticationService
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // 首頁 - 投資分析和市場資訊
            HomeView()
                .tabItem {
                    Image(systemName: selectedTab == 0 ? "house.fill" : "house")
                    Text("首頁")
                }
                .tag(0)
            
            // 聊天 - 投資群組討論
            ChatView(preselectedGroupId: selectedGroupId)
                .tabItem {
                    Image(systemName: selectedTab == 1 ? "message.fill" : "message")
                    Text("聊天")
                }
                .tag(1)
            
            // 資訊 - 文章和新聞
            InfoView()
                .tabItem {
                    Image(systemName: selectedTab == 2 ? "newspaper.fill" : "newspaper")
                    Text("資訊")
                }
                .tag(2)
            
            // 錢包 - 資產管理
            WalletView()
                .tabItem {
                    Image(systemName: selectedTab == 3 ? "creditcard.fill" : "creditcard")
                    Text("錢包")
                }
                .tag(3)
            
            // 收益 - 創作者收益儀表板
            AuthorEarningsView()
                .tabItem {
                    Image(systemName: selectedTab == 4 ? "dollarsign.circle.fill" : "dollarsign.circle")
                    Text("收益")
                }
                .tag(4)
            
            // 設定 - 個人設定和帳戶管理
            SettingsView()
                .tabItem {
                    Image(systemName: selectedTab == 5 ? "gearshape.fill" : "gearshape")
                    Text("設定")
                }
                .tag(5)
        }
        .accentColor(.mediumButtonPrimary)
        .onAppear {
            // 配置 TabBar 外觀 - 改善深色模式適配
            let appearance = UITabBarAppearance()
            appearance.configureWithOpaqueBackground()
            appearance.backgroundColor = UIColor.systemBackground
            
            // 深色模式下增加分隔線
            appearance.shadowColor = UIColor.separator
            
            // 設定選中狀態 - 使用 Medium 主題色
            appearance.stackedLayoutAppearance.selected.iconColor = UIColor(Color.mediumButtonPrimary)
            appearance.stackedLayoutAppearance.selected.titleTextAttributes = [
                .foregroundColor: UIColor(Color.mediumButtonPrimary),
                .font: UIFont.systemFont(ofSize: 10, weight: .medium)
            ]
            
            // 設定未選中狀態 - Medium 風格灰色
            let normalColor = UIColor(Color.mediumTextSecondary)
            
            appearance.stackedLayoutAppearance.normal.iconColor = normalColor
            appearance.stackedLayoutAppearance.normal.titleTextAttributes = [
                .foregroundColor: normalColor,
                .font: UIFont.systemFont(ofSize: 10, weight: .regular)
            ]
            
            UITabBar.appearance().standardAppearance = appearance
            UITabBar.appearance().scrollEdgeAppearance = appearance
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToChatTab"))) { notification in
            // 切換到聊天 Tab
            selectedTab = 1
            
            // 如果有群組 ID，設定選中的群組
            if let groupId = notification.object as? UUID {
                selectedGroupId = groupId
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("ShowWalletForTopUp"))) { _ in
            // 切換到錢包 Tab 進行充值
            selectedTab = 3
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("SwitchToHomeTab"))) { _ in
            // 切換到首頁 Tab (通常在登出後使用)
            selectedTab = 0
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthenticationService.shared)
}

