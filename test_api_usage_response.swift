#!/usr/bin/swift
//
//  test_api_usage_response.swift
//  用于测试 Qwen API 是否返回 usage 字段
//
//  这个脚本会：
//  1. 向 Qwen API 发送一个简单的流式请求
//  2. 捕获并打印所有原始响应数据
//  3. 特别标记出 usage 字段的位置和内容
//  4. 测试非流式模式（stream=false）的响应格式
//

import Foundation

// MARK: - 配置

struct TestConfig {
    static let apiKey = ProcessInfo.processInfo.environment["DASHSCOPE_API_KEY"] ?? ""
    static let endpoint = "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    
    // 测试用的简单提示
    static let testPrompt = "你好，请说一个字"
}

// MARK: - 测试函数

/// 测试流式响应（stream=true）
func testStreamingMode() async {
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🧪 测试 1: 流式模式 (stream=true)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    guard let url = URL(string: TestConfig.endpoint) else {
        print("❌ 无效的 URL")
        return
    }
    
    // 构建请求体
    let requestBody: [String: Any] = [
        "model": "qwen-vl-plus",
        "messages": [
            ["role": "user", "content": TestConfig.testPrompt]
        ],
        "stream": true,
        "temperature": 0.7
    ]
    
    guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
        print("❌ 无法序列化请求体")
        return
    }
    
    // 创建请求
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(TestConfig.apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = bodyData
    
    print("\n📤 发送请求...")
    print("   模型: qwen-vl-plus")
    print("   流式: true")
    
    do {
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 无效的响应")
            return
        }
        
        print("\n✅ 收到响应")
        print("   状态码: \(httpResponse.statusCode)")
        print("   Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "未知")")
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📡 原始 SSE 数据流:")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        var chunkCount = 0
        var usageFound = false
        
        for try await line in asyncBytes.lines {
            chunkCount += 1
            
            // 打印原始行
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString == "[DONE]" {
                    print("\n[\(chunkCount)] data: [DONE]")
                    continue
                }
                
                // 尝试解析 JSON 并美化输出
                if let jsonData = jsonString.data(using: .utf8),
                   let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
                   let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
                   let prettyString = String(data: prettyData, encoding: .utf8) {
                    
                    print("\n[\(chunkCount)] ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                    print(prettyString)
                    
                    // 检查是否包含 usage 字段
                    if let json = jsonObject as? [String: Any],
                       let usage = json["usage"] as? [String: Any] {
                        usageFound = true
                        print("\n🎯 发现 usage 字段！")
                        print("   prompt_tokens: \(usage["prompt_tokens"] ?? "N/A")")
                        print("   completion_tokens: \(usage["completion_tokens"] ?? "N/A")")
                        print("   total_tokens: \(usage["total_tokens"] ?? "N/A")")
                    }
                } else {
                    print("\n[\(chunkCount)] (无法解析的 JSON)")
                    print(jsonString)
                }
            } else if !line.isEmpty {
                print("\n[\(chunkCount)] \(line)")
            }
        }
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 流式模式测试结果:")
        print("   总数据块数: \(chunkCount)")
        print("   是否包含 usage: \(usageFound ? "✅ 是" : "❌ 否")")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
    } catch {
        print("❌ 请求失败: \(error.localizedDescription)")
    }
}

/// 测试非流式响应（stream=false）
func testNonStreamingMode() async {
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🧪 测试 2: 非流式模式 (stream=false)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    guard let url = URL(string: TestConfig.endpoint) else {
        print("❌ 无效的 URL")
        return
    }
    
    // 构建请求体
    let requestBody: [String: Any] = [
        "model": "qwen-vl-plus",
        "messages": [
            ["role": "user", "content": TestConfig.testPrompt]
        ],
        "stream": false,  // 非流式模式
        "temperature": 0.7
    ]
    
    guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
        print("❌ 无法序列化请求体")
        return
    }
    
    // 创建请求
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("application/json", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(TestConfig.apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = bodyData
    
    print("\n📤 发送请求...")
    print("   模型: qwen-vl-plus")
    print("   流式: false")
    
    do {
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 无效的响应")
            return
        }
        
        print("\n✅ 收到响应")
        print("   状态码: \(httpResponse.statusCode)")
        print("   Content-Type: \(httpResponse.value(forHTTPHeaderField: "Content-Type") ?? "未知")")
        print("   数据大小: \(data.count) 字节")
        
        // 解析 JSON
        if let jsonObject = try? JSONSerialization.jsonObject(with: data),
           let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let prettyString = String(data: prettyData, encoding: .utf8) {
            
            print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📡 原始响应 JSON:")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print(prettyString)
            
            // 检查是否包含 usage 字段
            if let json = jsonObject as? [String: Any],
               let usage = json["usage"] as? [String: Any] {
                print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("🎯 发现 usage 字段！")
                print("   prompt_tokens: \(usage["prompt_tokens"] ?? "N/A")")
                print("   completion_tokens: \(usage["completion_tokens"] ?? "N/A")")
                print("   total_tokens: \(usage["total_tokens"] ?? "N/A")")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            } else {
                print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
                print("❌ 未找到 usage 字段")
                print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            }
        } else {
            print("\n❌ 无法解析 JSON 响应")
            if let rawString = String(data: data, encoding: .utf8) {
                print("原始响应: \(rawString)")
            }
        }
        
    } catch {
        print("❌ 请求失败: \(error.localizedDescription)")
    }
}

