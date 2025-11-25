# AI 流式响应实现说明

## 已完成的工作

### 1. 创建了 SSEClient.swift
**路径：** `Project_Color/Services/AI/SSEClient.swift`

**功能：**
- 处理 Server-Sent Events (SSE) 数据流
- 解析 SSE 格式的数据（`data:` 前缀）
- 支持两种 JSON 格式：
  - 简单格式：`{"content": "文本"}`
  - OpenAI 格式：`{"choices": [{"delta": {"content": "文本"}}]}`
- 自动处理不完整的消息（缓冲区拼接）
- 支持 `[DONE]` 结束标记

### 2. 修改了 QwenVLService.swift
**新增方法：** `analyzeImagesStreaming`

**功能：**
- 与现有的 `analyzeImages` 方法并行存在
- 构建相同的请求体
- 使用 SSEClient 建立流式连接
- 提供 `onToken` 和 `onComplete` 回调

### 3. 修改了 ColorAnalysisEvaluator.swift
**改动：**
- 在 `evaluateColorAnalysis` 方法中改用流式 API
- 累积接收到的文本
- 每收到一个 token 就更新 UI

## 需要手动完成的步骤

### 步骤 1: 添加 SSEClient.swift 到 Xcode 项目

1. 打开 Xcode
2. 右键点击 `Project_Color/Services/AI` 文件夹
3. 选择 "Add Files to Project_Color..."
4. 选择 `SSEClient.swift` 文件
5. 确保 "Copy items if needed" 未勾选
6. 确保 "Add to targets" 中勾选了 `Project_Color`
7. 点击 "Add"

### 步骤 2: 修改 Function Compute 后端

你的 Node.js handler 需要支持 SSE 流式输出。参考代码：

```javascript
'use strict';

const axios = require("axios");

exports.handler = async (req, resp, context) => {
  try {
    // 设置 SSE 响应头
    resp.setHeader('Content-Type', 'text/event-stream');
    resp.setHeader('Cache-Control', 'no-cache');
    resp.setHeader('Connection', 'keep-alive');
    
    // 读取请求体
    const chunks = [];
    for await (const chunk of req) {
      chunks.push(chunk);
    }
    const rawBody = Buffer.concat(chunks).toString();
    
    let body = {};
    try {
      body = JSON.parse(rawBody);
    } catch (err) {
      console.error("JSON parse error:", err);
      resp.setStatusCode(400);
      resp.send(JSON.stringify({ error: "Invalid JSON" }));
      return;
    }
    
    // 启用流式
    body.stream = true;
    
    const apiKey = process.env.QWEN_API_KEY;
    if (!apiKey) {
      resp.setStatusCode(500);
      resp.send(JSON.stringify({ error: "Missing QWEN_API_KEY" }));
      return;
    }
    
    // 调用 Qwen API（流式）
    const qwenResponse = await axios.post(
      "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions",
      body,
      {
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json"
        },
        responseType: 'stream',
        timeout: 120000
      }
    );
    
    // 转发流式数据
    qwenResponse.data.on('data', chunk => {
      const lines = chunk.toString().split('\n');
      for (const line of lines) {
        if (line.trim().startsWith('data:')) {
          const dataStr = line.trim().substring(5).trim();
          
          // 检查是否是结束标记
          if (dataStr === '[DONE]') {
            resp.write('data: [DONE]\n\n');
            continue;
          }
          
          try {
            const data = JSON.parse(dataStr);
            const content = data.choices?.[0]?.delta?.content;
            
            if (content) {
              // 转换为简单格式
              resp.write(`data: ${JSON.stringify({content})}\n\n`);
            }
          } catch (err) {
            console.error('Parse error:', err);
          }
        }
      }
    });
    
    qwenResponse.data.on('end', () => {
      resp.write('data: [DONE]\n\n');
      resp.end();
    });
    
    qwenResponse.data.on('error', (err) => {
      console.error('Stream error:', err);
      resp.end();
    });
    
  } catch (err) {
    console.error("Error:", err);
    resp.setStatusCode(500);
    resp.setHeader("Content-Type", "application/json");
    resp.send(JSON.stringify({ error: err.toString() }));
  }
};
```

