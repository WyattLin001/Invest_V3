//
//  PaymentOptionsView.swift
//  Invest_V3
//
//  Created by AI Assistant on 2025/7/19.
//

import SwiftUI

struct SimplePaymentOptionsView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("選擇充值方式")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: 12) {
                    PaymentMethodCard(
                        icon: "💳",
                        title: "信用卡/金融卡",
                        subtitle: "Visa, MasterCard, JCB"
                    )
                    
                    PaymentMethodCard(
                        icon: "📱",
                        title: "Apple Pay",
                        subtitle: "快速安全支付"
                    )
                    
                    PaymentMethodCard(
                        icon: "🏦",
                        title: "銀行轉帳",
                        subtitle: "玉山銀行"
                    )
                }
                .padding(.horizontal)
                
                Spacer()
            }
            .navigationTitle("充值選項")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("關閉") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct PaymentMethodCard: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack {
            Text(icon)
                .font(.title2)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.systemSecondaryBackground)
        .cornerRadius(10)
    }
}

#Preview {
    SimplePaymentOptionsView()
}
