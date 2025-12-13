//
//  FavoriteAlertView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/23.
//  收藏分析结果的弹窗视图
//

import SwiftUI
import UIKit

// MARK: - 布局常量
private enum FavoriteAlertLayout {
    static let datePickerHeight: CGFloat = 180  // 日期选择器展开时的高度
}

struct FavoriteAlertView: View {
    let sessionId: UUID
    let defaultName: String
    let defaultDate: Date
    let onConfirm: (String, Date) -> Void
    let onDismiss: () -> Void
    
    @State private var customDate: Date
    @State private var showDatePicker: Bool = false
    
    /// 日期格式化器（年月日格式，根据系统语言自动适配）
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        // 根据当前语言选择日期格式
        if Locale.current.language.languageCode?.identifier == "zh" {
            // 中文：2025 年 11 月 9 日
            formatter.dateFormat = "yyyy 年 M 月 d 日"
        } else {
            // 英文及其他语言：2025/11/9
            formatter.dateFormat = "yyyy/M/d"
        }
        
        return formatter
    }
    
    /// 格式化后的日期字符串
    private var formattedDate: String {
        dateFormatter.string(from: customDate)
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
            Text(L10n.Favorite.title.localized)
                .font(.headline)
                .padding(.top, 16)
                .padding(.bottom, 12)
            
            // 日期选择行：左侧"照片日期"，右侧日期按钮，整体居中
            HStack {
                Text(L10n.Favorite.photoDate.localized)
                    .font(.body)
                    .foregroundColor(.primary)
                
                Spacer()
                
                // 日期按钮，点击弹出日期选择器
                Button {
                    showDatePicker.toggle()
                } label: {
                    Text(formattedDate)
                        .font(.body)
                        .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)
            
            // 日期选择器（展开时显示）
            if showDatePicker {
                DatePicker(
                    "",
                    selection: $customDate,
                    displayedComponents: .date
                )
                .datePickerStyle(.wheel)
                .labelsHidden()
                .environment(\.locale, Locale.current)
                .frame(height: FavoriteAlertLayout.datePickerHeight)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
            
            Divider()
            
            // 按钮区域
            HStack(spacing: 0) {
                Button(L10n.Favorite.cancel.localized) {
                    onDismiss()
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .foregroundColor(.primary)
                
                Divider()
                    .frame(height: 44)
                
                Button(L10n.Favorite.confirm.localized) {
                    // 使用日期格式化后的字符串作为名称
                    let name = formattedDate
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