### 步骤 3: 测试

1. 在 Xcode 中编译项目
2. 运行应用
3. 进行照片分析
4. 查看"洞察"标签页
5. 观察 AI 回复是否逐字显示

### 步骤 4: 调试

如果遇到问题，查看 Xcode Console 日志：

**成功的日志应该包含：**
```
🖼️ 开始编码 X 张图片（格式转换为 JPEG）...
   ✓ 图片 1/X 编码完成 (XX KB)
📤 建立 SSE 连接到 Qwen API...
   📌 使用模型: qwen3-vl-flash
   📦 请求体大小: XXX KB
📡 SSE 连接已建立
📡 SSE 响应状态码: 200
✅ 流式传输完成，总字符数: XXX
📡 SSE 连接正常关闭
```

**如果看到错误：**
- `❌ SSE 连接错误:` → 检查网络连接和 FC 端点
- `⚠️ SSE JSON 解析失败:` → 检查 FC 返回的数据格式
- `HTTP 502` → FC 后端有问题，检查 FC 日志

## 降级方案

如果流式实现有问题，可以临时回退到非流式版本：

在 `ColorAnalysisEvaluator.swift` 中，将：
```swift
try await qwenService.analyzeImagesStreaming(...)
```

改回：
```swift
let fullResponse = try await qwenService.analyzeImages(...)
evaluation.overallEvaluation!.fullText = fullResponse
await MainActor.run {
    onUpdate(evaluation)
}
```

## 未来优化

### 1. 添加打字机光标效果
在 `AnalysisResultView.swift` 中添加闪烁光标：

```swift
@State private var isStreaming: Bool = false
@State private var cursorVisible: Bool = true

// 在显示文本时
if isStreaming {
    Text(evaluation.overallEvaluation?.fullText ?? "")
    + Text(cursorVisible ? "▊" : "")
        .foregroundColor(.blue)
}
```

### 2. 自动滚动到底部
确保用户能看到最新的文本：

```swift
ScrollViewReader { proxy in
    ScrollView {
        VStack {
            // 内容
        }
        .id("bottom")
    }
    .onChange(of: evaluation.overallEvaluation?.fullText) { _ in
        withAnimation {
            proxy.scrollTo("bottom", anchor: .bottom)
        }
    }
}
```

### 3. 错误重试机制
如果 SSE 连接失败，自动降级到普通请求：

```swift
do {
    try await qwenService.analyzeImagesStreaming(...)
} catch {
    print("⚠️ 流式请求失败，降级到普通请求")
    let fullResponse = try await qwenService.analyzeImages(...)
    // 处理响应
}
```

## 技术细节

### SSE 数据格式

**从 FC 发送到 Swift：**
```
data: {"content":"你"}\n\n
data: {"content":"好"}\n\n
data: {"content":"！"}\n\n
data: [DONE]\n\n
```

**Swift 解析后：**
- 第一个 token: "你"
- 第二个 token: "好"
- 第三个 token: "！"
- 收到 `[DONE]` 后调用 `onComplete()`

### 并发处理

- SSEClient 在后台线程接收数据
- `onToken` 回调可能在任意线程
- 使用 `Task { @MainActor in }` 确保 UI 更新在主线程

### 内存管理

- SSEClient 使用缓冲区处理不完整的消息
- 连接关闭后自动清理缓冲区
- 累积的文本存储在 `OverallEvaluation.fullText` 中

## 常见问题

**Q: 为什么看不到逐字效果？**
A: 检查 FC 后端是否正确设置了 SSE 响应头和流式输出。

**Q: 连接一直超时怎么办？**
A: 增加 FC 函数的超时设置（建议 120 秒以上）。

**Q: 文本显示不完整？**
A: 检查 SSE 数据格式是否正确，确保每条消息以 `\n\n` 结尾。

**Q: 如何调试 SSE 数据？**
A: 在 SSEClient 的 `processSSELine` 方法中添加 `print(line)` 查看原始数据。

