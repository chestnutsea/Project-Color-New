# Qwen3-VL-Flash 快速启动指南

## 🚀 5 分钟快速开始

### 步骤 1: 设置 API Key

在终端中运行：

```bash
export QWEN_API_KEY="sk-de3d9cc09dcd47d3b22fd53418851081"
```

**或者**在 Xcode 中配置：

1. Product → Scheme → Edit Scheme...
2. Run → Arguments → Environment Variables
3. 添加 `QWEN_API_KEY` = `sk-de3d9cc09dcd47d3b22fd53418851081`

### 步骤 2: 验证配置

```bash
cd /Users/linyahuang/Project_Color
./test_qwen_config.sh
```

应该看到：
```
✅ 环境变量 QWEN_API_KEY 已设置
✅ API Key 格式正确（以 sk- 开头）
✅ API Key 长度正常（XX 字符）
🎯 配置检查完成！
```

### 步骤 3: 运行应用

在 Xcode 中：
1. 打开 `Project_Color.xcodeproj`
2. 选择目标设备/模拟器
3. 点击 Run (⌘R)

### 步骤 4: 测试功能

1. 选择一个相册
2. 点击"开始分析"
3. 观察控制台输出：

```
📦 收集到 X 张压缩图片用于 AI 分析
🖼️ 开始压缩和编码 X 张图片...
   ✓ 图片 1/X 编码完成 (XX KB)
📤 发送请求到 Qwen API...
📥 收到响应，状态码: 200
✅ Qwen API 调用成功
```

4. 查看分析结果中的 AI 评价

## ✅ 成功标志

- 控制台显示 "✅ Qwen API 调用成功"
- 分析结果页面显示 AI 生成的评价文本
- 没有错误提示

## ❌ 常见问题

### 问题 1: API Key 未设置

**错误信息**:
```
⚠️ QWEN_API_KEY not found in environment or build settings
```

**解决方法**:
重新执行步骤 1，确保环境变量已设置

### 问题 2: API 调用失败

**错误信息**:
```
⚠️ AI 评价失败: API 错误: [详细信息]
```

**可能原因**:
- API Key 错误
- 网络连接问题
- API 配额用尽

**解决方法**:
1. 检查 API Key 是否正确
2. 检查网络连接
3. 查看阿里云控制台的 API 使用情况

### 问题 3: 图片上传失败

**错误信息**:
```
⚠️ 图片 X 压缩失败，跳过
```

**影响**: 该图片不会上传，但不影响其他图片

**解决方法**: 通常可以忽略，如果大量图片失败，检查照片权限

## 📚 更多信息

- **详细文档**: `QWEN_VL_INTEGRATION.md`
- **迁移总结**: `QWEN_MIGRATION_SUMMARY.md`
- **配置测试**: `./test_qwen_config.sh`

## 🎯 下一步

配置成功后，您可以：
1. 分析不同的相册，测试 AI 评价质量
2. 查看并行处理的性能提升
3. 根据需要调整 Prompt（在 `ColorAnalysisEvaluator.swift` 中）

---

**祝使用愉快！** 🎉

