# 多语言实施指南

## ✅ 已完成的工作

### 1. 基础设施
- ✅ 创建 `LocalizationHelper.swift` - 多语言辅助工具
- ✅ 创建 `en.lproj/Localizable.strings` - 英文翻译
- ✅ 创建 `zh-Hans.lproj/Localizable.strings` - 简体中文翻译
- ✅ 创建 `L10n` 枚举 - 类型安全的 Key 定义

### 2. 已支持多语言的页面
- ✅ **MainTabView** - Tab Bar 标签
- ✅ **KitView** - 我的页面
- ✅ **BatchProcessView** - 照片暗房页面
- ✅ **ToastView** - Toast 提示消息
- ✅ **BatchProcessSettings** - 显影模式和扫描结果页样式

---

## 📖 使用方法

### 方法 1：使用 String 扩展（推荐）

```swift
// 简单用法
Text("tab.scanner".localized)

// 带注释（方便维护）
Text("tab.scanner".localized(comment: "扫描标签"))

// 带参数（格式化字符串）
"greeting.user".localized(with: userName)
```

### 方法 2：使用 L10n 枚举（类型安全）

```swift
// 避免拼写错误
Text(L10n.Tab.scanner.localized)
Text(L10n.Mine.title.localized)
Text(L10n.Toast.featureInDevelopment.localized)
```

### 方法 3：直接使用 NSLocalizedString

```swift
Text(NSLocalizedString("tab.scanner", comment: "扫描"))
```

---

## 🔧 添加新的多语言文本

### 步骤 1：在 Localizable.strings 中添加翻译

**en.lproj/Localizable.strings**
```
"new.feature.title" = "New Feature";
"new.feature.description" = "This is a new feature";
```

**zh-Hans.lproj/Localizable.strings**
```
"new.feature.title" = "新功能";
"new.feature.description" = "这是一个新功能";
```

### 步骤 2：（可选）在 L10n 枚举中添加 Key

**LocalizationHelper.swift**
```swift
enum L10n {
    enum NewFeature {
        static let title = "new.feature.title"
        static let description = "new.feature.description"
    }
}
```

### 步骤 3：在代码中使用

```swift
Text(L10n.NewFeature.title.localized)
Text(L10n.NewFeature.description.localized)
```

---

## 📋 需要迁移的页面清单

以下页面仍然使用硬编码中文，需要逐步迁移：

### 高优先级（用户常见）
- [ ] **HomeView** - 主页/扫描页
- [ ] **AnalysisResultView** - 扫描结果页
- [ ] **AnalysisLibraryView** - 相册页
- [ ] **EmergeView** - 显影页
- [ ] **AnalysisHistoryView** - 历史记录页

### 中优先级（设置和工具）
- [ ] **AnalysisSettingsView** - 分析设置页
- [ ] **PhotoPickerView** - 照片选择器
- [ ] **ClusterDetailView** - 聚类详情页
- [ ] **CollectedTagsView** - 标签库页

### 低优先级（实验室功能）
- [ ] **LabView** - 色彩实验室
- [ ] **SearchColorView** - 寻色功能
- [ ] **CalculateColorView** - 计算颜色
- [ ] **LookUpColorView** - 查找颜色
- [ ] **BatchProcessView** 的其他部分

---

## 🎯 迁移示例

### 示例 1：简单文本

**之前：**
```swift
Text("扫描")
```

**之后：**
```swift
Text(L10n.Tab.scanner.localized)
```

### 示例 2：带参数的文本

**Localizable.strings：**
```
"photo.count" = "共 %d 张照片";  // 中文
"photo.count" = "%d photos in total";  // 英文
```

**代码：**
```swift
Text("photo.count".localized(with: photoCount))
```

### 示例 3：枚举的 rawValue

**之前：**
```swift
enum DevelopmentMode: String {
    case tone = "色调模式"
    case shadow = "影调模式"
}
```

