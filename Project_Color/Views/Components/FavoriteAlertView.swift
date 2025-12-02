//
//  FavoriteAlertView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/23.
//  收藏分析结果的弹窗视图
//

import SwiftUI

struct FavoriteAlertView: View {
    let sessionId: UUID
    let defaultName: String
    let defaultDate: Date
    let onConfirm: (String, Date) -> Void
    let onDismiss: () -> Void
    
    @State private var customName: String
    @State private var customDate: Date
    
    init(sessionId: UUID, defaultName: String, defaultDate: Date, onConfirm: @escaping (String, Date) -> Void, onDismiss: @escaping () -> Void = {}) {
        self.sessionId = sessionId
        self.defaultName = defaultName
        self.defaultDate = defaultDate
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        
        _customName = State(initialValue: defaultName)
        _customDate = State(initialValue: defaultDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            Text("收藏该组分析结果")
                .font(.headline)
                .padding(.top, 20)
                .padding(.bottom, 16)
            
            // 内容区域
            VStack(alignment: .leading, spacing: 16) {
                // 名称输入框
                VStack(alignment: .leading, spacing: 8) {
                    Text("名称")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("请输入名称", text: $customName)
                        .textFieldStyle(.roundedBorder)
                }
                
                // 日期选择器（只显示日期选择器，不显示格式化文本）
                VStack(alignment: .leading, spacing: 8) {
                    Text("日期")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    DatePicker("", selection: $customDate, displayedComponents: .date)
                        .datePickerStyle(.compact)
                        .labelsHidden()
                        .environment(\.locale, Locale(identifier: "zh_CN"))
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
            
            Divider()
            
            // 按钮区域
            HStack(spacing: 0) {
                Button("取消") {
                    onDismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.primary)
                
                Divider()
                    .frame(height: 44)
                
                Button("确认") {
                    onConfirm(customName.trimmingCharacters(in: .whitespacesAndNewlines), customDate)
                    onDismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundColor(.blue)
                .fontWeight(.semibold)
                .disabled(customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
    }
}

#Preview {
    FavoriteAlertView(
        sessionId: UUID(),
        defaultName: "2025 年 11 月 23 日",
        defaultDate: Date()
    ) { name, date in
        print("收藏: \(name), \(date)")
    }
}

