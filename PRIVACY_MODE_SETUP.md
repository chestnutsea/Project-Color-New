# Feelm 隐私模式设置指南

## 问题描述

当 Feelm 在系统设置中被授予"有限照片访问"权限后，每次打开 PHPicker（照片选择器）时，iOS 系统会自动弹出提示：

> "是否要选择更多照片还是保留当前所选内容？"

这是 iOS 系统的默认行为，目的是让用户可以更新"有限访问"的照片范围。

## 解决方案：重置照片权限

要实现完全的隐私模式（不触发系统弹窗），需要**移除 Feelm 的照片库访问权限**：

### 步骤 1：删除 App

1. 长按 Feelm 图标
2. 选择"删除 App"
3. 确认删除

### 步骤 2：重置照片权限（可选）

如果删除 App 后权限仍然保留，可以手动重置：

1. 打开"设置" → "隐私与安全性" → "照片"
2. 找到 Feelm（如果存在）
3. 选择"无"或删除该条目

### 步骤 3：重新安装 App

1. 在 Xcode 中重新运行 Feelm
2. **不要**在系统设置中授予照片库权限
3. 直接点击 Scanner，使用 PHPicker 选择照片

## 隐私模式的工作原理

### PHPicker 的隐私保护特性

- **无需权限**：PHPicker 不需要照片库访问权限
- **用户控制**：用户只能看到和选择自己想要的照片
- **临时授权**：App 只能访问用户选择的照片，其他照片完全不可见
- **系统保护**：照片数据由系统管理，App 无法直接访问照片库

### 代码修改说明

已禁用以下功能以保持隐私模式：

1. **App 启动时的缓存预热**
   - 文件：`Project_ColorApp.swift`
   - 修改：注释掉 `CachePreloader.shared.startPreloading()`
   - 原因：避免在启动时检查照片库权限

2. **点击 Scanner 时的相册预热**
   - 文件：`HomeView.swift` 的 `handleImageTap()` 函数
   - 修改：移除 `AlbumPreheater.shared.preheatDefaultAlbum()` 调用
   - 原因：避免在打开照片选择器时检查照片库权限

## 验证隐私模式

### 正确的行为

1. Kill App 后重新打开
2. 点击 Scanner
3. **直接显示照片选择器**，无任何系统弹窗
4. 用户选择照片后，App 只能访问这些照片

### 如果仍然出现弹窗

检查以下几点：

1. **系统设置中的权限**
   - 设置 → 隐私与安全性 → 照片 → Feelm
   - 应该显示"无"或不存在该条目

2. **是否有其他代码请求权限**
   - 搜索代码中的 `PHPhotoLibrary.requestAuthorization`
   - 搜索代码中的 `PHPhotoLibrary.authorizationStatus`
   - 确保这些调用不会在用户操作前执行

3. **清理 App 数据**
   - 删除 App
   - 重启设备（可选）
   - 重新安装

## 注意事项

### 功能限制

采用隐私模式后，以下功能将受限：

1. **无法自动加载历史照片**
   - App 无法访问之前分析过的照片（除非用户重新选择）
   - 只能显示照片的 assetIdentifier，无法加载缩略图

2. **相册功能受限**
   - 无法显示用户的相册列表
   - 无法浏览相册中的照片

3. **缓存预热失效**
   - App 启动时无法预热缓存
   - 首次加载照片可能稍慢

### 推荐做法

如果需要更好的用户体验，可以考虑：

1. **首次使用时引导**
   - 向用户说明隐私模式的优势
   - 解释为什么不需要照片库权限

2. **按需请求权限**
   - 只在用户需要特定功能时（如浏览相册）才请求权限
   - 提供清晰的权限说明

3. **混合模式**
   - 默认使用 PHPicker（隐私模式）
   - 提供可选的"完整相册访问"功能

## 技术细节

### PHPicker vs 传统照片库访问

| 特性 | PHPicker | 传统方式 (PHPhotoLibrary) |
|------|----------|--------------------------|
| 需要权限 | ❌ 不需要 | ✅ 需要 |
| 系统弹窗 | ❌ 无 | ✅ 有（有限权限时） |
| 访问范围 | 仅用户选择的照片 | 全部照片（或有限照片） |
| 隐私保护 | ✅ 最佳 | ⚠️ 一般 |
| 用户体验 | ✅ 简洁 | ⚠️ 复杂（需要权限管理） |

### 相关 iOS API

```swift
// ❌ 会触发权限检查（避免使用）
let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in ... }

// ✅ 不需要权限（推荐使用）
var configuration = PHPickerConfiguration(photoLibrary: .shared())
let picker = PHPickerViewController(configuration: configuration)
```

## 总结

- ✅ 已禁用所有主动的照片库权限检查
- ✅ 完全依赖 PHPicker 的隐私保护特性
- ✅ 用户体验更简洁，无需管理权限
- ⚠️ 需要重置系统设置中的照片权限才能生效

如果按照以上步骤操作后仍然出现弹窗，请检查代码中是否还有其他地方调用了照片库权限 API。

