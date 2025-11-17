//
//  DeepSeekService.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/16.
//  DeepSeek API 客户端
//

import Foundation

/// DeepSeek API 服务类
class DeepSeekService {
    
    static let shared = DeepSeekService()
    
    private let apiConfig = APIConfig.shared
    private let session: URLSession
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 90  // 增加到90秒
        configuration.timeoutIntervalForResource = 180  // 增加到3分钟
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Request/Response Models
    
    struct ChatRequest: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let maxTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
        }
        
        struct Message: Codable {
            let role: String  // "system", "user", "assistant"
            let content: String
        }
    }
    
    struct ChatResponse: Codable {
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [Choice]
        let usage: Usage?
        
        struct Choice: Codable {
            let index: Int
            let message: Message
            let finishReason: String?
            
            enum CodingKeys: String, CodingKey {
                case index
                case message
                case finishReason = "finish_reason"
            }
            
            struct Message: Codable {
                let role: String
                let content: String
            }
        }
        
        struct Usage: Codable {
            let promptTokens: Int
            let completionTokens: Int
            let totalTokens: Int
            
            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }
    
    // MARK: - Streaming Response Models
    
    struct StreamResponse: Codable {
        let id: String
        let object: String
        let created: Int
        let model: String
        let choices: [StreamChoice]
        let usage: StreamUsage?  // 最后一个响应包含 usage
        
        struct StreamChoice: Codable {
            let index: Int
            let delta: Delta
            let finishReason: String?
            
            enum CodingKeys: String, CodingKey {
                case index
                case delta
                case finishReason = "finish_reason"
            }
            
            struct Delta: Codable {
                let role: String?
                let content: String?
            }
        }
        
        struct StreamUsage: Codable {
            let promptTokens: Int
            let completionTokens: Int
            let totalTokens: Int
            
            enum CodingKeys: String, CodingKey {
                case promptTokens = "prompt_tokens"
                case completionTokens = "completion_tokens"
                case totalTokens = "total_tokens"
            }
        }
    }
    
    struct APIError: Codable {
        let error: ErrorDetail
        
        struct ErrorDetail: Codable {
            let message: String
            let type: String?
            let code: String?
        }
    }
    
    // MARK: - Error Types
    
    enum DeepSeekError: LocalizedError {
        case invalidAPIKey
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case decodingError(Error)
        
        var errorDescription: String? {
            switch self {
            case .invalidAPIKey:
                return "API Key 无效或未配置"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            case .invalidResponse:
                return "无效的服务器响应"
            case .apiError(let message):
                return "API 错误: \(message)"
            case .decodingError(let error):
                return "数据解析错误: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - API Methods
    
    /// 发送聊天请求到 DeepSeek API
    /// - Parameters:
    ///   - messages: 对话消息列表
    ///   - model: 使用的模型（默认 deepseek-chat）
    ///   - temperature: 温度参数（0-2，默认 0.7）
    ///   - maxTokens: 最大生成 token 数
    /// - Returns: AI 生成的回复内容
    func sendChatRequest(
        messages: [ChatRequest.Message],
        model: String = "deepseek-chat",
        temperature: Double = 0.7,
        maxTokens: Int? = 2000
    ) async throws -> String {
        
        // 验证 API Key
        guard apiConfig.isAPIKeyValid else {
            throw DeepSeekError.invalidAPIKey
        }
        
        // 构建请求
        guard let url = URL(string: apiConfig.deepSeekEndpoint) else {
            throw DeepSeekError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiConfig.deepSeekAPIKey)", forHTTPHeaderField: "Authorization")
        
        let chatRequest = ChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )
        
        do {
            request.httpBody = try JSONEncoder().encode(chatRequest)
        } catch {
            throw DeepSeekError.decodingError(error)
        }
        
        // 发送请求
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw DeepSeekError.networkError(error)
        }
        
        // 检查 HTTP 状态码
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekError.invalidResponse
        }
        
        // 如果状态码不是 2xx，尝试解析错误信息
        guard (200...299).contains(httpResponse.statusCode) else {
            if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                throw DeepSeekError.apiError(apiError.error.message)
            } else {
                throw DeepSeekError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        // 解析响应
        let chatResponse: ChatResponse
        do {
            chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            print("❌ 解码错误: \(error)")
            if let jsonString = String(data: data, encoding: .utf8) {
                print("响应内容: \(jsonString)")
            }
            throw DeepSeekError.decodingError(error)
        }
        
        // 提取回复内容
        guard let firstChoice = chatResponse.choices.first else {
            throw DeepSeekError.invalidResponse
        }
        
        // 打印 token 使用情况
        if let usage = chatResponse.usage {
            print("📊 Token 使用情况:")
            print("   - Prompt: \(usage.promptTokens)")
            print("   - Completion: \(usage.completionTokens)")
            print("   - Total: \(usage.totalTokens)")
        }
        
        return firstChoice.message.content
    }
    
    /// 简化的单轮对话接口
    /// - Parameters:
    ///   - systemPrompt: 系统提示词（定义 AI 角色）
    ///   - userMessage: 用户消息
    /// - Returns: AI 回复
    func chat(systemPrompt: String, userMessage: String) async throws -> String {
        let messages = [
            ChatRequest.Message(role: "system", content: systemPrompt),
            ChatRequest.Message(role: "user", content: userMessage)
        ]
        return try await sendChatRequest(messages: messages)
    }
    
    // MARK: - Streaming API
    
    /// 发送流式聊天请求到 DeepSeek API（实时返回响应）
    /// - Parameters:
    ///   - messages: 对话消息列表
    ///   - model: 使用的模型（默认 deepseek-chat）
    ///   - temperature: 温度参数（0-2，默认 0.7）
    ///   - maxTokens: 最大生成 token 数
    ///   - onChunk: 每收到一个文本块时的回调
    /// - Returns: 完整的回复内容
    func sendStreamingChatRequest(
        messages: [ChatRequest.Message],
        model: String = "deepseek-chat",
        temperature: Double = 0.7,
        maxTokens: Int? = 2000,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        
        // 验证 API Key
        guard apiConfig.isAPIKeyValid else {
            throw DeepSeekError.invalidAPIKey
        }
        
        // 构建请求
        guard let url = URL(string: apiConfig.deepSeekEndpoint) else {
            throw DeepSeekError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiConfig.deepSeekAPIKey)", forHTTPHeaderField: "Authorization")
        
        // 构建请求体（添加 stream: true）
        var requestDict: [String: Any] = [
            "model": model,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
            "temperature": temperature,
            "stream": true  // 启用流式响应
        ]
        
        if let maxTokens = maxTokens {
            requestDict["max_tokens"] = maxTokens
        }
        
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestDict)
        } catch {
            throw DeepSeekError.decodingError(error)
        }
        
        // 发送请求并处理流式响应
        let (asyncBytes, response) = try await session.bytes(for: request)
        
        // 检查 HTTP 状态码
        guard let httpResponse = response as? HTTPURLResponse else {
            throw DeepSeekError.invalidResponse
        }
        
        guard (200...299).contains(httpResponse.statusCode) else {
            throw DeepSeekError.apiError("HTTP \(httpResponse.statusCode)")
        }
        
        var fullContent = ""
        var buffer = Data()
        var totalTokens: Int?
        var promptTokens: Int?
        var completionTokens: Int?
        
        // 逐字节读取 SSE 流（使用 Data 以正确处理 UTF-8）
        for try await byte in asyncBytes {
            buffer.append(byte)
            
            // 尝试将 buffer 转换为字符串
            if let bufferString = String(data: buffer, encoding: .utf8) {
                // 检查是否有完整的行
                if bufferString.contains("\n") {
                    let lines = bufferString.components(separatedBy: "\n")
                    
                    // 保留最后一行（可能不完整）
                    if let lastLine = lines.last, !lastLine.isEmpty {
                        buffer = lastLine.data(using: .utf8) ?? Data()
                    } else {
                        buffer = Data()
                    }
                    
                    // 处理完整的行
                    for line in lines.dropLast() {
                        // SSE 格式：data: {...}
                        if line.hasPrefix("data: ") {
                            let jsonString = String(line.dropFirst(6))
                            
                            // 检查是否是结束标记
                            if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                                continue
                            }
                            
                            // 解析 JSON
                            guard let jsonData = jsonString.data(using: .utf8) else { continue }
                            
                            do {
                                let streamResponse = try JSONDecoder().decode(StreamResponse.self, from: jsonData)
                                
                                if let content = streamResponse.choices.first?.delta.content {
                                    fullContent += content
                                    // 实时回调
                                    await MainActor.run {
                                        onChunk(content)
                                    }
                                }
                                
                                // 记录 token 使用情况（最后一个响应包含 usage）
                                if let usage = streamResponse.usage {
                                    totalTokens = usage.totalTokens
                                    promptTokens = usage.promptTokens
                                    completionTokens = usage.completionTokens
                                }
                            } catch {
                                // 忽略解析错误，继续处理下一行
                                continue
                            }
                        }
                    }
                }
            }
        }
        
        // 打印 token 使用情况
        if let total = totalTokens, let prompt = promptTokens, let completion = completionTokens {
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
            print("📊 Token 使用统计")
            print("   - Prompt Tokens: \(prompt)")
            print("   - Completion Tokens: \(completion)")
            print("   - Total Tokens: \(total)")
            print("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
        }
        
        print("✅ 流式响应完成，总长度: \(fullContent.count) 字符")
        return fullContent
    }
    
    /// 简化的流式对话接口
    /// - Parameters:
    ///   - systemPrompt: 系统提示词
    ///   - userMessage: 用户消息
    ///   - onChunk: 每收到一个文本块时的回调
    /// - Returns: 完整的回复内容
    func streamingChat(
        systemPrompt: String,
        userMessage: String,
        onChunk: @escaping (String) -> Void
    ) async throws -> String {
        let messages = [
            ChatRequest.Message(role: "system", content: systemPrompt),
            ChatRequest.Message(role: "user", content: userMessage)
        ]
        return try await sendStreamingChatRequest(messages: messages, onChunk: onChunk)
    }
}

