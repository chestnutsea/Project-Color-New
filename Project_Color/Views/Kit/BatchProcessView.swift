//
//  BatchProcessView.swift
//  Project_Color
//
//  批处理页面 - 设置和工具
//

import SwiftUI

struct BatchProcessView: View {
    // MARK: - 布局常量
    private enum Layout {
        static let cornerRadius: CGFloat = 20
        static let horizontalPadding: CGFloat = 16
        static let verticalSpacing: CGFloat = 16
        static let rowVerticalPadding: CGFloat = 14
        static let rowHorizontalPadding: CGFloat = 16
    }
    
    // MARK: - State
    @State private var usePhotoTimeAsDefault: Bool = true
    @State private var developmentMode: BatchProcessSettings.DevelopmentMode = .tone
    @State private var showDevelopmentModePicker = false
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.verticalSpacing) {
                // 设置卡片
                VStack(spacing: 0) {
                    // 使用照片时间作为默认名称与日期
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("使用照片时间作为默认名称与日期")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $usePhotoTimeAsDefault)
                            .tint(.black)
                            .labelsHidden()
                    }
                    .padding(.horizontal, Layout.rowHorizontalPadding)
                    .padding(.vertical, Layout.rowVerticalPadding)
                    .contentShape(Rectangle())
                    
                    Divider()
                        .padding(.leading, Layout.rowHorizontalPadding + 28 + 12)
                    
                    // 显影解析方式
                    Button {
                        showDevelopmentModePicker = true
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: "camera.filters")
                                .font(.system(size: 20))
                                .foregroundColor(.primary)
                                .frame(width: 28)
                            
                            Text("显影解析方式")
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.primary)
                            
                            Spacer()
                            
                            Text(developmentMode.rawValue)
                                .font(.system(size: 17, weight: .regular))
                                .foregroundColor(.secondary)
                            
                            Image(systemName: "chevron.right")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, Layout.rowHorizontalPadding)
                        .padding(.vertical, Layout.rowVerticalPadding)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .confirmationDialog("选择显影解析方式", isPresented: $showDevelopmentModePicker, titleVisibility: .visible) {
                        ForEach(BatchProcessSettings.DevelopmentMode.allCases, id: \.self) { mode in
                            Button(mode.rawValue) {
                                developmentMode = mode
                                BatchProcessSettings.developmentMode = mode
                            }
                        }
                        Button("取消", role: .cancel) {}
                    }
                    
                    Divider()
                        .padding(.leading, Layout.rowHorizontalPadding + 28 + 12)
                    
                    // 清理缓存
                    Button {
                        // TODO: 添加清理缓存功能
                    } label: {
                        BatchProcessMenuRow(
                            icon: "trash",
                            title: "清理缓存"
                        )
                    }
                    .buttonStyle(.plain)
                }
                .background(Color(.systemBackground))
                .cornerRadius(Layout.cornerRadius)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.verticalSpacing)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("批处理")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            // 加载设置
            usePhotoTimeAsDefault = BatchProcessSettings.usePhotoTimeAsDefault
            developmentMode = BatchProcessSettings.developmentMode
        }
        .onChange(of: usePhotoTimeAsDefault) { newValue in
            // 保存设置
            BatchProcessSettings.usePhotoTimeAsDefault = newValue
        }
    }
}

// MARK: - 批处理菜单行
private struct BatchProcessMenuRow: View {
    let icon: String
    let title: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.primary)
                .frame(width: 28)
            
            Text(title)
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.primary)
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .contentShape(Rectangle())
    }
}

#Preview {
    NavigationView {
        BatchProcessView()
    }
}

