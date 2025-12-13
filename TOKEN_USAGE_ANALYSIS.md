# Token 使用统计原理与测试指南

## 📊 问题描述

当前应用显示：`⚠️ 未收到 Token 使用统计信息（可能 API 未返回 usage 字段）`

## 🔍 Token 消耗的原理

### 1. API 响应中的 `usage` 字段

Token 使用统计依赖于 API 响应中的 `usage` 字段，标准格式如下：

```json
{
  "id": "chatcmpl-xxx",
  "object": "chat.completion",
  "created": 1234567890,
  "model": "qwen-vl-plus",
  "choices": [...],
  "usage": {
    "prompt_tokens": 150,      // 输入 tokens（包括图片）
    "completion_tokens": 50,   // 输出 tokens
    "total_tokens": 200        // 总计
  }
}
```

### 2. 流式模式 vs 非流式模式

#### 非流式模式 (`stream: false`)

```swift
// 响应格式
{
  "choices": [...],
  "usage": { ... }  // ✅ 包含在响应中
}
```

- **特点**：一次性返回完整响应
- **usage 位置**：直接在响应 JSON 的顶层
- **代码路径**：`QwenVLService.analyzeImages()` → 第 454-467 行

```swift:454:467:/Users/linyahuang/Project_Color/Project_Color/Services/AI/QwenVLService.swift
if let usage = chatResponse.usage {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("✅ Qwen API 调用成功")
    print("   📌 实际使用模型: \(chatResponse.model)")
    print("📊 AI 生成 Token 使用统计:")
    print("   📤 上传 (输入/Prompt): \(usage.promptTokens) tokens")
    print("   📥 下载 (输出/Completion): \(usage.completionTokens) tokens")
    print("   📦 总计 (Total): \(usage.totalTokens) tokens")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
} else {
    print("✅ Qwen API 调用成功")
    print("   📌 实际使用模型: \(chatResponse.model)")
    print("⚠️ 未收到 Token 使用统计信息（API 响应中未包含 usage 字段）")
}
```

#### 流式模式 (`stream: true`) 

```swift
// SSE 数据流格式
data: {"choices": [{"delta": {"content": "你"}}]}
data: {"choices": [{"delta": {"content": "好"}}]}
data: {"choices": [{"delta": {"content": "！"}}]}
data: {"choices": [...], "usage": {...}}  // ❓ 可能在最后一个响应中
data: [DONE]
```

- **特点**：逐个 token 实时返回
- **usage 位置**：
  - **OpenAI 格式**：在最后一个 SSE 事件中
  - **部分 API**：可能不返回 usage
  - **Qwen API**：需要测试确认
- **代码路径**：`SSEClient.processSSELine()` → 第 159-166 行

```swift:159:166:/Users/linyahuang/Project_Color/Project_Color/Services/AI/SSEClient.swift
// 检查是否包含 usage 信息（通常在最后一个响应中）
if let usage = json["usage"] as? [String: Any],
   let promptTokens = usage["prompt_tokens"] as? Int,
   let completionTokens = usage["completion_tokens"] as? Int,
   let totalTokens = usage["total_tokens"] as? Int {
    // Token 统计会在 QwenVLService 中统一打印，这里只记录
    onUsage?(promptTokens, completionTokens, totalTokens)
}
```

### 3. 当前实现的处理流程

```
┌─────────────────────────────────────────────────────────────┐
│ QwenVLService.analyzeImagesStreaming()                      │
│                                                             │
│ 1. 构建请求体 (stream: true)                                │
│ 2. 创建 SSEClient                                            │
│ 3. 设置回调：                                                │
│    - onToken: 处理每个 token                                 │
│    - onUsage: 处理 usage 统计                                │
│    - onComplete: 完成时打印统计                              │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ SSEClient.connect()                                         │
│                                                             │
│ 1. 建立 URLSession 连接                                      │
│ 2. 接收 SSE 数据流                                           │
│ 3. 逐行解析：                                                │
│    data: {...} → JSON 解析                                   │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ SSEClient.processSSELine()                                  │
│                                                             │
│ 检查每个 JSON 响应：                                         │
│ ✓ 提取 content 字段 → 调用 onToken                          │
│ ✓ 提取 usage 字段 → 调用 onUsage                            │
└─────────────────────────────────────────────────────────────┘
                           ↓
┌─────────────────────────────────────────────────────────────┐
│ QwenVLService onComplete 回调                               │
│                                                             │
│ if promptTokens != nil {                                    │
│     打印 usage 统计 ✅                                        │
│ } else {                                                    │
│     打印警告 ⚠️ 未收到统计                                    │
│ }                                                           │
└─────────────────────────────────────────────────────────────┘
```

