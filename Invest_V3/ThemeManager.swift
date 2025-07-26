//
//  ThemeManager.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/25.
//  統一主題管理器 - 支援系統自動、淺色、深色三種模式

import SwiftUI
import UIKit

/// 主題管理器 - 統一管理應用程式的深色模式設定
@MainActor
class ThemeManager: ObservableObject {
    
    /// 主題模式選項
    enum ThemeMode: String, CaseIterable, Identifiable {
        case system = "system"
        case light = "light"
        case dark = "dark"
        
        var id: String { rawValue }
        
        /// 顯示名稱
        var displayName: String {
            switch self {
            case .system:
                return "跟隨系統"
            case .light:
                return "淺色模式"
            case .dark:
                return "深色模式"
            }
        }
        
        /// 圖示名稱
        var iconName: String {
            switch self {
            case .system:
                return "gear"
            case .light:
                return "sun.max"
            case .dark:
                return "moon"
            }
        }
        
        /// 對應的 UIUserInterfaceStyle
        var uiStyle: UIUserInterfaceStyle {
            switch self {
            case .system:
                return .unspecified
            case .light:
                return .light
            case .dark:
                return .dark
            }
        }
    }
    
    // MARK: - 單例模式
    static let shared = ThemeManager()
    
    // MARK: - 發布的屬性
    @Published var currentMode: ThemeMode {
        didSet {
            saveThemePreference()
            applyTheme()
        }
    }
    
    @Published var isDarkMode: Bool = false
    
    // MARK: - 私有屬性
    private let userDefaults = UserDefaults.standard
    private let themeKey = "user_theme_preference"
    
    // MARK: - 初始化
    private init() {
        // 從 UserDefaults 載入主題偏好
        let savedTheme = userDefaults.string(forKey: themeKey) ?? ThemeMode.system.rawValue
        self.currentMode = ThemeMode(rawValue: savedTheme) ?? .system
        
        // 監聽系統主題變化
        setupSystemThemeObserver()
        
        // 應用初始主題
        applyTheme()
        updateDarkModeStatus()
        
        print("🎨 [ThemeManager] 初始化完成，當前主題: \(currentMode.displayName)")
    }
    
    // MARK: - 公開方法
    
    /// 設定主題模式
    func setTheme(_ mode: ThemeMode) {
        print("🎨 [ThemeManager] 切換主題: \(currentMode.displayName) -> \(mode.displayName)")
        
        withAnimation(.easeInOut(duration: 0.3)) {
            currentMode = mode
        }
    }
    
    /// 獲取當前實際的顏色方案
    func getCurrentColorScheme() -> ColorScheme? {
        switch currentMode {
        case .system:
            return nil // 讓系統決定
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }
    
    /// 檢查當前是否為深色模式
    func isCurrentlyDark() -> Bool {
        switch currentMode {
        case .system:
            return UITraitCollection.current.userInterfaceStyle == .dark
        case .light:
            return false
        case .dark:
            return true
        }
    }
    
    // MARK: - 私有方法
    
    /// 應用主題到應用程式
    private func applyTheme() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            print("❌ [ThemeManager] 無法獲取主視窗")
            return
        }
        
        // 設定視窗的外觀模式
        window.overrideUserInterfaceStyle = currentMode.uiStyle
        
        // 更新深色模式狀態
        updateDarkModeStatus()
        
        print("✅ [ThemeManager] 已應用主題: \(currentMode.displayName)")
    }
    
    /// 更新深色模式狀態
    private func updateDarkModeStatus() {
        let wasDark = isDarkMode
        isDarkMode = isCurrentlyDark()
        
        if wasDark != isDarkMode {
            print("🌗 [ThemeManager] 深色模式狀態變更: \(wasDark) -> \(isDarkMode)")
        }
    }
    
    /// 保存主題偏好到 UserDefaults
    private func saveThemePreference() {
        userDefaults.set(currentMode.rawValue, forKey: themeKey)
        print("💾 [ThemeManager] 已保存主題偏好: \(currentMode.rawValue)")
    }
    
    /// 設定系統主題變化監聽器
    private func setupSystemThemeObserver() {
        NotificationCenter.default.addObserver(
            forName: UIApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateDarkModeStatus()
        }
        
        // 監聽系統外觀變化
        NotificationCenter.default.addObserver(
            forName: Notification.Name("UIApplicationDidChangeUserInterfaceStyleNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            if self?.currentMode == .system {
                self?.updateDarkModeStatus()
            }
        }
    }
}

// MARK: - SwiftUI 集成

/// 主題環境鍵
struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeManager = ThemeManager.shared
}

extension EnvironmentValues {
    var themeManager: ThemeManager {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - View 擴展

extension View {
    /// 注入主題管理器到環境
    func withThemeManager() -> some View {
        self.environmentObject(ThemeManager.shared)
    }
    
    /// 應用主題敏感的修飾器
    func themeAdaptive<Content: View>(
        @ViewBuilder content: @escaping (Bool) -> Content
    ) -> some View {
        self.modifier(ThemeAdaptiveModifier(contentBuilder: content))
    }
}

/// 主題自適應修飾器
struct ThemeAdaptiveModifier<Content: View>: ViewModifier {
    @EnvironmentObject private var themeManager: ThemeManager
    let contentBuilder: (Bool) -> Content
    
    func body(content: Content) -> some View {
        contentBuilder(themeManager.isDarkMode)
    }
}

// MARK: - 主題切換動畫支援

extension ThemeManager {
    /// 帶動畫的主題切換
    func setThemeWithAnimation(
        _ mode: ThemeMode,
        animation: Animation = .easeInOut(duration: 0.3)
    ) {
        withAnimation(animation) {
            setTheme(mode)
        }
    }
}

// MARK: - 調試輔助

#if DEBUG
extension ThemeManager {
    /// 獲取當前主題狀態的調試信息
    func getDebugInfo() -> String {
        let systemStyle = UITraitCollection.current.userInterfaceStyle
        return """
        主題管理器狀態:
        - 用戶設置: \(currentMode.displayName)
        - 系統模式: \(systemStyle == .dark ? "深色" : "淺色")
        - 當前實際: \(isDarkMode ? "深色" : "淺色")
        - UI Style: \(currentMode.uiStyle.rawValue)
        """
    }
}
#endif