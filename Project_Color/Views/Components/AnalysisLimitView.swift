//
//  AnalysisLimitView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/31.
//  分析次数限制提示视图
//

import SwiftUI

struct AnalysisLimitView: View {
    @ObservedObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showUpgradeSheet = false
    @State private var limitInfo: (used: Int, total: Int, isUnlimited: Bool) = (0, 3, false)
    @State private var membershipTitle: String = "免费版"
    
    var body: some View {
        HStack(spacing: 12) {
            // 图标
            Image(subscriptionManager.isProUser ? "pro" : "free")
                .resizable()
                .renderingMode(.template)
                .frame(width: 20, height: 20)
                .foregroundColor(Color(hex: "FFE74E"))
            
            // 文字信息
            VStack(alignment: .leading, spacing: 4) {
                Text(membershipTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundColor(.primary)
                
                Text(String(format: L10n.AnalysisLimit.monthlyUsage.localized, limitInfo.used, limitInfo.total))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            
            Spacer()
            
            // 升级/查看按钮（仅非终身会员显示）
            if !subscriptionManager.isLifetimeUser {
                Button(action: {
                    showUpgradeSheet = true
                }) {
                    Text(subscriptionManager.isProUser ? L10n.AnalysisLimit.view.localized : L10n.AnalysisLimit.upgradePro.localized)
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color(hex: "FFE74E"))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .onAppear {
            updateInfo()
        }
        .onChange(of: subscriptionManager.membershipType) { _ in
            updateInfo()
        }
        .onChange(of: subscriptionManager.currentMonthAnalysisCount) { _ in
            updateInfo()
        }
        .fullScreenCover(isPresented: $showUpgradeSheet) {
            UnlockAISheetView(onClose: {
                showUpgradeSheet = false
            })
        }
    }
    
    private func updateInfo() {
        limitInfo = subscriptionManager.getLimitInfo()
        membershipTitle = subscriptionManager.membershipType.displayName
    }
}

#Preview {
    AnalysisLimitView()
        .padding()
}

