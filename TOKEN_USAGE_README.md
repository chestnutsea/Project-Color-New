# Token 使用统计问题解决方案

## 📋 问题

应用显示：**⚠️ 未收到 Token 使用统计信息（可能 API 未返回 usage 字段）**

## 🎯 原理说明

Token 使用统计依赖于 API 响应中的 `usage` 字段：

```json
{
  "usage": {
    "prompt_tokens": 150,      // 输入（文本 + 图片）
    "completion_tokens": 50,   // 输出
    "total_tokens": 200        // 总计
  }
}
```

### 当前实现流程

```
应用发送请求 (stream: true)
    ↓
SSEClient 接收流式数据
    ↓
解析每个 SSE 事件，查找 usage 字段
    ↓
如果找到 → 调用 onUsage 回调 → 打印统计 ✅
如果没找到 → 打印警告 ⚠️
```

**代码位置：**
- SSE 解析：`Project_Color/Services/AI/SSEClient.swift` 第 159-166 行
- 统计打印：`Project_Color/Services/AI/QwenVLService.swift` 第 257-267 行

## 🧪 测试方法

### 快速测试（推荐）

```bash
# 1. 设置 API Key
export DASHSCOPE_API_KEY="your-api-key"

# 2. 运行测试
cd /Users/linyahuang/Project_Color
./test_qwen_usage.sh
```

测试脚本会自动检查：
- ✅ 流式模式是否返回 `usage`
- ✅ 非流式模式是否返回 `usage`
- ✅ `stream_options` 参数是否有效

**预计耗时：** 1-2 分钟

### 手动测试

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

# 如果有输出 → 流式模式支持 usage ✅
# 如果没有输出 → 流式模式不支持 usage ❌
```

## 💡 解决方案

根据测试结果，选择对应的解决方案：

### 方案 A：流式模式返回 usage（最理想）

**情况：** API 支持，代码需要调试

**步骤：**
1. 在 `SSEClient.swift` 添加调试日志查看原始 JSON
2. 确认 `onUsage` 回调被正确调用
3. 检查是否有解析错误

### 方案 B：只有非流式模式返回 usage

**情况：** API 限制，需要权衡

**选项 1 - 切换到非流式模式：**
- ✅ 获取精确统计
- ❌ 失去实时打字效果

**选项 2 - 实现本地估算（推荐）：**
- ✅ 保留实时效果
- ✅ 提供大致参考
- ❌ 估算误差 10-20%

**选项 3 - 混合方案：**
- UI 显示：流式 + 估算
- 成本统计：非流式 + 精确值

### 方案 C：需要 stream_options 参数

**情况：** 需要添加参数

**修改 `QwenVLService.swift`：**

```swift
let requestBody: [String: Any] = [
    "model": selectedModel.rawValue,
    "messages": messages,
    "stream": true,
    "stream_options": [           // 🆕 添加
        "include_usage": true
    ]
]
```

### 方案 D：API 不支持 usage

**情况：** API 限制，使用降级方案

**实现本地估算：**

```swift
// 添加到 QwenVLService.swift
private func estimateTokenUsage(
    systemPrompt: String,
    userPrompt: String,
    images: [UIImage],
    response: String
) -> (prompt: Int, completion: Int, total: Int) {
    
    // 1. 文本 token（中文约 1.5 字符/token）
    let promptText = systemPrompt + userPrompt
    let promptTextTokens = Int(Double(promptText.count) / 2.0)
    let completionTokens = Int(Double(response.count) / 2.0)
    
    // 2. 图片 token（Qwen-VL: 256-1280 tokens/图）
    let imageTokens = images.reduce(0) { sum, image in
        let width = image.size.width * image.scale
        let height = image.size.height * image.scale
        let pixels = width * height
        let tokens = Int(pixels / 256.0)
        return sum + max(256, min(1280, tokens))
    }
    
    let totalPrompt = promptTextTokens + imageTokens
    let total = totalPrompt + completionTokens
    
    return (totalPrompt, completionTokens, total)
}
```

**使用估算：**

```swift
onComplete: { [weak self] in
    if let prompt = promptTokens, 
       let completion = completionTokens, 
       let total = totalTokens {
        // 使用 API 返回的精确值
        print("📊 Token 统计: prompt=\(prompt), completion=\(completion)")
    } else {
        // 使用本地估算
        let est = self?.estimateTokenUsage(...)
        print("📊 Token 统计（估算）: ~\(est.prompt), ~\(est.completion)")
    }
}
```

## 📁 文件清单

已创建的文件：

| 文件 | 用途 | 使用方式 |
|------|------|----------|
| `test_qwen_usage.sh` | Shell 测试脚本 | `./test_qwen_usage.sh` |
| `test_api_usage_response.swift` | Swift 测试脚本 | `swift test_api_usage_response.swift` |
| `TOKEN_USAGE_ANALYSIS.md` | 详细原理分析 | 阅读理解原理 |
| `TOKEN_USAGE_QUICK_TEST.md` | 快速测试指南 | 快速上手 |
| `TOKEN_USAGE_README.md` | 本文件 | 总览 |

## 🚀 推荐流程

```
1. 运行测试脚本
   cd /Users/linyahuang/Project_Color
   ./test_qwen_usage.sh