## 🧪 测试方法

### 方法 1: 使用提供的测试脚本

我已经创建了一个专门的测试脚本：`test_api_usage_response.swift`

```bash
# 设置 API Key
export DASHSCOPE_API_KEY="your-api-key"

# 运行测试
chmod +x test_api_usage_response.swift
swift test_api_usage_response.swift
```

**测试内容：**

1. **测试 1：流式模式（文本）**
   - 发送简单文本提示
   - 捕获所有 SSE 数据块
   - 检查是否包含 `usage` 字段

2. **测试 2：非流式模式（文本）**
   - 发送简单文本提示
   - 检查完整响应中的 `usage` 字段

3. **测试 3：流式模式（图片）**
   - 发送带图片的视觉任务
   - 检查 `usage` 字段的位置和时机

**测试输出示例：**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧪 测试 1: 流式模式 (stream=true)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

📤 发送请求...
   模型: qwen-vl-plus
   流式: true

✅ 收到响应
   状态码: 200

[1] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
  "id" : "chatcmpl-xxx",
  "choices" : [{
    "delta" : { "content" : "你" }
  }]
}

[2] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
  "id" : "chatcmpl-xxx",
  "choices" : [{
    "delta" : { "content" : "好" }
  }]
}

[15] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
{
  "id" : "chatcmpl-xxx",
  "choices" : [{
    "delta" : {},
    "finish_reason" : "stop"
  }],
  "usage" : {
    "prompt_tokens" : 10,
    "completion_tokens" : 5,
    "total_tokens" : 15
  }
}

🎯 发现 usage 字段！
   prompt_tokens: 10
   completion_tokens: 5
   total_tokens: 15

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 流式模式测试结果:
   总数据块数: 16
   是否包含 usage: ✅ 是
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 方法 2: 使用 curl 命令测试

#### 测试流式模式

```bash
export DASHSCOPE_API_KEY="your-api-key"

curl -X POST https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
  -H "Accept: text/event-stream" \
  -d '{
    "model": "qwen-vl-plus",
    "messages": [
      {"role": "user", "content": "你好"}
    ],
    "stream": true
  }' | tee stream_response.log
```

#### 测试非流式模式

```bash
curl -X POST https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
  -d '{
    "model": "qwen-vl-plus",
    "messages": [
      {"role": "user", "content": "你好"}
    ],
    "stream": false
  }' | jq '.' | tee non_stream_response.json

# 检查 usage 字段
jq '.usage' non_stream_response.json
```

### 方法 3: 在应用中添加调试日志

修改 `SSEClient.swift`，添加原始数据打印：

```swift
private func processSSELine(_ line: String) {
    if line.hasPrefix("data: ") {
        let jsonString = String(line.dropFirst(6))
        
        // 🔍 添加这行：打印原始 JSON
        print("🔍 原始 SSE JSON: \(jsonString)")
        
        if jsonString == "[DONE]" {
            print("📡 SSE 流式传输完成")
            onComplete?()
            return
        }
        
        // ... 其余代码
    }
}
```

## 🎯 可能的原因分析

### 原因 1: API 在流式模式下不返回 usage

**可能性：⭐⭐⭐⭐⭐ 最可能**

某些 API 提供商在流式模式下不返回 `usage` 字段，因为：
- 流式响应为了减少延迟，可能省略统计信息
- Token 统计需要完整的响应才能计算

