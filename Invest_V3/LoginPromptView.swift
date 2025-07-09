import SwiftUI

/// 一個可重複使用的視圖，用於在用戶需要登入才能訪問某個功能時顯示提示。
struct LoginPromptView: View {
    /// 一個閉包，當使用者點擊登入按鈕時被呼叫。
    /// 父視圖應處理呈現登入畫面的邏輯。
    var onLogin: () -> Void
    var title: String
    var message: String
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 60))
                .foregroundColor(.gray400)
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.gray900)
                
                Text(message)
                    .font(.body)
                    .foregroundColor(.gray600)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Button(action: onLogin) {
                Text("登入 / 註冊")
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.brandGreen)
                    .cornerRadius(12)
            }
            .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.gray100)
    }
}

#Preview {
    LoginPromptView(
        onLogin: { print("Login button tapped") },
        title: "需要登入",
        message: "登入後即可開始與群組成員聊天、下單，並查看您的投資組合。"
    )
} 