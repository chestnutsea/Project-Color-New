# 流式 AI 响应调试指南

## 修复的关键问题

### 问题 1: 方法阻塞
**原因：** `analyzeImagesStreaming` 使用 `withCheckedThrowingContinuation` 会阻塞等待完成

**修复：** 改为立即返回，不等待流式传输完成

### 问题 2: SSEClient 被释放
**原因：** SSEClient 是局部变量，方法返回后会被释放

**修复：** 在 QwenVLService 中保持 `currentSSEClient` 引用

### 问题 3: isLoading 状态管理
**原因：** 之前在流式方法返回后立即设置 `isLoading = false`

**修复：** 在 `onComplete` 回调中设置 `isLoading = false`

## FC 代码检查

你的 FC 代码看起来**没有问题**，它正确地：
1. 设置了 SSE 响应头
2. 启用了 `stream: true`
3. 逐块转发数据
4. 转换为简单的 `{content: "..."}` 格式

## 测试步骤

### 1. 编译并运行 App

在 Xcode 中编译运行，查看 Console 日志。

### 2. 预期的日志输出

**成功的流式输出应该看到：**

```
🖼️ 开始编码 X 张图片（格式转换为 JPEG）...
   ✓ 图片 1/X 编码完成 (XX KB)
   ✓ 图片 2/X 编码完成 (XX KB)
   ...
📤 建立 SSE 连接到 Qwen API...
   📌 使用模型: qwen3-vl-flash
   📦 请求体大小: XXX KB
📡 SSE 连接已建立
✅ SSE 连接已建立，开始接收数据...
📡 SSE 响应状态码: 200
📡 SSE 流式传输完成
✅ 流式传输完成，总字符数: XXX
✅ SSE 连接正常关闭
```

**如果看到错误：**

```
❌ SSE 连接错误: ...
```
或
```
⚠️ SSE JSON 解析失败: ...
```

### 3. 使用 curl 测试 FC 端点

在终端运行：

```bash
curl -X POST https://qwen-api-wvqmvfqpfy.cn-hangzhou.fcapp.run \
  -H "Content-Type: application/json" \
  -d '{
    "model": "qwen-vl-flash",
    "messages": [
      {
        "role": "user",
        "content": [{"type": "text", "text": "你好"}]
      }
    ]
  }' \
  --no-buffer
```

**预期输出：**
```
data: {"content":"你"}

data: {"content":"好"}

data: {"content":"！"}

data: [DONE]
```

如果看到这样的输出，说明 FC 端点工作正常。

### 4. 添加调试日志

如果仍然没有流式效果，在 SSEClient.swift 的 `processSSELine` 方法中添加日志：

```swift
private func processSSELine(_ line: String) {
    print("📡 收到 SSE 行: \(line)")  // 添加这行
    
    if line.hasPrefix("data: ") {
        let jsonString = String(line.dropFirst(6))
        print("📡 JSON 字符串: \(jsonString)")  // 添加这行
        
        // ... 其余代码
    }
}
```

### 5. 检查 UI 更新

在 ColorAnalysisEvaluator.swift 的 onToken 回调中添加日志：

```swift
onToken: { token in
    print("📝 收到 token: \(token)")  // 添加这行
    
    if evaluation.overallEvaluation != nil {
        evaluation.overallEvaluation!.fullText += token
        print("📝 累积文本长度: \(evaluation.overallEvaluation!.fullText.count)")  // 添加这行
    }
    
    Task { @MainActor in
        onUpdate(evaluation)
    }
}
```

## 常见问题排查

### Q1: 日志显示连接成功，但没有收到数据

**可能原因：**
- FC 端点没有正确转发流式数据
- Qwen API 没有返回流式数据

**排查：**
1. 用 curl 测试 FC 端点（见上面）
2. 检查 FC 日志，看是否有错误
3. 确认 FC 的 `stream: true` 设置生效

### Q2: 收到数据但 UI 不更新

**可能原因：**
- `onUpdate` 回调没有触发 UI 刷新
- SwiftUI 视图没有观察到数据变化

**排查：**
1. 检查 `evaluation.overallEvaluation?.fullText` 是否在变化
2. 确认 `onUpdate` 在主线程调用
3. 检查 AnalysisResultView 是否正确绑定数据

### Q3: 数据一次性显示，不是逐字显示

**可能原因：**
- SSE 数据被缓冲了
- UI 更新被批处理了

**排查：**
1. 添加上面的调试日志，看 token 是否逐个到达
2. 如果 token 逐个到达但 UI 批量更新，可能是 SwiftUI 的优化
3. 尝试在 `onToken` 中添加小延迟：
   ```swift
   onToken: { token in
       Task { @MainActor in
           evaluation.overallEvaluation!.fullText += token
           onUpdate(evaluation)
           try? await Task.sleep(nanoseconds: 10_000_000)  // 10ms
       }
   }
   ```

### Q4: 看到 "SSE 连接错误" 或 502

**可能原因：**
- FC 端点配置问题
- 请求体过大
- FC 超时

**排查：**
1. 检查 FC 函数的超时设置（应该 >= 120 秒）
2. 检查 FC 函数的内存设置（应该 >= 512 MB）
3. 查看 FC 控制台的日志
4. 尝试减少图片数量测试

## 降级方案

如果流式实现仍有问题，可以临时回退到非流式版本。

在 `ColorAnalysisEvaluator.swift` 中注释掉流式代码，恢复原来的：

```swift
// 临时降级：使用非流式 API
let fullResponse = try await qwenService.analyzeImages(
    images: compressedImages,
    systemPrompt: self.systemPrompt,
    userPrompt: userPrompt,
    model: "qwen3-vl-flash",
    temperature: 0.7,
    maxTokens: 2000
)

if evaluation.overallEvaluation != nil {
    evaluation.overallEvaluation!.fullText = fullResponse
}

await MainActor.run {
    onUpdate(evaluation)
}
```

## 关键代码变更总结

### 1. QwenVLService.swift
- 添加了 `currentSSEClient` 属性保持引用
- `analyzeImagesStreaming` 立即返回，不阻塞
- 在 `onComplete` 中清理 `currentSSEClient`

### 2. ColorAnalysisEvaluator.swift
- `onToken` 中直接累积文本到 `fullText`
- `onComplete` 中设置 `isLoading = false`
- 移除了方法返回后的状态设置

### 3. SSEClient.swift
- 无变化，保持原样

## 下一步

1. 在 Xcode 中编译运行
2. 查看 Console 日志
3. 如果有问题，按照上面的排查步骤逐一检查
4. 如果需要，添加调试日志定位问题