**解决方案：**
1. 查看 Qwen API 官方文档
2. 联系 API 提供商确认
3. 考虑使用非流式模式获取统计

### 原因 2: 需要特定参数才能获取 usage

**可能性：⭐⭐⭐**

OpenAI API 在流式模式下需要添加 `stream_options` 参数：

```json
{
  "model": "gpt-4",
  "messages": [...],
  "stream": true,
  "stream_options": {
    "include_usage": true  // 📌 关键参数
  }
}
```

**修改建议（QwenVLService.swift）：**

```swift
let requestBody: [String: Any] = [
    "model": selectedModel.rawValue,
    "messages": messages,
    "stream": true,
    "temperature": temperature,
    "max_tokens": maxTokens,
    "stream_options": [              // 🆕 添加这个
        "include_usage": true
    ]
]
```

### 原因 3: usage 字段在不同位置

**可能性：⭐⭐**

某些 API 可能将 `usage` 放在不同的位置：

```json
// 可能的位置 1：顶层（当前代码支持）
{
  "usage": {...}
}

// 可能的位置 2：choices 内部
{
  "choices": [{
    "usage": {...}
  }]
}

// 可能的位置 3：metadata 字段
{
  "metadata": {
    "usage": {...}
  }
}
```

### 原因 4: 视觉模型的特殊行为

**可能性：⭐⭐**

视觉模型（qwen-vl-plus）可能与纯文本模型行为不同：
- 图片 token 计算复杂
- 可能需要特殊参数
- 可能只在非流式模式下提供

## 📝 建议的行动步骤

### 步骤 1: 运行测试脚本

```bash
cd /Users/linyahuang/Project_Color
export DASHSCOPE_API_KEY="your-api-key"
swift test_api_usage_response.swift
```

查看输出，确认：
- ✅ 流式模式是否返回 `usage`
- ✅ 非流式模式是否返回 `usage`
- ✅ 视觉模型是否返回 `usage`
- ✅ `usage` 字段出现在哪个位置

### 步骤 2: 根据测试结果修改代码

**情况 A：流式模式不返回 usage**

选项 1 - 切换到非流式模式（仅用于统计）：

```swift
// 在需要统计的场景使用非流式
let response = try await analyzeImages(
    images: images,
    systemPrompt: systemPrompt,
    userPrompt: userPrompt,
    stream: false  // 获取 usage
)
```

选项 2 - 本地估算 token 数量：

```swift
// 添加 token 估算工具
struct TokenEstimator {
    static func estimate(text: String, images: [UIImage]) -> (prompt: Int, completion: Int) {
        // 文本：约 1 token = 4 个字符（中文约 1.5-2 字符）
        let textTokens = text.count / 2
        
        // 图片：根据分辨率估算
        let imageTokens = images.reduce(0) { sum, image in
            let pixels = image.size.width * image.size.height
            // Qwen-VL: 约每 784 像素 = 1 token
            return sum + Int(pixels / 784)
        }
        
        return (textTokens + imageTokens, 0)
    }
}
```

**情况 B：需要添加 stream_options 参数**

修改 `QwenVLService.swift`：

```swift
let requestBody: [String: Any] = [
    "model": selectedModel.rawValue,
    "messages": messages,
    "stream": true,
    "temperature": temperature,
    "max_tokens": maxTokens,
    "stream_options": [
        "include_usage": true
    ]
]
```

**情况 C：usage 在不同位置**

修改 `SSEClient.swift` 添加多位置检查：