**之后：**
```swift
enum DevelopmentMode: String {
    case tone = "tone"
    case shadow = "shadow"
    
    var displayName: String {
        switch self {
        case .tone: return L10n.DevelopmentMode.tone.localized
        case .shadow: return L10n.DevelopmentMode.shadow.localized
        }
    }
}

// 使用
Text(mode.displayName)  // 而不是 mode.rawValue
```

---

## 🌍 测试多语言

### 方法 1：在模拟器中切换语言
1. 打开 **Settings** > **General** > **Language & Region**
2. 添加或切换到 **English** 或 **简体中文**
3. 重启 App 查看效果

### 方法 2：在 Xcode 中测试
1. 选择 Scheme > **Edit Scheme**
2. 选择 **Run** > **Options**
3. 在 **App Language** 中选择语言
4. 运行 App

### 方法 3：使用 Xcode Previews
```swift
#Preview {
    KitView()
        .environment(\.locale, .init(identifier: "en"))  // 英文
}

#Preview {
    KitView()
        .environment(\.locale, .init(identifier: "zh-Hans"))  // 中文
}
```

---

## 📝 命名规范

### Key 命名规则
- 使用小写字母和下划线
- 使用点号分隔层级
- 格式：`<模块>.<功能>.<描述>`

**示例：**
```
tab.scanner           // Tab Bar 的扫描标签
mine.cloud_album      // 我的页面的云相册
toast.feature_in_development  // Toast 提示消息
```

### L10n 枚举规则
- 使用 PascalCase 命名枚举
- 使用 camelCase 命名属性
- 按模块分组

**示例：**
```swift
enum L10n {
    enum Tab {
        static let scanner = "tab.scanner"
    }
    
    enum Mine {
        static let cloudAlbum = "mine.cloud_album"
    }
}
```

---

## 🔍 查找需要翻译的文本

使用以下命令查找硬编码的中文字符串：

```bash
# 查找所有包含中文的 Swift 文件
grep -r "[\u4e00-\u9fa5]" Project_Color/Views/*.swift

# 查找 Text() 中的中文
grep -r 'Text(".*[\u4e00-\u9fa5].*")' Project_Color/Views/*.swift
```

---

## 💡 最佳实践

### 1. 始终使用 L10n 枚举
- ✅ 类型安全，避免拼写错误
- ✅ 代码补全友好
- ✅ 重构时容易追踪

### 2. 为翻译添加注释
```swift
// 好的做法
"tab.scanner".localized(comment: "底部 Tab Bar 的扫描标签")

// 不好的做法
"tab.scanner".localized
```

### 3. 避免在代码中拼接字符串
```swift
// ❌ 不好
Text("共 \(count) 张照片")

// ✅ 好
Text("photo.count".localized(with: count))
```

### 4. 处理复数形式
对于英文，使用 `.stringsdict` 文件处理复数：

**Localizable.stringsdict**
```xml
<key>photo.count</key>
<dict>
    <key>NSStringLocalizedFormatKey</key>
    <string>%#@photos@</string>
    <key>photos</key>
    <dict>
        <key>NSStringFormatSpecTypeKey</key>
        <string>NSStringPluralRuleType</string>
        <key>NSStringFormatValueTypeKey</key>
        <string>d</string>
        <key>one</key>
        <string>%d photo</string>
        <key>other</key>
        <string>%d photos</string>
    </dict>
</dict>
```

---

## 🚀 下一步

1. **逐步迁移其他页面**：按优先级从高到低迁移
2. **添加更多语言**：如需支持繁体中文、日文等，创建对应的 `.lproj` 文件夹
3. **完善翻译**：请专业翻译人员审核英文翻译
4. **测试覆盖**：确保所有文本在两种语言下都正确显示

---

## 📞 需要帮助？

如果在实施过程中遇到问题：
1. 查看已完成的示例（MainTabView, KitView）
2. 参考 Apple 官方文档：[Localization](https://developer.apple.com/documentation/xcode/localization)
3. 检查 `LocalizationHelper.swift` 中的辅助方法

---

**最后更新：** 2025-12-13
**当前进度：** 主要页面已完成，其他页面待迁移

