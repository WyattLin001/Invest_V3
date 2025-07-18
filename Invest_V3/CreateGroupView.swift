import SwiftUI
import PhotosUI

struct CreateGroupView: View {
    @StateObject private var viewModel = CreateGroupViewModel()
    @Environment(\.presentationMode) var presentationMode
    @State private var showingImagePicker = false
    @State private var selectedPhoto: PhotosPickerItem?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // 群組頭像選擇區域
                    groupAvatarSection
                    
                    // 表單輸入區域
                    formInputSection
                    
                    // 創建按鈕
                    createButton
                }
                .padding(.horizontal, 20)
                .padding(.top, 20)
            }
            .navigationTitle("創建投資群組")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(
                leading: Button("取消") {
                    presentationMode.wrappedValue.dismiss()
                },
                trailing: EmptyView()
            )
        }
        .alert("錯誤", isPresented: $viewModel.showError) {
            Button("確定", role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage)
        }
        .alert("成功", isPresented: $viewModel.showSuccess) {
            Button("確定") {
                presentationMode.wrappedValue.dismiss()
            }
        } message: {
            Text("群組創建成功！")
        }
        .onChange(of: selectedPhoto) { newValue in
            if let newValue = newValue {
                Task {
                    await viewModel.loadSelectedImage(from: newValue)
                }
            }
        }
        .overlay(
            // 成功創建動畫覆蓋層
            Group {
                if viewModel.showSuccessAnimation {
                    ZStack {
                        Color.black.opacity(0.3)
                            .ignoresSafeArea(.all)
                        
                        VStack(spacing: 20) {
                            // 成功圖示動畫
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 80))
                                .foregroundColor(.green)
                                .scaleEffect(viewModel.showSuccessAnimation ? 1.2 : 0.8)
                                .animation(
                                    .spring(response: 0.6, dampingFraction: 0.6, blendDuration: 0),
                                    value: viewModel.showSuccessAnimation
                                )
                            
                            Text("群組創建成功！")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .opacity(viewModel.showSuccessAnimation ? 1 : 0)
                                .animation(.easeInOut(duration: 0.5).delay(0.2), value: viewModel.showSuccessAnimation)
                        }
                        .scaleEffect(viewModel.showSuccessAnimation ? 1 : 0.5)
                        .opacity(viewModel.showSuccessAnimation ? 1 : 0)
                        .animation(.spring(response: 0.8, dampingFraction: 0.8), value: viewModel.showSuccessAnimation)
                    }
                    .transition(.opacity.combined(with: .scale))
                }
            }
        )
    }
    
    // MARK: - 群組頭像選擇區域
    private var groupAvatarSection: some View {
        VStack(spacing: 16) {
            // 頭像顯示
            ZStack {
                Circle()
                    .fill(Color.gray200)
                    .frame(width: 120, height: 120)
                
                if let avatarImage = viewModel.selectedAvatarImage {
                    Image(uiImage: avatarImage)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 120, height: 120)
                        .clipShape(Circle())
                } else {
                    VStack(spacing: 8) {
                        Image(systemName: "person.2.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.gray400)
                        
                        Text("群組頭像")
                            .font(.caption)
                            .foregroundColor(.gray400)
                    }
                }
                
                // 編輯按鈕
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        PhotosPicker(selection: $selectedPhoto, matching: .images) {
                            Circle()
                                .fill(Color.brandPrimary)
                                .frame(width: 36, height: 36)
                                .overlay(
                                    Image(systemName: "camera.fill")
                                        .font(.system(size: 16))
                                        .foregroundColor(.white)
                                )
                        }
                        .offset(x: -8, y: -8)
                    }
                }
            }
            .frame(width: 120, height: 120)
            
            Text("點擊選擇群組頭像")
                .font(.caption)
                .foregroundColor(.textSecondary)
        }
    }
    
    // MARK: - 表單輸入區域
    private var formInputSection: some View {
        VStack(spacing: 20) {
            // 群組名稱
            VStack(alignment: .leading, spacing: 8) {
                Text("群組名稱")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                TextField("輸入群組名稱...", text: $viewModel.groupName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                viewModel.groupNameError.isEmpty ? Color.clear : Color.red,
                                lineWidth: 1
                            )
                    )
                    .onChange(of: viewModel.groupName) { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.validateForm()
                        }
                    }
                
                if !viewModel.groupNameError.isEmpty {
                    Text(viewModel.groupNameError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.groupNameError)
                }
            }
            
            // 主持人（只讀）
            VStack(alignment: .leading, spacing: 8) {
                Text("主持人")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                HStack {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.brandPrimary)
                    
                    Text(viewModel.hostName)
                        .foregroundColor(.textPrimary)
                    
                    Spacer()
                    
                    Text("(您)")
                        .font(.caption)
                        .foregroundColor(.textSecondary)
                }
                .padding()
                .background(Color.gray100)
                .cornerRadius(8)
            }
            
            // 入會費設定
            VStack(alignment: .leading, spacing: 8) {
                Text("入會費設定")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                VStack(spacing: 12) {
                    // 滑桿
                    Slider(value: $viewModel.entryFee, in: 0...100, step: 5)
                        .tint(.brandPrimary)
                    
                    // 費用顯示
                    HStack {
                        Text("0 代幣")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                        
                        Spacer()
                        
                        Text("\(Int(viewModel.entryFee)) 代幣")
                            .font(.headline)
                            .foregroundColor(.brandPrimary)
                            .fontWeight(.bold)
                        
                        Spacer()
                        
                        Text("100 代幣")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                    
                    if viewModel.entryFee == 0 {
                        Text("免費群組 - 所有人都可以加入")
                            .font(.caption)
                            .foregroundColor(.textSecondary)
                    }
                }
                .padding()
                .background(Color.gray50)
                .cornerRadius(8)
            }
            
            // 群組規則
            VStack(alignment: .leading, spacing: 8) {
                Text("群組規則")
                    .font(.headline)
                    .foregroundColor(.textPrimary)
                
                TextEditor(text: $viewModel.groupRules)
                    .frame(minHeight: 100)
                    .padding(8)
                    .background(Color.gray50)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(
                                viewModel.groupRulesError.isEmpty ? Color.gray300 : Color.red,
                                lineWidth: 1
                            )
                    )
                    .onChange(of: viewModel.groupRules) { _ in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            viewModel.validateForm()
                        }
                    }
                
                if !viewModel.groupRulesError.isEmpty {
                    Text(viewModel.groupRulesError)
                        .font(.caption)
                        .foregroundColor(.red)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                        .animation(.easeInOut(duration: 0.3), value: viewModel.groupRulesError)
                }
                
                Text("\(viewModel.groupRules.count)/500 字元")
                    .font(.caption)
                    .foregroundColor(.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
    }
    
    // MARK: - 創建按鈕
    private var createButton: some View {
        Button(action: {
            Task {
                await viewModel.createGroup()
            }
        }) {
            HStack(spacing: 12) {
                if viewModel.isCreating {
                    ProgressView()
                        .scaleEffect(0.8)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                }
                
                Text(viewModel.isCreating ? "創建中..." : "創建群組")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                viewModel.isFormValid && !viewModel.isCreating 
                    ? Color.brandPrimary 
                    : Color.gray400
            )
            .cornerRadius(12)
        }
        .disabled(!viewModel.isFormValid || viewModel.isCreating)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isFormValid)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isCreating)
    }
}

#Preview {
    CreateGroupView()
}