/// 测试带图片的视觉模型
func testVisionModelWithImage() async {
    print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    print("🧪 测试 3: 视觉模型 + 图片 (stream=true)")
    print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    
    guard let url = URL(string: TestConfig.endpoint) else {
        print("❌ 无效的 URL")
        return
    }
    
    // 创建一个 1x1 的红色图片作为测试
    let testImageBase64 = "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8DwHwAFBQIAX8jx0gAAAABJRU5ErkJggg=="
    
    // 构建请求体（带图片）
    let requestBody: [String: Any] = [
        "model": "qwen-vl-plus",
        "messages": [
            [
                "role": "user",
                "content": [
                    [
                        "type": "image_url",
                        "image_url": [
                            "url": "data:image/png;base64,\(testImageBase64)"
                        ]
                    ],
                    [
                        "type": "text",
                        "text": "描述这张图片，用一句话"
                    ]
                ]
            ]
        ],
        "stream": true,
        "temperature": 0.7
    ]
    
    guard let bodyData = try? JSONSerialization.data(withJSONObject: requestBody) else {
        print("❌ 无法序列化请求体")
        return
    }
    
    // 创建请求
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
    request.setValue("Bearer \(TestConfig.apiKey)", forHTTPHeaderField: "Authorization")
    request.httpBody = bodyData
    
    print("\n📤 发送请求...")
    print("   模型: qwen-vl-plus")
    print("   流式: true")
    print("   带图片: 是（1x1 测试图片）")
    
    do {
        let (asyncBytes, response) = try await URLSession.shared.bytes(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ 无效的响应")
            return
        }
        
        print("\n✅ 收到响应")
        print("   状态码: \(httpResponse.statusCode)")
        
        var chunkCount = 0
        var usageFound = false
        var lastChunkWithUsage: String?
        
        for try await line in asyncBytes.lines {
            chunkCount += 1
            
            if line.hasPrefix("data: ") {
                let jsonString = String(line.dropFirst(6))
                
                if jsonString == "[DONE]" {
                    continue
                }
                
                // 检查是否包含 usage 字段
                if let jsonData = jsonString.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                   let usage = json["usage"] as? [String: Any] {
                    usageFound = true
                    lastChunkWithUsage = jsonString
                    
                    print("\n🎯 在第 \(chunkCount) 个数据块发现 usage 字段！")
                    print("   prompt_tokens: \(usage["prompt_tokens"] ?? "N/A")")
                    print("   completion_tokens: \(usage["completion_tokens"] ?? "N/A")")
                    print("   total_tokens: \(usage["total_tokens"] ?? "N/A")")
                }
            }
        }
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("📊 视觉模型测试结果:")
        print("   总数据块数: \(chunkCount)")
        print("   是否包含 usage: \(usageFound ? "✅ 是" : "❌ 否")")
        
        if let lastChunk = lastChunkWithUsage {
            print("\n   最后一个包含 usage 的数据块:")
            if let jsonData = lastChunk.data(using: .utf8),
               let jsonObject = try? JSONSerialization.jsonObject(with: jsonData),
               let prettyData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
               let prettyString = String(data: prettyData, encoding: .utf8) {
                print(prettyString)
            }
        }
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n")
        
    } catch {
        print("❌ 请求失败: \(error.localizedDescription)")
    }
}

// MARK: - 主函数

@main
struct UsageTest {
    static func main() async {
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("🧪 Qwen API Usage 字段测试工具")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        
        // 检查 API Key
        if TestConfig.apiKey.isEmpty {
            print("❌ 错误: 未设置 DASHSCOPE_API_KEY 环境变量")
            print("\n使用方法:")
            print("   export DASHSCOPE_API_KEY=\"your-api-key\"")
            print("   swift test_api_usage_response.swift")
            return
        }
        
        print("✅ API Key 已配置")
        print("   长度: \(TestConfig.apiKey.count) 字符")
        print("   前缀: \(String(TestConfig.apiKey.prefix(8)))...")
        
        // 依次执行三个测试
        await testStreamingMode()
        await testNonStreamingMode()
        await testVisionModelWithImage()
        
        print("\n━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("✅ 所有测试完成")
        print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        print("\n📝 总结:")
        print("   - 如果流式模式没有返回 usage，说明 API 在流式响应中不包含 usage")
        print("   - 如果非流式模式返回了 usage，说明 API 支持 usage，但仅在非流式模式下")
        print("   - 如果都没有 usage，说明该端点或模型不支持 usage 统计")
        print("\n💡 建议:")
        print("   - 查看 Qwen API 官方文档确认 usage 字段的返回条件")
        print("   - 如果需要 usage，考虑使用非流式模式或其他 API 参数")
        print("   - 可能需要在请求中添加特定参数（如 stream_options）来获取 usage")
    }
}

