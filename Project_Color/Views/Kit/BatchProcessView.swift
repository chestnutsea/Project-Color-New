//
//  BatchProcessView.swift
//  Project_Color
//
//  照片暗房页面 - 设置和工具
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
    @State private var usePhotoTimeAsDefault: Bool = BatchProcessSettings.usePhotoTimeAsDefault
    @State private var developmentFavoriteOnly: Bool = BatchProcessSettings.developmentFavoriteOnly
    @State private var scanResultStyle: BatchProcessSettings.ScanResultStyle = BatchProcessSettings.scanResultStyle
    
    var body: some View {
        ScrollView {
            VStack(spacing: Layout.verticalSpacing) {
                // 设置卡片
                VStack(spacing: 0) {
                    // 使用照片时间作为默认日期
                    HStack(spacing: 12) {
                        Image(systemName: "clock")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Darkroom.usePhotoTime.localized)
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
                    
                    // 只对收藏照片进行显影
                    HStack(spacing: 12) {
                        Image(systemName: "heart")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(L10n.Darkroom.favoriteOnly.localized)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.primary)
                        }
                        
                        Spacer()
                        
                        Toggle("", isOn: $developmentFavoriteOnly)
                            .tint(.black)
                            .labelsHidden()
                    }
                    .padding(.horizontal, Layout.rowHorizontalPadding)
                    .padding(.vertical, Layout.rowVerticalPadding)
                    .contentShape(Rectangle())
                    
                    Divider()
                        .padding(.leading, Layout.rowHorizontalPadding + 28 + 12)
                    
                    // 扫描结果页样式
                    HStack(spacing: 12) {
                        Image(systemName: "rectangle.split.2x1")
                            .font(.system(size: 20))
                            .foregroundColor(.primary)
                            .frame(width: 28)
                        
                        Text(L10n.Darkroom.scanResultStyle.localized)
                            .font(.system(size: 17, weight: .regular))
                            .foregroundColor(.primary)
                        
                        Spacer()
                        
                        Menu {
                            ForEach(BatchProcessSettings.ScanResultStyle.allCases, id: \.self) { style in
                                Button {
                                    scanResultStyle = style
                                    BatchProcessSettings.scanResultStyle = style
                                } label: {
                                    if style == scanResultStyle {
                                        Label(style.displayName, systemImage: "checkmark")
                                    } else {
                                        Text(style.displayName)
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Text(scanResultStyle.displayName)
                                    .font(.system(size: 17, weight: .regular))
                                    .foregroundColor(.secondary)
                                
                                Image(systemName: "chevron.up.chevron.down")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.horizontal, Layout.rowHorizontalPadding)
                    .padding(.vertical, Layout.rowVerticalPadding)
                    .contentShape(Rectangle())
                }
                .background(Color(.systemBackground))
                .cornerRadius(Layout.cornerRadius)
            }
            .padding(.horizontal, Layout.horizontalPadding)
            .padding(.top, Layout.verticalSpacing)
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle(L10n.Darkroom.title.localized)
        .navigationBarTitleDisplayMode(.inline)
        .hideTabBar()
        .onAppear {
            // 每次进入页面时从设置读取最新值
            usePhotoTimeAsDefault = BatchProcessSettings.usePhotoTimeAsDefault
            developmentFavoriteOnly = BatchProcessSettings.developmentFavoriteOnly
            scanResultStyle = BatchProcessSettings.scanResultStyle
        }
        .onChange(of: usePhotoTimeAsDefault) { newValue in
            // 保存设置
            BatchProcessSettings.usePhotoTimeAsDefault = newValue
        }
        .onChange(of: developmentFavoriteOnly) { newValue in
            // 保存设置
            BatchProcessSettings.developmentFavoriteOnly = newValue
        }
    }
}

// MARK: - 照片暗房菜单行
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

