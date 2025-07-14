import SwiftUI

struct TopicsEditView: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var draft: ArticleDraft
    
    private let topics = ["投資分析", "市場動態", "技術分析", "基本面分析", "風險管理", "投資心得", "新手教學", "其他"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("分類") {
                    ForEach(topics, id: \.self) { topic in
                        HStack {
                            Text(topic)
                            Spacer()
                            if draft.category == topic {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            draft.category = topic
                        }
                    }
                }
                
                Section("內容設定") {
                    HStack {
                        Text("文章類型")
                        Spacer()
                        Picker("文章類型", selection: $draft.isFree) {
                            Text("免費").tag(true)
                            Text("付費").tag(false)
                        }
                        .pickerStyle(.segmented)
                        .frame(width: 120)
                    }
                }
                
                if !draft.isFree {
                    Section {
                        HStack {
                            Image(systemName: "info.circle")
                                .foregroundColor(.blue)
                            Text("付費文章將需要讀者訂閱才能閱讀完整內容")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("編輯主題")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

#Preview {
    TopicsEditView(draft: .constant(ArticleDraft()))
} 