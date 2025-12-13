# Token Usage 快速测试指南

## 🎯 问题

应用显示：`⚠️ 未收到 Token 使用统计信息（可能 API 未返回 usage 字段）`

## ⚡ 快速测试（3 分钟）

### 方法 1: 使用 Shell 脚本测试（推荐）

```bash
# 1. 设置 API Key
export DASHSCOPE_API_KEY="your-api-key-here"

# 2. 运行测试脚本
cd /Users/linyahuang/Project_Color
./test_qwen_usage.sh
```

**脚本会自动测试：**
- ✅ 流式模式是否返回 `usage`
- ✅ 非流式模式是否返回 `usage`
- ✅ 添加 `stream_options` 参数是否有效

**预期输出示例：**

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
🧪 测试 1: 流式模式 (stream=true)
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

✅ 收到响应

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📡 原始 SSE 数据流:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

[1]
{"id":"chatcmpl-xxx","choices":[{"delta":{"content":"你"}}]}

[15] 🎯 发现 usage 字段！
{
  "id": "chatcmpl-xxx",
  "choices": [...],
  "usage": {
    "prompt_tokens": 10,
    "completion_tokens": 5,
    "total_tokens": 15
  }
}

━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
📊 流式模式测试结果:
   总数据块数: 16
   是否包含 usage: ✅ 是
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

### 方法 2: 使用 curl 命令测试

```bash
# 测试流式模式
curl -X POST https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions \
  -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
  -H "Content-Type: application/json" \
  -H "Accept: text/event-stream" \
  -d '{
    "model": "qwen-vl-plus",
    "messages": [{"role": "user", "content": "你好"}],
    "stream": true
  }' | grep -i usage

# 如果看到输出，说明流式模式返回了 usage
# 如果没有输出，说明流式模式不返回 usage
```

```bash
# 测试非流式模式
curl -s -X POST https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions \
  -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen-vl-plus",
    "messages": [{"role": "user", "content": "你好"}],
    "stream": false
  }' | jq '.usage'

# 如果看到 usage 字段，说明非流式模式返回了 usage
```

## 📊 根据测试结果采取行动

### 情况 A：流式模式返回了 `usage` ✅

**说明：** API 正常，代码需要调试

**解决步骤：**

1. 检查 SSE 解析逻辑：

```swift
// 在 SSEClient.swift 的 processSSELine() 方法中添加调试日志
print("🔍 原始 SSE JSON: \(jsonString)")
```

2. 确认 `onUsage` 回调被正确调用：

```swift
// 在 QwenVLService.swift 的 onUsage 回调中添加日志
onUsage: { prompt, completion, total in
    print("🎯 收到 usage: prompt=\(prompt), completion=\(completion), total=\(total)")
    promptTokens = prompt
    completionTokens = completion
    totalTokens = total
    onUsage?(prompt, completion, total)
}
```

3. 重新运行应用测试

---

### 情况 B：只有非流式模式返回 `usage` ⚠️

**说明：** API 不支持流式模式下的 usage 统计

**解决方案选项：**

#### 选项 1：为统计切换到非流式模式

```swift
// 在需要精确统计的场景使用非流式
let result = try await qwenService.analyzeImages(
    images: images,
    systemPrompt: systemPrompt,
    userPrompt: userPrompt
    // 不使用流式模式
)
```

**优点：**
- ✅ 可以获取准确的 token 统计
- ✅ 代码改动小

**缺点：**
- ❌ 失去实时打字效果
- ❌ 响应感觉变慢

#### 选项 2：实现本地 Token 估算

添加到 `QwenVLService.swift`：

```swift
/// 估算 token 使用量（当 API 不返回 usage 时使用）
private func estimateTokenUsage(
    systemPrompt: String,
    userPrompt: String,
    images: [UIImage],
    response: String
) -> (prompt: Int, completion: Int, total: Int) {
    
    // 1. 文本 token 估算
    let promptText = systemPrompt + userPrompt
    let responseText = response
    
    // 中文：约 1.5 字符/token
    // 英文：约 4 字符/token
    // 混合：约 2 字符/token
    let avgCharsPerToken = 2.0
    
    let promptTextTokens = Int(Double(promptText.count) / avgCharsPerToken)
    let completionTokens = Int(Double(responseText.count) / avgCharsPerToken)
    
    // 2. 图片 token 估算
    // Qwen-VL 规则：根据图片分辨率计算
    // 参考：https://help.aliyun.com/zh/dashscope/developer-reference/qwen-vl-plus-api
    let imageTokens = images.reduce(0) { sum, image in
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let pixels = width * height
        
        // Qwen-VL: 每张图片约 256-1280 tokens，取决于分辨率
        // 简化估算：按 256x256 = 256 tokens 比例计算
        let estimatedTokens = Int(pixels / 256.0)
        return sum + max(256, min(1280, estimatedTokens))
    }
    
    let totalPrompt = promptTextTokens + imageTokens
    let total = totalPrompt + completionTokens
    
    return (totalPrompt, completionTokens, total)
}

// 在 onComplete 回调中使用
onComplete: { [weak self] in
    if let prompt = promptTokens, 
       let completion = completionTokens, 
       let total = totalTokens {
        // API 返回了 usage，使用精确值
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 AI 生成 Token 使用统计:")
        print("   📤 上传 (输入/Prompt): \(prompt) tokens")
        print("   📥 下载 (输出/Completion): \(completion) tokens")
        print("   📦 总计 (Total): \(total) tokens")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    } else {
        // API 未返回 usage，使用估算
        let estimated = self?.estimateTokenUsage(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            images: images,
            response: fullResponse
        )
        
        if let est = estimated {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 AI 生成 Token 使用统计（估算）:")
            print("   📤 上传 (输入/Prompt): ~\(est.prompt) tokens")
            print("   📥 下载 (输出/Completion): ~\(est.completion) tokens")
            print("   📦 总计 (Total): ~\(est.total) tokens")
            print("   ⚠️  注意：以上为本地估算值，仅供参考")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
    }
    onComplete()
    self?.currentSSEClient = nil
}
```

