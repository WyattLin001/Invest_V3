//
//  EnhancedSettingsView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/9.
//

import SwiftUI

struct EnhancedSettingsView: View {
    @AppStorage("isDarkMode") private var isDarkMode = false
    @AppStorage("language") private var selectedLanguage = "繁體中文"
    @AppStorage("investmentNotifications") private var investmentNotifications = true
    @AppStorage("chatNotifications") private var chatNotifications = true
    @AppStorage("rankingNotifications") private var rankingNotifications = false
    
    @State private var showingKYCSheet = false
    @State private var showingQRCode = false
    @State private var userProfile = UserProfile.sample
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Profile Section
                    VStack(spacing: 16) {
                        // Avatar and Basic Info
                        HStack(spacing: 16) {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 80, height: 80)
                                .overlay(
                                    Text(String(userProfile.name.prefix(1)))
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(.white)
                                )
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(userProfile.name)
                                    .font(.title2)
                                    .fontWeight(.bold)
                                
                                Text("ID: \(userProfile.userID)")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Button("編輯個人資料") {
                                    // Edit profile
                                }
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Color.blue.opacity(0.1))
                                .foregroundColor(.blue)
                                .cornerRadius(12)
                            }
                            
                            Spacer()
                            
                            Button {
                                showingQRCode = true
                            } label: {
                                Image(systemName: "qrcode")
                                    .font(.title2)
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Notification Settings
                    VStack(alignment: .leading, spacing: 0) {
                        Text("通知設定")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        
                        VStack(spacing: 0) {
                            NotificationSettingRow(
                                icon: "chart.line.uptrend.xyaxis",
                                title: "投資提醒",
                                subtitle: "排名變化、重要市場動態",
                                isOn: $investmentNotifications
                            )
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            NotificationSettingRow(
                                icon: "message",
                                title: "聊天訊息",
                                subtitle: "群組和私人訊息通知",
                                isOn: $chatNotifications
                            )
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            NotificationSettingRow(
                                icon: "trophy",
                                title: "排行榜更新",
                                subtitle: "每週排名結果通知",
                                isOn: $rankingNotifications
                            )
                        }
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // App Settings
                    VStack(alignment: .leading, spacing: 0) {
                        Text("應用設定")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                            .padding(.bottom, 16)
                        
                        VStack(spacing: 0) {
                            AppSettingRow(
                                icon: "moon",
                                title: "深色模式",
                                subtitle: "切換至深色主題",
                                isToggle: true,
                                isOn: $isDarkMode
                            )
                            
                            Divider()
                                .padding(.leading, 60)
                            
                            AppSettingRow(
                                icon: "globe",
                                title: "語言",
                                subtitle: selectedLanguage,
                                value: selectedLanguage
                            ) {
                                // Language selection
                            }
                        }
                    }
                    .padding(.vertical)
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // KYC Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("KYC 身份驗證")
                            .font(.headline)
                            .fontWeight(.bold)
                            .padding(.horizontal)
                        
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("身份驗證狀態")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                
                                HStack(spacing: 8) {
                                    Circle()
                                        .fill(userProfile.isKYCVerified ? .green : .orange)
                                        .frame(width: 8, height: 8)
                                    
                                    Text(userProfile.isKYCVerified ? "已驗證" : "待驗證")
                                        .font(.caption)
                                        .foregroundColor(userProfile.isKYCVerified ? .green : .orange)
                                }
                            }
                            
                            Spacer()
                            
                            Button(userProfile.isKYCVerified ? "已完成" : "立即驗證") {
                                if !userProfile.isKYCVerified {
                                    showingKYCSheet = true
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(userProfile.isKYCVerified ? Color.gray : Color(hex: "#FD7E14"))
                            .foregroundColor(.white)
                            .cornerRadius(20)
                            .disabled(userProfile.isKYCVerified)
                        }
                        .padding()
                    }
                    .background(Color(.systemBackground))
                    .cornerRadius(16)
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 4)
                    
                    // Additional Options
                    VStack(spacing: 12) {
                        SettingsActionButton(
                            icon: "questionmark.circle",
                            title: "幫助與支援",
                            color: .blue
                        ) {
                            // Help action
                        }
                        
                        SettingsActionButton(
                            icon: "doc.text",
                            title: "服務條款",
                            color: .blue
                        ) {
                            // Terms action
                        }
                        
                        SettingsActionButton(
                            icon: "hand.raised",
                            title: "隱私政策",
                            color: .blue
                        ) {
                            // Privacy action
                        }
                        
                        SettingsActionButton(
                            icon: "arrow.right.square",
                            title: "登出",
                            color: .red
                        ) {
                            // Logout action
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("設定")
            .navigationBarTitleDisplayMode(.large)
            .sheet(isPresented: $showingKYCSheet) {
                KYCVerificationSheet()
            }
            .sheet(isPresented: $showingQRCode) {
                QRCodeSheet(userProfile: userProfile)
            }
        }
        .preferredColorScheme(isDarkMode ? .dark : .light)
    }
}

