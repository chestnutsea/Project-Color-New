# InfoPlist.strings 本地化设置完成

## ✅ 已完成的工作

### 1. 创建本地化文件夹
```
Project_Color/
├── en.lproj/
│   └── InfoPlist.strings  （英文版本）
└── zh-Hans.lproj/
    └── InfoPlist.strings  （简体中文版本）
```

### 2. 英文版本内容 (en.lproj/InfoPlist.strings)
```
NSPhotoLibraryUsageDescription = "Feelm needs access to your photo library to process analysis.";
NSPhotoLibraryAddUsageDescription = "Feelm needs access to save analysis results to your photo library.";
CFBundleDisplayName = "Feelm";
CFBundleName = "Feelm";
```

### 3. 中文版本内容 (zh-Hans.lproj/InfoPlist.strings)
```
NSPhotoLibraryUsageDescription = "Feelm 需要访问您的相册以分析照片。";
NSPhotoLibraryAddUsageDescription = "Feelm 需要访问您的相册以保存分析结果。";
CFBundleDisplayName = "知色";
CFBundleName = "知色";
```

### 4. Xcode 项目配置
- ✅ 添加到 PBXFileReference
- ✅ 创建 PBXVariantGroup
- ✅ 添加到 Resources Build Phase
- ✅ 添加到异常列表（membershipExceptions）
- ✅ 配置 knownRegions：en, zh-Hans

---

## 📱 效果说明

### 相册权限提示语
- **英文系统**：显示 "Feelm needs access to your photo library to process analysis."
- **中文系统**：显示 "Feelm 需要访问您的相册以分析照片。"

### 应用显示名称
- **英文系统**：显示 "Feelm"
- **中文系统**：显示 "知色"

---

## 🔍 如何验证

### 方法 1：在 Xcode 中验证
1. 打开 Xcode
2. 在项目导航器中查找 `InfoPlist.strings`
3. 应该看到它是一个 **可展开的文件组**
4. 展开后应该显示：
   - English
   - Chinese (Simplified)

### 方法 2：在模拟器/真机上测试
1. **删除应用**（如果已安装）
2. 重新运行项目
3. **测试相册权限提示**：
   - 切换系统语言到英文 → 检查权限提示
   - 切换系统语言到中文 → 检查权限提示
4. **测试应用名称**：
   - 查看主屏幕上的应用图标下方的名称

### 方法 3：检查编译后的 Bundle
```bash
# 在编译后的 .app 包中查找
cd ~/Library/Developer/Xcode/DerivedData/Project_Color-*/Build/Products/Debug-iphonesimulator/Project_Color.app

# 查看本地化文件
ls -la en.lproj/
ls -la zh-Hans.lproj/
```

---

## 🎯 后续步骤

### 1. 在 Xcode 中验证
```bash
# 打开项目
open Project_Color.xcodeproj
```

在 Xcode 中：
1. 选中 `Project_Color` 项目
2. 在 **Project** 设置中，查看 **Localizations** 部分
3. 应该看到：
   - ✅ English
   - ✅ Chinese (Simplified)

### 2. 运行测试
1. 选择模拟器或真机
2. 点击运行（Cmd + R）
3. 首次运行时应该会弹出相册权限请求
4. 检查提示文字是否正确本地化

### 3. 切换语言测试
**在模拟器中切换语言：**
- Settings → General → Language & Region → iPhone Language
- 选择不同语言后重启应用

**在真机中切换语言：**
- 设置 → 通用 → 语言与地区 → iPhone 语言
- 选择不同语言后重启应用

---

## ⚠️ 注意事项

### 1. Info.plist 中的原始值
`Info.plist` 中的原始值会被 `InfoPlist.strings` 的本地化值**覆盖**：

```xml
<!-- Info.plist 中的这些值会被 InfoPlist.strings 覆盖 -->
<key>NSPhotoLibraryUsageDescription</key>
<string>Feelm requires access to your photo library to process analysis.</string>
```

实际显示时，系统会：
1. 检查当前语言
2. 查找对应的 `InfoPlist.strings` 文件
3. 使用本地化后的值

### 2. Key 必须完全一致
InfoPlist.strings 中的 Key 必须与系统 Key **完全一致**（包括大小写）：
- ✅ `NSPhotoLibraryUsageDescription`
- ❌ `nsPhotoLibraryUsageDescription`
- ❌ `PhotoLibraryUsageDescription`

### 3. 文件编码
确保 `InfoPlist.strings` 文件使用 **UTF-8 编码**，否则中文字符可能无法正确显示。

### 4. 清理构建
如果本地化没有生效，尝试：
```bash
# 清理构建缓存
# Xcode: Product → Clean Build Folder (Shift + Cmd + K)
```

---

## 🛠️ 故障排除

### 问题 1：本地化没有生效
**解决方案：**
1. 确认文件路径正确：
   ```
   Project_Color/en.lproj/InfoPlist.strings
   Project_Color/zh-Hans.lproj/InfoPlist.strings
   ```
2. 确认 Xcode 项目中已正确引用
3. 清理构建并重新编译

### 问题 2：中文显示乱码
**解决方案：**
1. 确认文件编码为 UTF-8
2. 在终端中检查：
   ```bash
   file -I Project_Color/zh-Hans.lproj/InfoPlist.strings
   ```
   应该显示：`charset=utf-8`

### 问题 3：应用名称没有本地化
**解决方案：**
1. 确认 `CFBundleDisplayName` 在 InfoPlist.strings 中
2. 卸载应用后重新安装
3. 检查系统语言设置

---

## 📚 相关文档

- [Apple 官方文档：Localization](https://developer.apple.com/documentation/xcode/localization)
- [Info.plist Key Reference](https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Introduction/Introduction.html)
- [Internationalizing Your App](https://developer.apple.com/documentation/xcode/localization/localizing-your-app)

---

## ✨ 完成！

您的应用现在已经配置好本地化支持：
- ✅ 相册权限提示语支持中英文
- ✅ 应用名称支持中英文（Feelm / 知色）
- ✅ Xcode 项目配置完成
- ✅ 文件结构符合 Apple 规范

现在可以在 Xcode 中打开项目并运行测试了！

