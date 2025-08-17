//
//  DevelopmentPlaceholderView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/8/17.
//  錦標賽功能開發中占位符視圖
//

import SwiftUI

/// 功能開發中的占位符視圖
/// 用於錦標賽功能暫時關閉時顯示
struct DevelopmentPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isVisible = false
    
    var body: some View {
        ZStack {
            // 背景
            Color(.systemBackground)
                .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 頂部導航欄
                HStack {
                    Button("關閉") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                    
                    Spacer()
                    
                    Text("錦標賽")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // 平衡右側空間
                    Button("關閉") {
                        dismiss()
                    }
                    .opacity(0)
                    .disabled(true)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
                .overlay(
                    Rectangle()
                        .frame(height: 0.5)
                        .foregroundColor(.gray.opacity(0.3)),
                    alignment: .bottom
                )
                
                // 主要內容
                ScrollView {
                    VStack(spacing: 40) {
                        Spacer()
                            .frame(height: 60)
                        
                        // 開發中圖標和動畫
                        VStack(spacing: 24) {
                            ZStack {
                                Circle()
                                    .fill(Color.blue.opacity(0.1))
                                    .frame(width: 120, height: 120)
                                
                                Image(systemName: "hammer.fill")
                                    .font(.system(size: 50))
                                    .foregroundColor(.blue)
                                    .scaleEffect(isVisible ? 1.0 : 0.8)
                                    .animation(.spring(response: 0.6, dampingFraction: 0.8), value: isVisible)
                            }
                            
                            VStack(spacing: 16) {
                                Text("功能開發中")
                                    .font(.largeTitle)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                                    .opacity(isVisible ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.8).delay(0.2), value: isVisible)
                                
                                Text("錦標賽功能正在開發中\n敬請期待更精彩的投資競賽體驗！")
                                    .font(.body)
                                    .multilineTextAlignment(.center)
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 32)
                                    .opacity(isVisible ? 1 : 0)
                                    .animation(.easeInOut(duration: 0.8).delay(0.4), value: isVisible)
                            }
                        }
                        
                        // 開發進度信息
                        VStack(spacing: 12) {
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                Text("基礎架構設計")
                                Spacer()
                                Text("✓ 完成")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Image(systemName: "circle.dotted")
                                    .foregroundColor(.orange)
                                Text("競賽規則制定")
                                Spacer()
                                Text("進行中")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                            }
                            
                            HStack {
                                Image(systemName: "circle")
                                    .foregroundColor(.gray)
                                Text("界面開發")
                                Spacer()
                                Text("待開始")
                                    .foregroundColor(.gray)
                                    .font(.caption)
                            }
                        }
                        .padding(.horizontal, 40)
                        .padding(.vertical, 20)
                        .background(Color.gray.opacity(0.05))
                        .cornerRadius(12)
                        .padding(.horizontal, 24)
                        .opacity(isVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).delay(0.6), value: isVisible)
                        
                        Spacer()
                            .frame(height: 60)
                        
                        // 返回按鈕
                        Button(action: {
                            dismiss()
                        }) {
                            HStack {
                                Image(systemName: "house.fill")
                                Text("返回首頁")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 24)
                        .opacity(isVisible ? 1 : 0)
                        .animation(.easeInOut(duration: 0.8).delay(0.8), value: isVisible)
                        
                        Spacer()
                            .frame(height: 40)
                    }
                }
            }
        }
        .onAppear {
            // 確保動畫在View完全載入後才開始
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isVisible = true
            }
        }
    }
}

// MARK: - Preview
struct DevelopmentPlaceholderView_Previews: PreviewProvider {
    static var previews: some View {
        DevelopmentPlaceholderView()
    }
}