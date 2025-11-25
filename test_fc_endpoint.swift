#!/usr/bin/env swift

import Foundation

struct ChatMessage: Codable {
    let role: String
    let content: String
}

struct ChatRequest: Codable {
    let messages: [ChatMessage]
}

func testFCEndpoint() async {
    guard let url = URL(string: "https://qwen-api-wvqmvfqpfy.cn-hangzhou.fcapp.run") else {
        print("❌ URL无效")
        return
    }
    
    // 测试消息
    let body = ChatRequest(
        messages: [
            ChatMessage(role: "user", content: "Hello from Swift App!")
        ]
    )
    
    // 创建请求
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    
    do {
        // 编码请求体
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(body)
        
        print("📤 发送测试请求到 Function Compute...")
        
        // 发请求（异步）
        let (data, response) = try await URLSession.shared.data(for: request)
        
        // 打印响应内容
        let responseText = String(data: data, encoding: .utf8) ?? "无效数据"
        print("✅ 服务器返回：")
        print(responseText)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("\n📊 HTTP 状态码: \(httpResponse.statusCode)")
        }
        
    } catch {
        print("❌ 请求失败：\(error)")
    }
}

// 运行测试
Task {
    await testFCEndpoint()
    exit(0)
}

// 保持程序运行
RunLoop.main.run()