2. 根据输出选择方案
   - 如果流式返回 usage → 调试代码
   - 如果非流式返回 usage → 实现估算或混合方案
   - 如果需要参数 → 添加 stream_options
   - 如果都不返回 → 查文档或实现估算

3. 实现解决方案
   - 修改相关代码
   - 添加测试
   - 更新 UI 显示

4. 验证
   - 在应用中测试
   - 查看控制台输出
   - 确认统计正确显示
```

## 🔗 相关代码

### SSE 客户端（解析 usage）

```swift:159:166:Project_Color/Services/AI/SSEClient.swift
// 检查是否包含 usage 信息（通常在最后一个响应中）
if let usage = json["usage"] as? [String: Any],
   let promptTokens = usage["prompt_tokens"] as? Int,
   let completionTokens = usage["completion_tokens"] as? Int,
   let totalTokens = usage["total_tokens"] as? Int {
    // Token 统计会在 QwenVLService 中统一打印，这里只记录
    onUsage?(promptTokens, completionTokens, totalTokens)
}
```

### Qwen 服务（打印统计）

```swift:257:267:Project_Color/Services/AI/QwenVLService.swift
// 打印最终的 token 使用统计
if let prompt = promptTokens, let completion = completionTokens, let total = totalTokens {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("📊 AI 生成 Token 使用统计:")
    print("   📤 上传 (输入/Prompt): \(prompt) tokens")
    print("   📥 下载 (输出/Completion): \(completion) tokens")
    print("   📦 总计 (Total): \(total) tokens")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
} else {
    print("⚠️ 未收到 Token 使用统计信息（可能 API 未返回 usage 字段）")
}
```

## 📚 参考资料

- **Qwen API 文档**：https://help.aliyun.com/zh/dashscope/
- **OpenAI Stream Options**：https://platform.openai.com/docs/api-reference/chat/create#chat-create-stream_options
- **SSE 规范**：https://developer.mozilla.org/en-US/docs/Web/API/Server-sent_events

## ❓ 常见问题

**Q: 为什么流式模式可能不返回 usage？**

A: 流式模式逐个 token 返回，为了减少延迟，某些 API 提供商会省略统计信息。需要等到流结束才能计算总 token 数。

**Q: 本地估算准确吗？**

A: 文本 token 误差约 10-15%，图片 token 误差约 15-20%。对于成本估算已足够，但精确计费建议使用 API 返回值。

**Q: 如何在 UI 上显示 token 统计？**

A: 可以在 ViewModel 中添加属性：
```swift
@Published var tokenUsage: (prompt: Int, completion: Int, total: Int)?
@Published var isEstimated: Bool = false
```

然后在 View 中显示：
```swift
if let usage = viewModel.tokenUsage {
    Text("Token: \(usage.total) \(viewModel.isEstimated ? "~" : "")")
}
```

**Q: 测试脚本需要什么依赖？**

A: 
- `test_qwen_usage.sh`: 需要 `curl`（系统自带），推荐安装 `jq`（`brew install jq`）
- `test_api_usage_response.swift`: 只需要 Swift 环境（Xcode 自带）

## 📞 获取帮助

如果测试后仍有问题：

1. 保存测试脚本的完整输出
2. 检查 Qwen API 官方文档
3. 查看应用控制台的详细日志
4. 根据具体输出选择对应的解决方案

---

**创建时间：** 2025-12-12  
**相关问题：** Token 使用统计未显示  
**状态：** 待测试验证

