# Qwen Function Compute 502 错误排查指南

## 错误信息
```
❌ 整体评价失败: API 错误: HTTP 502: Internal Server Error
```

## 502 错误的常见原因

### 1. Function Compute 后端问题

**可能原因：**
- FC 函数超时（默认 60 秒）
- FC 函数内存不足
- FC 函数代码错误
- Qwen API 调用失败（从 FC 到 DashScope）

**排查步骤：**

1. **检查 FC 函数日志**
   ```bash
   # 在阿里云控制台查看函数计算日志
   # 路径：函数计算 > 服务及函数 > 你的函数 > 调用日志
   ```

2. **检查 FC 函数配置**
   - 超时时间：建议设置为 120 秒或更长
   - 内存：建议至少 512 MB
   - 环境变量：确保 QWEN_API_KEY 已配置

### 2. 请求体过大

**问题：** 图片的 base64 编码可能导致请求体过大

**当前实现：**
- 图片已压缩到最长边 400px
- 使用 JPEG 格式，质量 1.0

**可能的解决方案：**

```swift
// 选项 1: 进一步压缩图片质量
guard let imageData = image.jpegData(compressionQuality: 0.8) else {
    continue
}

// 选项 2: 减少图片数量
let maxImages = 5
let imagesToSend = images.prefix(maxImages)

// 选项 3: 进一步缩小尺寸
let maxDimension: CGFloat = 300  // 从 400 降到 300
```

### 3. FC 函数代码问题

**检查你的 FC 函数是否正确处理请求：**

```python
# 示例 FC 函数代码
def handler(event, context):
    import json
    import requests
    
    # 解析请求
    body = json.loads(event)
    
    # 转发到 Qwen API
    response = requests.post(
        'https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions',
        headers={
            'Authorization': f'Bearer {os.environ["QWEN_API_KEY"]}',
            'Content-Type': 'application/json'
        },
        json=body,
        timeout=120  # 重要：设置足够长的超时
    )
    
    return {
        'statusCode': response.status_code,
        'body': response.text
    }
```

### 4. 网络问题

**可能原因：**
- FC 函数无法访问外网（需要配置 NAT 网关）
- Qwen API 响应慢

**解决方案：**
- 确保 FC 函数配置了 VPC 和 NAT 网关
- 或使用公网访问模式

## 调试步骤

### 步骤 1: 查看详细日志

运行应用后，在 Xcode Console 中查看：

```
📤 发送请求到 Qwen API...
   🔗 URL: https://qwen-api-wvqmvfqpfy.cn-hangzhou.fcapp.run
   📌 使用模型: qwen3-vl-flash
   📦 请求体大小: XXX KB
   📝 请求体预览 (前 500 字符):
   {...}

📥 收到响应，状态码: 502
❌ API 返回错误状态码: 502
   📄 错误响应内容:
   {...}
```

### 步骤 2: 测试 FC 端点

使用简单的测试请求：

```bash
curl -X POST https://qwen-api-wvqmvfqpfy.cn-hangzhou.fcapp.run \
  -H "Content-Type: application/json" \
  -d '{
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'
```

### 步骤 3: 检查请求体大小

如果请求体过大（> 6 MB），考虑：

1. **减少图片数量**
   ```swift
   // 在 ColorAnalysisEvaluator.swift 中
   let maxImages = 5
   let imagesToAnalyze = compressedImages.prefix(maxImages)
   ```

2. **进一步压缩**
   ```swift
   // 在 QwenVLService.swift 中
   guard let imageData = image.jpegData(compressionQuality: 0.7) else {
       continue
   }
   ```

### 步骤 4: 简化请求测试

创建一个最小化的测试：

```swift
// 只发送 1 张图片，不带 system prompt
let result = try await qwenService.analyzeImages(
    images: [compressedImages.first!],
    systemPrompt: "你是一位色彩分析师",
    userPrompt: "描述这张图片的色彩",
    model: "qwen-vl-flash",
    temperature: 0.7,
    maxTokens: 500
)
```

## 临时解决方案

### 方案 1: 减少图片数量

```swift
// 在 ColorAnalysisEvaluator.swift 的 evaluateColorAnalysis 方法中
let maxImages = 3  // 只发送前 3 张
let imagesToSend = Array(compressedImages.prefix(maxImages))

let fullResponse = try await qwenService.analyzeImages(
    images: imagesToSend,  // 使用限制后的图片
    systemPrompt: self.systemPrompt,
    userPrompt: userPrompt,
    model: "qwen3-vl-flash",
    temperature: 0.7,
    maxTokens: 2000
)
```

### 方案 2: 降低图片质量

```swift
// 在 QwenVLService.swift 中
guard let imageData = image.jpegData(compressionQuality: 0.6) else {
    print("⚠️ 图片 \(index + 1) 转换失败，跳过")
    continue
}
```

### 方案 3: 回退到原 DashScope API

如果 FC 问题难以解决，可以暂时回退：

```swift
// APIConfig.swift
var qwenEndpoint: String {
    return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
}

// QwenVLService.swift - 恢复 Authorization header
guard apiConfig.isQwenAPIKeyValid else {
    throw QwenError.invalidAPIKey
}
request.setValue("Bearer \(apiConfig.qwenAPIKey)", forHTTPHeaderField: "Authorization")
```

## 检查清单

- [ ] FC 函数日志中有错误信息吗？
- [ ] FC 函数超时设置是否足够长（>= 120 秒）？
- [ ] FC 函数内存是否足够（>= 512 MB）？
- [ ] FC 函数能否访问外网（Qwen API）？
- [ ] 请求体大小是否合理（< 6 MB）？
- [ ] 使用 curl 测试 FC 端点是否正常？
- [ ] FC 函数的 QWEN_API_KEY 是否配置正确？

## 下一步

1. **查看 FC 日志**：这是最重要的，能直接看到后端错误
2. **测试简单请求**：使用 curl 发送不带图片的简单请求
3. **逐步增加复杂度**：先 1 张图片，再多张图片
4. **监控请求大小**：确保不超过 FC 限制

## 联系信息

如果问题持续，请提供：
- FC 函数日志截图
- Xcode Console 完整日志
- 请求体大小（从日志中获取）
- FC 函数配置（超时、内存等）

