//
//  FavoriteAlertView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/23.
//  收藏分析结果的弹窗视图
//

import SwiftUI
import UIKit

struct FavoriteAlertView: View {
    let sessionId: UUID
    let defaultName: String
    let defaultDate: Date
    let onConfirm: (String, Date) -> Void
    let onDismiss: () -> Void
    
    @State private var customDate: Date
    
    /// 日期格式化器（年月日格式）
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "zh_Hans_CN")
        formatter.dateFormat = "yyyy 年 M 月 d 日"
        return formatter
    }
    
    init(sessionId: UUID, defaultName: String, defaultDate: Date, onConfirm: @escaping (String, Date) -> Void, onDismiss: @escaping () -> Void = {}) {
        self.sessionId = sessionId
        self.defaultName = defaultName
        self.defaultDate = defaultDate
        self.onConfirm = onConfirm
        self.onDismiss = onDismiss
        
        _customDate = State(initialValue: defaultDate)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题
            Text("收藏")
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            // 日期选择器（使用 SwiftUI 原生 DatePicker，直接显示年月日格式）
            DatePicker(
                "",
                selection: $customDate,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .labelsHidden()
            .environment(\.locale, Locale(identifier: "zh_Hans_CN"))
            .padding(.horizontal, 16)
            .padding(.bottom, 16)
            
            Divider()
            
            // 按钮区域
            HStack(spacing: 0) {
                Button("取消") {
                    onDismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundColor(.primary)
                
                Divider()
                    .frame(height: 44)
                
                Button("确认") {
                    // 使用日期格式化后的字符串作为名称
                    let name = dateFormatter.string(from: customDate)
                    onConfirm(name, customDate)
                    onDismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundColor(.blue)
                .fontWeight(.semibold)
            }
        }
        .background(adaptiveMaterial)
    }
    
    /// iOS 系统版本自适应的材质背景
    @ViewBuilder
    private var adaptiveMaterial: some View {
        if #available(iOS 15.0, *) {
            // iOS 15+ 使用 Material
            Rectangle()
                .fill(.regularMaterial)
        } else {
            // iOS 14 及以下使用半透明背景
            Rectangle()
                .fill(Color(.systemBackground).opacity(0.95))
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

/// SwiftUI 封装的 UIDatePicker，确保 compact 样式一开始就使用指定的 Locale 展示文本
private struct LocaleAwareCompactDatePicker: UIViewRepresentable {
    @Binding var date: Date
    var locale: Locale
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    func makeUIView(context: Context) -> UIDatePicker {
        let picker = UIDatePicker()
        picker.datePickerMode = .date
        picker.preferredDatePickerStyle = .compact
        picker.locale = locale
        picker.calendar = locale.calendar
        picker.date = date
        picker.addTarget(context.coordinator, action: #selector(Coordinator.dateChanged(_:)), for: .valueChanged)
        return picker
    }
    
    func updateUIView(_ uiView: UIDatePicker, context: Context) {
        if uiView.date != date {
            uiView.setDate(date, animated: false)
        }
        if uiView.locale != locale {
            uiView.locale = locale
            uiView.calendar = locale.calendar
        }
    }
    
    final class Coordinator: NSObject {
        private let parent: LocaleAwareCompactDatePicker
        
        init(_ parent: LocaleAwareCompactDatePicker) {
            self.parent = parent
        }
        
        @objc
        func dateChanged(_ sender: UIDatePicker) {
            parent.date = sender.date
        }
    }
}