**优点：**
- ✅ 保留实时打字效果
- ✅ 提供大致的 token 消耗参考

**缺点：**
- ❌ 不够精确（误差约 10-20%）
- ❌ 需要维护估算算法

#### 选项 3：混合方案

```swift
/// 分析图片（带 token 统计选项）
func analyzeImagesWithUsage(
    images: [UIImage],
    systemPrompt: String,
    userPrompt: String,
    onToken: ((String) -> Void)? = nil,
    needAccurateUsage: Bool = false
) async throws -> (response: String, usage: (prompt: Int, completion: Int, total: Int)?) {
    
    if needAccurateUsage {
        // 需要精确统计，使用非流式模式
        let response = try await analyzeImages(
            images: images,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt
        )
        // 从响应中获取 usage...
        return (response, usage)
    } else {
        // 不需要精确统计，使用流式模式
        var fullResponse = ""
        try await analyzeImagesStreaming(
            images: images,
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            onToken: { token in
                fullResponse += token
                onToken?(token)
            },
            onComplete: {},
            onUsage: nil
        )
        
        // 使用估算
        let estimated = estimateTokenUsage(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            images: images,
            response: fullResponse
        )
        return (fullResponse, estimated)
    }
}
```

**使用场景：**
- UI 显示：使用流式模式 + 估算
- 成本统计/日志：使用非流式模式 + 精确 usage

---

### 情况 C：添加 `stream_options` 后返回 `usage` ✅

**说明：** 需要添加参数才能获取 usage

**修改 `QwenVLService.swift`：**

```swift
let requestBody: [String: Any] = [
    "model": selectedModel.rawValue,
    "messages": messages,
    "stream": true,
    "temperature": temperature,
    "max_tokens": maxTokens,
    // 🆕 添加这个参数
    "stream_options": [
        "include_usage": true
    ]
]
```

**测试步骤：**

1. 修改代码添加 `stream_options`
2. 重新编译运行
3. 查看控制台是否打印出 usage 统计

---

### 情况 D：所有模式都不返回 `usage` ❌

**说明：** API 端点或模型不支持 usage 统计

**可能原因：**
1. Qwen API 的 compatible-mode 端点可能不支持
2. 特定模型（qwen-vl-plus）可能不返回
3. 需要使用其他 API 端点

**解决步骤：**

1. **查阅官方文档**
   - Qwen API 文档：https://help.aliyun.com/zh/dashscope/
   - 搜索关键词：`usage`、`token`、`计费`

2. **尝试其他端点**
   ```bash
   # 尝试原生端点而非 compatible-mode
   curl -X POST https://dashscope.aliyuncs.com/api/v1/services/aigc/multimodal-generation/generation \
     -H "Authorization: Bearer $DASHSCOPE_API_KEY" \
     -H "Content-Type: application/json" \
     -d '{...}'
   ```

3. **联系技术支持**
   - 阿里云工单系统
   - DashScope 开发者社区

4. **实现降级方案**
   - 使用上面的本地估算方法
   - 或者记录请求参数，定期调用计费 API 查询

## 🔗 相关文件

- **详细分析**：`TOKEN_USAGE_ANALYSIS.md`
- **测试脚本（Shell）**：`test_qwen_usage.sh`
- **测试脚本（Swift）**：`test_api_usage_response.swift`
- **SSE 客户端**：`Project_Color/Services/AI/SSEClient.swift`
- **Qwen 服务**：`Project_Color/Services/AI/QwenVLService.swift`

## 📚 Qwen Token 计算规则参考

### 文本 Token

| 语言 | 约每 Token 字符数 |
|------|-------------------|
| 中文 | 1.5-2 字符 |
| 英文 | 4 字符 |
| 混合 | 2-2.5 字符 |

### 图片 Token（Qwen-VL）

根据官方文档，图片 token 计算规则：

```
最小：256 tokens（小图片）
最大：1280 tokens（高分辨率图片）
计算公式：基于图片的实际分辨率和压缩比例
```

**示例：**
- 400x400 图片 ≈ 625 tokens
- 800x600 图片 ≈ 1280 tokens（达到上限）
- 200x200 图片 ≈ 256 tokens（达到下限）

## ✅ 推荐方案

基于大多数场景，推荐使用 **混合方案**：

1. **常规 UI 使用**：流式模式 + 本地估算
   - 用户体验好（实时反馈）
   - 提供大致的 token 参考

2. **需要精确统计时**：非流式模式 + API usage
   - 用于成本分析
   - 用于日志记录
   - 用于计费统计

3. **实现步骤**：
   ```
   1. 先运行 test_qwen_usage.sh 确认 API 行为
   2. 根据结果选择对应的解决方案
   3. 添加本地估算作为降级方案
   4. 在 UI 上标注估算值（添加 ~ 符号）
   ```

## 🆘 需要帮助？

运行测试后，请将输出发给我，我可以帮你：
1. 分析 API 的具体行为
2. 选择最佳解决方案
3. 提供具体的代码修改建议

