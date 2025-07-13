import SwiftUI

// MARK: - Toast View
struct ToastView: View {
    let message: String
    @Binding var isShowing: Bool
    
    var body: some View {
        VStack {
            Spacer()
            HStack {
                Text(message)
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 24)
                    .background(Color.green.opacity(0.8))
                    .cornerRadius(28)
                    .shadow(radius: 10)
            }
            .padding(.bottom, 50)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.01)) // Make it tappable
        .edgesIgnoringSafeArea(.all)
        .opacity(isShowing ? 1 : 0)
        .onTapGesture {
            withAnimation {
                isShowing = false
            }
        }
        .onAppear {
            // Automatically dismiss after 2 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    self.isShowing = false
                }
            }
        }
    }
}

// MARK: - View Extension for Toast
extension View {
    func toast(message: String, isShowing: Binding<Bool>) -> some View {
        self.overlay(
            ToastView(message: message, isShowing: isShowing)
        )
    }
} 