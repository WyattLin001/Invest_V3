//
//  AuthenticationView.swift
//  Invest_V2
//
//  Created by 林家麒 on 2025/7/9.
//
import SwiftUI

struct AuthenticationView: View {
    @EnvironmentObject var authService: AuthenticationService
    @State private var isSignUp = false
    @State private var username = ""
    @State private var email = ""
    @State private var password = "" // 新增密碼狀態
    @State private var displayName = ""
    @State private var showError = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Logo 區域
                VStack(spacing: 16) {
                    Circle()
                        .fill(Color.investGreen)
                        .frame(width: 100, height: 100)
                        .overlay(
                            Text("投")
                                .font(.system(size: 40, weight: .bold))
                                .foregroundColor(.white)
                        )
                    
                    Text("Invest V3")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.black)
                    
                    Text("社交投資競賽平台")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 50)
                
                // 輸入區域
                VStack(spacing: 20) {
                    // Email 輸入
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                        
                        TextField("Email", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .frame(width: 343, height: 40)
                    }
                    
                    // 密碼或用戶名輸入
                    if isSignUp {
                        // 註冊時，顯示用戶名
                        VStack(alignment: .leading, spacing: 8) {
                            Text("用戶名")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            TextField("請輸入用戶名", text: $username)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                        }
                    }
                    
                    // 通用密碼欄位
                    VStack(alignment: .leading, spacing: 8) {
                        Text("密碼")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.black)
                        
                        SecureField("密碼", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .frame(width: 343, height: 40)
                    }
                    
                    // 暱稱輸入（僅註冊時顯示）
                    if isSignUp {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("暱稱")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.black)
                            
                            TextField("請輸入暱稱", text: $displayName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                    }
                }
                .padding(.horizontal, 30)
                
                // 按鈕區域
                VStack(spacing: 16) {
                    // 主要按鈕
                    Button(action: {
                        Task {
                            await handleAuthentication()
                        }
                    }) {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(.circular)
                            .tint(.white)
                        } else {
                            Text(isSignUp ? "註冊" : "登入")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.investGreen)
                    .cornerRadius(25)
                    .disabled(authService.isLoading || email.isEmpty || password.isEmpty || (isSignUp && (username.isEmpty || displayName.isEmpty)))
                    
                    // 切換按鈕
                    Button(action: {
                        isSignUp.toggle()
                        displayName = ""
                    }) {
                        Text(isSignUp ? "已有帳號？登入" : "沒有帳號？註冊")
                            .font(.system(size: 14))
                            .foregroundColor(.investGreen)
                    }
                }
                .padding(.horizontal, 30)
                
                Spacer()
            }
            .background(Color.investBackground)
            .navigationBarHidden(true)
            .alert("錯誤", isPresented: $showError) {
                Button("確定", role: .cancel) {}
            } message: {
                Text(authService.error ?? "未知錯誤")
            }
            .onChange(of: authService.error) { error in
                showError = error != nil
            }
        }
    }
    
    @MainActor
    private func handleAuthentication() async {
        do {
            if isSignUp {
                try await authService.registerUser(email: email, password: password, username: username, displayName: displayName)
            } else {
                try await authService.signIn(email: email, password: password)
            }
        } catch {
            // 錯誤處理已在 AuthenticationService 中完成
        }
    }
}

#Preview {
    AuthenticationView()
        .environmentObject(AuthenticationService())
}
