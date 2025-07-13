import SwiftUI

struct FullScreenQRCodeView: View {
    @Environment(\.dismiss) var dismiss
    let qrCodeImage: UIImage
    let userId: String
    
    var body: some View {
        VStack(spacing: DesignTokens.spacingLG) {
            Text("用戶 ID: \(userId)")
                .font(.titleLarge)
                .fontWeight(.bold)
            
            Image(uiImage: qrCodeImage)
                .resizable()
                .interpolation(.none)
                .scaledToFit()
                .padding()
            
            Button("關閉") {
                dismiss()
            }
            .brandButtonStyle(backgroundColor: .brandOrange)
        }
        .padding(DesignTokens.spacingXL)
    }
}

struct FullScreenQRCodeView_Previews: PreviewProvider {
    static var previews: some View {
        // 創建一個假的 QR Code 圖像用於預覽
        let fakeImage = UIImage(systemName: "qrcode") ?? UIImage()
        FullScreenQRCodeView(qrCodeImage: fakeImage, userId: "USER_12345678")
    }
} 