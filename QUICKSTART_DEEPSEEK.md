# DeepSeek Integration - Quick Start Guide

## 🚀 快速开始

### 1. 打开 Xcode 项目

```bash
open Project_Color.xcodeproj
```

### 2. 添加新文件到项目

需要将以下新文件添加到 Xcode 项目中：

#### 方法 A: 使用脚本提示（推荐）

```bash
./add_deepseek_files_to_xcode.sh
```

然后按照屏幕提示操作。

#### 方法 B: 手动添加

1. **创建 AI 文件夹**
   - 在 Xcode 的 Project Navigator 中
   - 右键点击 `Services` 文件夹
   - 选择 "New Group"
   - 命名为 `AI`

2. **添加 AI 服务文件**
   - 右键点击 `Services/AI` 组
   - 选择 "Add Files to 'Project_Color'..."
   - 导航到 `Project_Color/Services/AI/`
   - 选择这两个文件：
     - `DeepSeekService.swift`
     - `ColorAnalysisEvaluator.swift`
   - 确保 **不要** 勾选 "Copy items if needed"
   - 确保勾选 `Project_Color` target
   - 点击 "Add"

3. **添加配置文件**
   - 右键点击 `Config` 文件夹
   - 选择 "Add Files to 'Project_Color'..."
   - 导航到 `Project_Color/Config/`
   - 选择 `APIConfig.swift`
   - 确保 **不要** 勾选 "Copy items if needed"
   - 确保勾选 `Project_Color` target
   - 点击 "Add"

4. **添加测试文件（可选）**
   - 右键点击 `Test` 文件夹
   - 选择 "Add Files to 'Project_Color'..."
   - 导航到 `Project_Color/Test/`
   - 选择 `DeepSeekIntegrationTest.swift`
   - 添加到项目

### 3. 配置 API Key

#### 方法 A: Build Settings（推荐）

1. 在 Xcode 中选择项目（最顶部的蓝色图标）
2. 选择 `Project_Color` target
3. 点击 "Build Settings" 标签
4. 点击顶部的 `+` 按钮
5. 选择 "Add User-Defined Setting"
6. 输入：
   - **Name**: `DEEPSEEK_API_KEY`
   - **Value**: `sk-02551e4b861b4d7abb754abef5d73ae5`

#### 方法 B: 使用 xcconfig 文件

1. 选择项目 → Info 标签
2. 在 Configurations 下展开 Debug 和 Release
3. 为两个配置设置 configuration file 为 `Secrets`

### 4. 构建项目

```
Cmd + B
```

如果构建成功，说明集成完成！

### 5. 测试功能

1. 运行应用（Cmd + R）
2. 选择一些照片进行分析
3. 分析完成后，点击 "**AI评价**" 标签
4. 应该看到 AI 生成的色彩评价

## ✅ 验证集成

### 检查 API Key 配置

在 `Project_ColorApp.swift` 或任何 View 中添加：

```swift
import SwiftUI

@main
struct Project_ColorApp: App {
    init() {
        // 验证 API Key
        let config = APIConfig.shared
        print("🔑 API Key 已配置: \(config.isAPIKeyValid)")
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 运行测试

在任何 View 中添加测试按钮：

```swift
Button("测试 DeepSeek API") {
    Task {
        await DeepSeekIntegrationTest.runAllTests()
    }
}
```

查看控制台输出，应该看到：
- ✅ API Config is valid
- ✅ API Request Successful
- ✅ Evaluation Successful

## 🎨 功能说明

### 自动触发

AI 评价会在照片分析完成后自动触发，无需用户手动操作。

### 评价内容

1. **整体色彩评价**：分析所有照片的整体色彩构成
   - 色调分布
   - 饱和度特征
   - 明度层次

2. **各色系评价**：对每个识别的色系进行单独评价
   - 视觉特征
   - 情感表达
   - 色彩属性

### UI 状态

- **加载中**：显示进度指示器和"AI 正在分析色彩组成..."
- **成功**：显示完整的评价卡片
- **失败**：显示错误信息和重试按钮

## 🔧 常见问题

### Q: 构建失败，提示找不到 DeepSeekService

**A**: 确保已将新文件添加到 Xcode 项目中。检查 Project Navigator 中是否能看到这些文件。

### Q: 运行时提示 "API Key 无效或未配置"

**A**: 
1. 检查 Build Settings 中是否添加了 `DEEPSEEK_API_KEY`
2. 确保 API Key 以 `sk-` 开头
3. Clean Build Folder (Cmd+Shift+K) 后重新构建

### Q: API 请求失败

**A**:
1. 检查网络连接
2. 验证 API Key 在 DeepSeek 平台是否有效
3. 查看控制台的详细错误信息

### Q: 评价内容显示不完整

**A**: 
1. 检查 ScrollView 是否正常工作
2. 查看控制台是否有截断警告
3. 尝试重新生成评价（点击重试按钮）

## 📚 更多信息

- **详细文档**: `DeepSeek_Integration_Summary.md`
- **配置说明**: `Project_Color/Config/README.md`
- **API 文档**: https://platform.deepseek.com/docs

## 🎯 下一步

1. **测试多种照片集**：测试不同色彩风格的照片
2. **调整提示词**：根据需要修改 `ColorAnalysisEvaluator.swift` 中的提示词
3. **监控 API 使用**：查看控制台的 token 使用情况
4. **添加自定义功能**：基于现有代码扩展功能

## 💡 提示

- AI 评价在后台运行，不会阻塞分析流程
- 评价失败不影响其他功能
- 可以多次重试评价
- Token 使用情况会打印在控制台

---

**集成完成！** 🎉

如有问题，请查看控制台日志或参考详细文档。