struct NotificationSettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.blue)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(Color(hex: "#00B900"))
        }
        .padding()
    }
}

struct AppSettingRow: View {
    let icon: String
    let title: String
    let subtitle: String
    var isToggle: Bool = false
    @Binding var isOn: Binding<Bool>?
    var value: String?
    var action: (() -> Void)?
    
    init(icon: String, title: String, subtitle: String, isToggle: Bool = false, isOn: Binding<Bool>? = nil, value: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.isToggle = isToggle
        self._isOn = isOn ?? .constant(false)
        self.value = value
        self.action = action
    }
    
    var body: some View {
        Button(action: action ?? {}) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.blue)
                    .frame(width: 24, height: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isToggle, let isOnBinding = isOn {
                    Toggle("", isOn: isOnBinding)
                        .tint(Color(hex: "#00B900"))
                } else if let value = value {
                    Text(value)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 24, height: 24)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
        }
    }
}

struct KYCVerificationSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var fullName = ""
    @State private var idNumber = ""
    @State private var phoneNumber = ""
    @State private var address = ""
    
    var body: some View {
        NavigationView {
            Form {
                Section("個人資料") {
                    TextField("真實姓名", text: $fullName)
                    TextField("身份證字號", text: $idNumber)
                    TextField("手機號碼", text: $phoneNumber)
                    TextField("地址", text: $address)
                }
                
                Section("身份驗證文件") {
                    Button("上傳身份證正面") {
                        // Upload ID front
                    }
                    
                    Button("上傳身份證背面") {
                        // Upload ID back
                    }
                }
                
                Section {
                    Button("提交驗證") {
                        // Submit KYC
                        dismiss()
                    }
                    .disabled(fullName.isEmpty || idNumber.isEmpty)
                }
            }
            .navigationTitle("身份驗證")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("取消") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct QRCodeSheet: View {
    let userProfile: UserProfile
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                Text("我的 QR Code")
                    .font(.headline)
                    .fontWeight(.bold)
                
                // QR Code placeholder
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(.systemGray6))
                    .frame(width: 200, height: 200)
                    .overlay(
                        VStack(spacing: 8) {
                            Image(systemName: "qrcode")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("QR Code")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    )
                
                VStack(spacing: 8) {
                    Text(userProfile.name)
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("ID: \(userProfile.userID)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Text("掃描此 QR Code 加為好友")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Button("分享 QR Code") {
                    // Share QR code
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 12)
                .background(Color(hex: "#00B900"))
                .cornerRadius(20)
                
                Spacer()
            }
            .padding()
            .navigationTitle("QR Code")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Supporting Models
struct UserProfile {
    let id: UUID
    let name: String
    let userID: String
    let email: String
    let isKYCVerified: Bool
    
    static let sample = UserProfile(
        id: UUID(),
        name: "投資新手",
        userID: "INV001234",
        email: "investor@example.com",
        isKYCVerified: false
    )
}

#Preview {
    EnhancedSettingsView()
}