```swift
private func processSSELine(_ line: String) {
    if line.hasPrefix("data: ") {
        let jsonString = String(line.dropFirst(6))
        // ... 省略
        
        if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
            // 检查多个可能的位置
            var usage: [String: Any]?
            
            // 位置 1：顶层
            if let topUsage = json["usage"] as? [String: Any] {
                usage = topUsage
            }
            // 位置 2：choices 内部
            else if let choices = json["choices"] as? [[String: Any]],
                    let firstChoice = choices.first,
                    let choiceUsage = firstChoice["usage"] as? [String: Any] {
                usage = choiceUsage
            }
            // 位置 3：metadata
            else if let metadata = json["metadata"] as? [String: Any],
                    let metaUsage = metadata["usage"] as? [String: Any] {
                usage = metaUsage
            }
            
            if let usage = usage,
               let promptTokens = usage["prompt_tokens"] as? Int,
               let completionTokens = usage["completion_tokens"] as? Int,
               let totalTokens = usage["total_tokens"] as? Int {
                onUsage?(promptTokens, completionTokens, totalTokens)
            }
        }
    }
}
```

### 步骤 3: 查阅官方文档

**Qwen API 文档位置：**
- 官方文档：https://help.aliyun.com/zh/dashscope/
- API 参考：https://help.aliyun.com/zh/dashscope/developer-reference/api-details
- 视觉模型文档：https://help.aliyun.com/zh/dashscope/developer-reference/qwen-vl-plus-api

**需要确认的问题：**
1. 流式模式是否支持 `usage` 返回？
2. 是否需要特定参数（如 `stream_options`）？
3. 视觉模型的 token 计算规则是什么？
4. `usage` 字段的具体位置和格式？

### 步骤 4: 添加降级方案

即使无法获取精确的 usage，也可以提供大致估算：

```swift
// 在 QwenVLService 中添加
func estimateTokenUsage(
    systemPrompt: String,
    userPrompt: String,
    images: [UIImage],
    response: String
) -> (prompt: Int, completion: Int, total: Int) {
    
    // 文本 token 估算（中文约 1.5 字符/token，英文约 4 字符/token）
    let promptText = systemPrompt + userPrompt
    let avgCharsPerToken = 2.0  // 混合中英文平均值
    let promptTokens = Int(Double(promptText.count) / avgCharsPerToken)
    let completionTokens = Int(Double(response.count) / avgCharsPerToken)
    
    // 图片 token 估算（Qwen-VL 规则）
    let imageTokens = images.reduce(0) { sum, image in
        // Qwen-VL: 256x256 = 256 tokens, 按比例计算
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let pixels = width * height
        return sum + Int(pixels / 256.0)  // 每 256 像素约 1 token
    }
    
    let totalPrompt = promptTokens + imageTokens
    let total = totalPrompt + completionTokens
    
    return (totalPrompt, completionTokens, total)
}

// 使用方式
if promptTokens == nil {
    // 如果 API 没有返回 usage，使用估算
    let estimated = estimateTokenUsage(
        systemPrompt: systemPrompt,
        userPrompt: userPrompt,
        images: images,
        response: fullResponse
    )
    
    print("📊 AI 生成 Token 使用统计（估算）:")
    print("   📤 上传 (输入/Prompt): ~\(estimated.prompt) tokens")
    print("   📥 下载 (输出/Completion): ~\(estimated.completion) tokens")
    print("   📦 总计 (Total): ~\(estimated.total) tokens")
    print("   ⚠️  注意：以上为估算值，仅供参考")
}
```

## 🔗 相关文件

- **SSE 客户端**：`Project_Color/Services/AI/SSEClient.swift`（第 159-166 行）
- **Qwen 服务**：`Project_Color/Services/AI/QwenVLService.swift`（第 245-287 行）
- **测试脚本**：`test_api_usage_response.swift`

## 📚 参考资料

1. **OpenAI API - Stream Options**
   - https://platform.openai.com/docs/api-reference/chat/create#chat-create-stream_options

2. **Server-Sent Events (SSE) 规范**
   - https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events

3. **Token 计算规则**
   - OpenAI Tokenizer: https://platform.openai.com/tokenizer
   - Qwen Token 计算：需查阅官方文档

## ✅ 下一步

1. ✅ 运行 `test_api_usage_response.swift` 测试脚本
2. ⏳ 根据测试结果确定问题原因
3. ⏳ 实施相应的解决方案
4. ⏳ 添加 token 估算作为降级方案
5. ⏳ 更新用户界面显示 token 统计

