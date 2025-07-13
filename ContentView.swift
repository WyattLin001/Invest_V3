import SwiftUI

struct ContentView: View {
    @State private var showEditor = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Invest V3")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("台灣去中心化模擬投資競賽平台")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                Button("測試富文本編輯器") {
                    showEditor = true
                }
                .buttonStyle(.borderedProminent)
                .font(.headline)
                
                Spacer()
            }
            .padding()
            .navigationTitle("主頁")
        }
        .sheet(isPresented: $showEditor) {
            NativeRichTextEditor()
        }
    }
}

#Preview {
    ContentView()
}

