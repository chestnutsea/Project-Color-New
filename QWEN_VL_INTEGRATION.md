# Qwen3-VL-Flash 集成说明

## 概述

已成功将 AI 分析从 DeepSeek 迁移到阿里云的 Qwen3-VL-Flash 视觉模型。新实现直接上传压缩后的用户照片进行分析，而不是传输文本数据。

## 主要变更

### 1. 新增文件

- **`Project_Color/Services/AI/QwenVLService.swift`**
  - Qwen3-VL-Flash API 客户端
  - 支持多图片上传（base64 编码）
  - 自动压缩图片为 JPEG 格式（质量 0.7）

### 2. 修改文件

- **`Project_Color/Config/APIConfig.swift`**
  - 添加 Qwen API 配置
  - API Key 从环境变量 `QWEN_API_KEY` 读取
  - API 端点：`https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions`

- **`Project_Color/Services/AI/ColorAnalysisEvaluator.swift`**
  - 改用 `QwenVLService` 替代 `DeepSeekService`
  - 接收压缩图片数组作为参数
  - 简化 Prompt，让 AI 直接观察照片

- **`Project_Color/Services/ColorAnalysis/SimpleAnalysisPipeline.swift`**
  - 添加 `CompressedImageCollector` Actor（线程安全收集图片）
  - 在图片提取阶段同时收集压缩图片（300x300）
  - 并行执行风格分析和 AI 评价（不再串行）

## 配置步骤

### 1. 设置环境变量

在运行应用前，需要设置 Qwen API Key：

```bash
export QWEN_API_KEY="sk-de3d9cc09dcd47d3b22fd53418851081"
```

### 2. Xcode 配置（可选）

也可以在 Xcode 的 Scheme 中配置环境变量：

1. Product → Scheme → Edit Scheme...
2. Run → Arguments → Environment Variables
3. 添加：
   - Name: `QWEN_API_KEY`
   - Value: `sk-de3d9cc09dcd47d3b22fd53418851081`

## 工作流程

### 旧流程（DeepSeek）
```
1. 提取照片主色
2. 计算统计数据
3. 生成文本 Prompt（包含颜色数据、统计信息）
4. 上传文本到 DeepSeek
5. 串行执行：风格分析 → AI 评价
```

### 新流程（Qwen3-VL-Flash）
```
1. 提取照片主色 + 收集压缩图片（300x300）
2. 并行执行：
   a. 风格分析（本地计算）
   b. AI 评价（上传压缩图片到 Qwen）
3. 两个任务独立完成，互不阻塞
```

## 性能优化

### 并行处理
- **图片收集**：在颜色提取阶段同步进行，无额外开销
- **AI 上传**：与风格分析并行，不增加总耗时
- **压缩格式**：JPEG 质量 0.7，平衡质量和大小

### 图片规格
- **尺寸**：300x300（与现有颜色分析一致）
- **格式**：JPEG
- **压缩质量**：0.7
- **编码**：base64（符合 Qwen API 要求）

## API 调用示例

```swift
let qwenService = QwenVLService.shared

let response = try await qwenService.analyzeImages(
    images: compressedImages,           // [UIImage]
    systemPrompt: "你是专业摄影评论家...",
    userPrompt: "请分析这组照片的整体风格",
    model: "qwen-vl-plus",
    temperature: 0.7,
    maxTokens: 2000
)
```

## 错误处理

### API Key 未配置
```
⚠️ QWEN_API_KEY not found in environment or build settings
```

**解决方法**：按照"配置步骤"设置环境变量

### 图片压缩失败
```
⚠️ 图片 X 压缩失败，跳过
```

**影响**：该图片不会上传，但不影响其他图片

### API 调用失败
```
⚠️ AI 评价失败: [错误信息]
```

**影响**：AI 评价部分显示错误，但不影响颜色分析结果

## 调试日志

启用详细日志查看执行过程：

```
📦 收集到 X 张压缩图片用于 AI 分析
🖼️ 开始压缩和编码 X 张图片...
   ✓ 图片 1/X 编码完成 (XX KB)
📤 发送请求到 Qwen API...
📥 收到响应，状态码: 200
✅ Qwen API 调用成功
   Token 使用: XXX + XXX = XXX
```

## 与 DeepSeek 的对比

| 特性 | DeepSeek | Qwen3-VL-Flash |
|------|----------|----------------|
| 输入方式 | 文本（统计数据） | 图片（视觉内容） |
| 分析依据 | 颜色统计、数值 | 直接观察照片 |
| 执行方式 | 串行（等待风格分析） | 并行（同时进行） |
| API Key 配置 | Build Settings | 环境变量 |
| 模型类型 | 文本模型 | 视觉模型 |

## 注意事项

1. **API Key 安全**：
   - 不要将 API Key 硬编码到代码中
   - 使用环境变量或 Xcode Secrets

2. **图片数量限制**：
   - Qwen API 可能对单次请求的图片数量有限制
   - 当前实现上传所有分析的照片

3. **网络流量**：
   - 上传压缩图片会产生网络流量
   - 建议在 WiFi 环境下使用

4. **成本控制**：
   - 每次分析都会调用 API（产生费用）
   - 注意监控 API 使用量

## 未来优化方向

1. **智能采样**：
   - 当照片数量过多时，智能选择代表性照片上传
   - 例如：每个聚类选择 2-3 张代表照片

2. **缓存机制**：
   - 缓存 AI 评价结果
   - 避免重复分析相同照片集

3. **进度反馈**：
   - 显示图片上传进度
   - 实时反馈 AI 分析状态

4. **降级策略**：
   - API 失败时使用本地统计数据生成评价
   - 提供离线分析能力

## 版本信息

- **实现日期**：2025-11-22
- **Qwen 模型**：qwen-vl-plus
- **API 版本**：compatible-mode/v1
- **集成方式**：完全替换 DeepSeek

