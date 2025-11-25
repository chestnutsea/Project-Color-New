# Qwen API 迁移到 Function Compute

## 概述

已将 Qwen API 调用从阿里云 DashScope 迁移到自定义的 Function Compute 端点。

## 更改内容

### 1. APIConfig.swift

**更改前：**
```swift
var qwenEndpoint: String {
    return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
}
```

**更改后：**
```swift
var qwenEndpoint: String {
    return "https://qwen-api-wvqmvfqpfy.cn-hangzhou.fcapp.run"
}
```

### 2. QwenVLService.swift

**主要更改：**
- ✅ 移除了 API Key 验证逻辑
- ✅ 移除了 Authorization header
- ✅ 保留了 Content-Type: application/json header

**更改前：**
```swift
// 验证 API Key
guard apiConfig.isQwenAPIKeyValid else {
    throw QwenError.invalidAPIKey
}

var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
request.setValue("Bearer \(apiConfig.qwenAPIKey)", forHTTPHeaderField: "Authorization")
```

**更改后：**
```swift
var request = URLRequest(url: url)
request.httpMethod = "POST"
request.setValue("application/json", forHTTPHeaderField: "Content-Type")
// Function Compute endpoint doesn't require Authorization header
```

## 请求格式

Function Compute 端点接收的请求格式：

```json
{
  "messages": [
    {
      "role": "user",
      "content": "Hello from Swift App!"
    }
  ]
}
```

## 兼容性

- ✅ 保持了原有的 `VisionChatRequest` 数据结构
- ✅ 保持了原有的 `ChatResponse` 解析逻辑
- ✅ 保持了原有的错误处理机制
- ✅ 不需要修改 `ColorAnalysisEvaluator.swift`

## 测试

运行测试脚本：

```bash
swift test_fc_endpoint.swift
```

或在 Xcode 中直接运行应用，使用照片分析功能测试 AI 评价。

## 注意事项

1. **不再需要 API Key**：Function Compute 端点不需要 Authorization header
2. **端点 URL**：确保 Function Compute 服务正常运行
3. **超时设置**：保持原有的 90 秒请求超时和 180 秒资源超时
4. **错误处理**：保持原有的错误处理逻辑，包括网络错误、解析错误等

## 文件清单

### 已修改文件
- ✅ `Project_Color/Config/APIConfig.swift`
- ✅ `Project_Color/Services/AI/QwenVLService.swift`

### 测试文件
- ✅ `test_fc_endpoint.swift` (新建)

### 未修改文件（无需修改）
- `Project_Color/Services/AI/ColorAnalysisEvaluator.swift`
- `Project_Color/Services/ColorAnalysis/SimpleAnalysisPipeline.swift`

## 后续步骤

1. 在 Xcode 中编译项目，确保没有编译错误
2. 运行应用，测试照片分析功能
3. 检查 Console 日志，确认请求发送到正确的端点
4. 验证 AI 评价功能正常工作

## 回滚方案

如需回滚到原有的 DashScope API：

```swift
// APIConfig.swift
var qwenEndpoint: String {
    return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
}

// QwenVLService.swift - 在 analyzeImages 方法中添加：
guard apiConfig.isQwenAPIKeyValid else {
    throw QwenError.invalidAPIKey
}

request.setValue("Bearer \(apiConfig.qwenAPIKey)", forHTTPHeaderField: "Authorization")
```

