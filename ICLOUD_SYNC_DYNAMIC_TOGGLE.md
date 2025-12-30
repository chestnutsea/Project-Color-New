# iCloud 同步动态切换实现

## 问题描述

之前的实现中，iCloud 同步开关需要重启应用才能生效，因为：

1. `CoreDataManager` 在应用启动时初始化
2. `NSPersistentCloudKitContainer` 的配置在初始化时就固定了
3. 无法在运行时修改 CloudKit 配置

## 解决方案

实现了**动态切换**功能，用户可以在不重启应用的情况下启用/禁用 iCloud 同步。

### 核心改动

#### 1. CoreDataManager.swift - 双存储架构

**改动前**：
- 单一存储，启动时根据设置决定是否启用 CloudKit
- 需要重启才能切换

**改动后**：
```swift
// 定义两个存储 URL
private let localStoreURL: URL  // 本地存储（始终存在）
private let cloudStoreURL: URL  // 云端存储（按需添加/移除）

// 动态添加 CloudKit 存储
private func addCloudKitStore() {
    let cloudDescription = NSPersistentStoreDescription(url: cloudStoreURL)
    cloudDescription.cloudKitContainerOptions = NSPersistentCloudKitContainerOptions(
        containerIdentifier: "iCloud.com.linyahuang.ProjectColor"
    )
    
    cloudKitStore = try container.persistentStoreCoordinator.addPersistentStore(
        ofType: NSSQLiteStoreType,
        configurationName: nil,
        at: cloudStoreURL,
        options: cloudDescription.options
    )
}

// 动态移除 CloudKit 存储
private func removeCloudKitStore() {
    try container.persistentStoreCoordinator.remove(cloudKitStore)
    cloudKitStore = nil
}

// 公开方法，供设置界面调用
func toggleCloudSync(enabled: Bool) {
    if enabled {
        addCloudKitStore()
    } else {
        removeCloudKitStore()
    }
}
```

**关键点**：
- 本地存储始终存在，作为主存储
- CloudKit 存储按需动态添加/移除
- 使用 `NSPersistentStoreCoordinator.addPersistentStore()` 和 `remove()` 实现运行时切换

#### 2. CloudSyncSettingsView.swift - 实时切换 UI

**改动前**：
- 切换开关时弹出"需要重启"警告
- 用户必须手动重启应用

**改动后**：
```swift
private func handleSyncToggle(_ newValue: Bool) {
    isToggling = true
    
    Task {
        // 1. 保存设置
        CloudSyncSettings.shared.isSyncEnabled = newValue
        
        // 2. 动态切换 Core Data 存储
        await MainActor.run {
            CoreDataManager.shared.toggleCloudSync(enabled: newValue)
        }
        
        // 3. 显示成功提示
        await MainActor.run {
            toastMessage = newValue ? "☁️ iCloud 同步已启用" : "📱 已切换到本地存储"
            showSuccessToast = true
        }
        
        isToggling = false
    }
}
```

**用户体验改进**：
- ✅ 切换开关后立即生效，无需重启
- ✅ 显示友好的 Toast 提示（2秒后自动消失）
- ✅ 切换过程中禁用开关，防止重复操作

## 技术细节

### 存储架构

```
应用启动
  ↓
加载本地存储 (Project_Color_Local.sqlite)
  ↓
检查 CloudSyncSettings.isSyncEnabled
  ↓
如果启用 → 添加 CloudKit 存储 (Project_Color_Cloud.sqlite)
  ↓
运行时切换
  ↓
启用：addCloudKitStore()
禁用：removeCloudKitStore()
```

### 数据同步行为

1. **启用 iCloud 同步时**：
   - 添加 CloudKit 存储
   - Core Data 自动开始同步本地数据到 iCloud
   - 其他设备上的数据会自动下载

2. **禁用 iCloud 同步时**：
   - 移除 CloudKit 存储
   - 本地数据保留不变
   - 停止与 iCloud 的同步

3. **数据安全**：
   - 本地存储始终保留完整数据
   - 切换不会丢失任何数据
   - iCloud 数据在云端保留，重新启用后会继续同步

## 测试建议

### 测试场景 1：启用 iCloud 同步
1. 打开设置 → 云相册
2. 开启 iCloud 同步开关
3. 观察：
   - ✅ Toast 提示"☁️ iCloud 同步已启用"
   - ✅ 控制台输出"☁️ iCloud 同步已启用"
   - ✅ 无需重启应用

### 测试场景 2：禁用 iCloud 同步
1. 打开设置 → 云相册
2. 关闭 iCloud 同步开关
3. 观察：
   - ✅ Toast 提示"📱 已切换到本地存储"
   - ✅ 控制台输出"📱 iCloud 同步已禁用"
   - ✅ 无需重启应用

### 测试场景 3：多设备同步
1. 设备 A：启用 iCloud 同步，添加照片分析
2. 设备 B：启用 iCloud 同步
3. 观察：
   - ✅ 设备 B 自动下载设备 A 的数据
   - ✅ 两设备数据保持一致

### 测试场景 4：数据完整性
1. 本地添加一些分析会话
2. 启用 iCloud 同步
3. 禁用 iCloud 同步
4. 观察：
   - ✅ 本地数据完整保留
   - ✅ 无数据丢失

## 与其他应用的对比

### 常见实现方式

| 应用 | 实现方式 | 需要重启 |
|------|---------|---------|
| **Notes (备忘录)** | 动态切换 | ❌ 否 |
| **Reminders (提醒事项)** | 动态切换 | ❌ 否 |
| **Photos (照片)** | 系统级设置 | ❌ 否 |
| **旧版 Feelm** | 启动时配置 | ✅ 是 |
| **新版 Feelm** | 动态切换 | ❌ 否 |

现在 Feelm 的 iCloud 同步体验与系统应用一致！

## 技术参考

- [NSPersistentStoreCoordinator - Apple Documentation](https://developer.apple.com/documentation/coredata/nspersistentstorecoordinator)
- [NSPersistentCloudKitContainer - Apple Documentation](https://developer.apple.com/documentation/coredata/nspersistentcloudkitcontainer)
- [Core Data with CloudKit - WWDC](https://developer.apple.com/videos/play/wwdc2019/202/)

## 更新日期

2025-12-29

## 作者

AI Assistant

