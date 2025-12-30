//
//  CloudSyncSettingsView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/24.
//  iCloud 同步设置页面
//

import SwiftUI
import CoreData

struct CloudSyncSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isSyncEnabled: Bool = CloudSyncSettings.shared.isSyncEnabled
    @State private var sessionCount: Int = 0
    @State private var photoCount: Int = 0
    @State private var estimatedSize: String = "计算中..."
    @State private var isToggling: Bool = false  // 切换中状态
    @State private var showSuccessToast: Bool = false
    @State private var toastMessage: String = ""
    
    var body: some View {
        Group {
            if #available(iOS 16.0, *) {
                NavigationStack {
                    contentView
                }
            } else {
                NavigationView {
                    contentView
                }
                .navigationViewStyle(.stack)
            }
        }
        .overlay(alignment: .top) {
            if showSuccessToast {
                toastView
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(999)
            }
        }
        .onAppear {
            loadStatistics()
        }
    }
    
    // MARK: - Toast View
    private var toastView: some View {
        HStack(spacing: 12) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text(toastMessage)
                .font(.system(size: 15))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(color: .black.opacity(0.1), radius: 10, x: 0, y: 4)
        .padding(.top, 60)
    }
    
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 20) {
                // 状态卡片
                statusCard
                
                // 数据统计卡片
                statisticsCard
                
                // 说明卡片
                descriptionCard
            }
            .padding(.horizontal, 16)
            .padding(.top, 20)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle(L10n.CloudSync.title.localized)
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - 状态卡片
    private var statusCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(L10n.CloudSync.syncStatus.localized)
                        .font(.system(size: 17, weight: .semibold))
                    
                    Text(isSyncEnabled ? L10n.CloudSync.statusEnabled.localized : L10n.CloudSync.statusDisabled.localized)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Toggle("", isOn: $isSyncEnabled)
                    .labelsHidden()
                    .disabled(isToggling)
                    .onChange(of: isSyncEnabled) { newValue in
                        handleSyncToggle(newValue)
                    }
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 数据统计卡片
    private var statisticsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.CloudSync.dataStats.localized)
                .font(.system(size: 17, weight: .semibold))
            
            Divider()
            
            HStack {
                Label(L10n.CloudSync.statsSessions.localized, systemImage: "folder.fill")
                    .font(.system(size: 15))
                Spacer()
                Text("\(sessionCount)")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label(L10n.CloudSync.statsPhotos.localized, systemImage: "photo.fill")
                    .font(.system(size: 15))
                Spacer()
                Text("\(photoCount)")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
            
            HStack {
                Label(L10n.CloudSync.statsSize.localized, systemImage: "internaldrive.fill")
                    .font(.system(size: 15))
                Spacer()
                Text(estimatedSize)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    // MARK: - 说明卡片
    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(L10n.CloudSync.aboutTitle.localized)
                .font(.system(size: 17, weight: .semibold))
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                descriptionRow(icon: "icloud.and.arrow.up", text: L10n.CloudSync.aboutMultiDevice.localized)
                descriptionRow(icon: "externaldrive.fill.badge.icloud", text: L10n.CloudSync.aboutStorage.localized)
                descriptionRow(icon: "wifi", text: L10n.CloudSync.aboutNetwork.localized)
                descriptionRow(icon: "photo.on.rectangle", text: L10n.CloudSync.aboutPhotoReference.localized)
            }
        }
        .padding(16)
        .background(Color(.systemBackground))
        .cornerRadius(12)
    }
    
    private func descriptionRow(icon: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.primary)
                .frame(width: 20)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
    
    // MARK: - Methods
    
    private func handleSyncToggle(_ newValue: Bool) {
        guard !isToggling else { return }
        
        isToggling = true
        
        Task {
            // 1. 保存设置
            CloudSyncSettings.shared.isSyncEnabled = newValue
            
            // 2. 动态切换 Core Data 存储
            await MainActor.run {
                CoreDataManager.shared.toggleCloudSync(enabled: newValue)
            }
            
            // 3. 刷新统计数据（切换后立即更新显示）
            loadStatistics()
            
            // 4. 显示成功提示
            await MainActor.run {
                toastMessage = newValue ? "☁️ iCloud 同步已启用" : "📱 已切换到本地存储"
                withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                    showSuccessToast = true
                }
                
                // 2 秒后隐藏提示
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        showSuccessToast = false
                    }
                }
                
                isToggling = false
            }
            
            print("✅ iCloud 同步状态已切换: \(newValue ? "启用" : "禁用")")
        }
    }
    
    private func loadStatistics() {
        Task {
            // ✅ 只统计云端数据（cloudOnly: true）
            let stats = CoreDataManager.shared.getDataStatistics(cloudOnly: true)
            let totalPhotoCount = await CoreDataManager.shared.fetchTotalPhotoCount(cloudOnly: true)
            
            // 估算存储大小：每张照片约 100KB（分析数据 + 缩略图）
            let estimatedBytes = totalPhotoCount * 100 * 1024
            let formattedSize = formatBytes(estimatedBytes)
            
            await MainActor.run {
                sessionCount = stats.total
                photoCount = totalPhotoCount
                estimatedSize = formattedSize
            }
        }
    }
    
    private func formatBytes(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}

#Preview {
    CloudSyncSettingsView()
}

