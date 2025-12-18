# 相册权限说明

## 📸 关于"受限访问"模式

### 什么是受限访问？

iOS 14+ 引入了新的照片权限模式：
- **完整访问**：App 可以访问所有照片
- **受限访问**：用户只授权 App 访问部分照片（例如 2 张）
- **拒绝访问**：App 无法访问任何照片

### 当前行为（正常且符合 Apple 设计）

#### 1. 照片选择器显示所有照片
✅ **这是正常的！**

即使用户只授权了 2 张照片，系统照片选择器（`PHPickerViewController`）也会显示所有照片。

**原因**：
- Apple 的设计理念是让用户在需要时可以临时授权更多照片
- 当用户点击未授权的照片时，系统会自动弹出权限请求
- 这样用户可以灵活地添加更多照片，而不需要去设置中修改权限

#### 2. 未授权的照片无法出现在主页
✅ **这是正常的！**

当用户选择了未授权的照片，但没有在系统弹窗中授权时：
- 照片无法被读取
- 不会出现在主页的照片堆中
- 这是 iOS 的隐私保护机制

### 用户体验流程

```
1. 用户只授权了 2 张照片
   ↓
2. 点击 Scanner 打开照片选择器
   ↓
3. 选择器显示所有照片（包括未授权的）
   ↓
4. 用户点击第 3 张照片（未授权）
   ↓
5. 系统弹出："是否允许 Feelm 访问这张照片？"
   ├─ 用户选择"允许" → 照片被添加到主页 ✅
   └─ 用户选择"不允许" → 照片无法添加 ❌
```

---

## 🔧 最新改动

### 1. 权限请求时机优化

**之前的问题**：
- 每次进入主页时，如果是"受限访问"模式，系统会自动弹出权限选择器
- 用户体验不好

**现在的行为**：
- 进入主页时**不会**主动请求权限
- 只有在**点击 Scanner** 时才会检查和请求权限
- 如果是"受限访问"模式，系统会在打开照片选择器时自动询问

### 2. 权限状态检查

```swift
// ✅ 进入主页时：仅检查权限状态，不请求
private func updatePhotoAuthorizationStatus() {
    let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    photoAuthorizationStatus = status
}

// ✅ 点击 Scanner 时：检查并请求权限
private func handleImageTap() {
    let currentStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    
    switch currentStatus {
    case .authorized, .limited:
        // 直接打开照片选择器
        showPhotoPicker = true
        
    case .notDetermined:
        // 请求权限
        PHPhotoLibrary.requestAuthorization(for: .readWrite) { status in
            if status == .authorized || status == .limited {
                showPhotoPicker = true
            }
        }
        
    case .denied, .restricted:
        // 提示用户去设置中开启权限
        print("⚠️ 相册权限被拒绝或受限")
    }
}
```

### 3. 未授权照片处理

```swift
// ✅ 记录无法访问的照片数量
private func convertPickerResultsToAssets(_ results: [PHPickerResult], completion: @escaping ([PHAsset]) -> Void) {
    var failedCount = 0
    
    for result in results {
        if let assetIdentifier = result.assetIdentifier {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
            if fetchResult.firstObject == nil {
                failedCount += 1  // 照片无法访问
            }
        } else {
            failedCount += 1  // 无法获取 identifier
        }
    }
    
    if failedCount > 0 {
        print("⚠️ 有 \(failedCount) 张照片无法访问（可能是权限限制）")
        // 可以在这里显示 Toast 提示
    }
}
```

---

## 💡 建议

### 对于用户
1. 如果想要完整的体验，建议授予"完整访问"权限
2. 如果只想授权部分照片，可以使用"受限访问"模式
3. 在照片选择器中点击未授权的照片时，系统会询问是否授权

### 对于开发者
1. ✅ 不要在 `onAppear` 时主动请求权限（避免频繁弹窗）
2. ✅ 在用户点击功能按钮时才请求权限（更好的用户体验）
3. ✅ 使用 `PHPickerViewController` 而不是自定义选择器（符合 Apple 设计规范）
4. ⚠️ 可以考虑添加 Toast 提示，告知用户部分照片无法访问

---

## 🎯 总结

**当前行为是正常的，符合 Apple 的设计规范：**

1. ✅ 照片选择器显示所有照片（让用户可以临时授权）
2. ✅ 未授权的照片无法被读取（隐私保护）
3. ✅ 权限请求在点击 Scanner 时才触发（更好的体验）

**不需要修改，这是 iOS 系统的预期行为！**

