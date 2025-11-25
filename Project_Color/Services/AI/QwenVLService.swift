//
//  QwenVLService.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/22.
//  Qwen3-VL-Flash API 客户端
//

import Foundation
import UIKit

/// Qwen3-VL-Flash API 服务类
class QwenVLService {
    
    static let shared = QwenVLService()
    
    private let apiConfig = APIConfig.shared
    private let session: URLSession
    private var currentSSEClient: SSEClient?  // 保持 SSE 客户端的引用
    
    private init() {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 180
        self.session = URLSession(configuration: configuration)
    }
    
    // MARK: - Request/Response Models
    
    struct VisionChatRequest: Codable {
        let model: String
        let messages: [Message]
        let temperature: Double?
        let maxTokens: Int?
        
        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case temperature
            case maxTokens = "max_tokens"
        }
        
        struct Message: Codable {
            let role: String  // "system", "user"
            let content: [ContentItem]
        }
        
        struct ContentItem: Codable {
            let type: String  // "text" or "image_url"
            let text: String?
            let imageUrl: ImageURL?
            
            enum CodingKeys: String, CodingKey {
                case type
                case text
                case imageUrl = "image_url"
            }
        }
        
        struct ImageURL: Codable {
            let url: String  // base64 data URL
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
    
    struct APIError: Codable {
        let error: ErrorDetail
        
        struct ErrorDetail: Codable {
            let message: String
            let type: String?
            let code: String?
        }
    }
    
    // MARK: - Error Types
    
    enum QwenError: LocalizedError {
        case invalidAPIKey
        case networkError(Error)
        case invalidResponse
        case apiError(String)
        case decodingError(Error)
        case imageCompressionFailed
        
        var errorDescription: String? {
            switch self {
            case .invalidAPIKey:
                return "Qwen API Key 无效或未配置"
            case .networkError(let error):
                return "网络错误: \(error.localizedDescription)"
            case .invalidResponse:
                return "无效的服务器响应"
            case .apiError(let message):
                return "API 错误: \(message)"
            case .decodingError(let error):
                return "数据解析错误: \(error.localizedDescription)"
            case .imageCompressionFailed:
                return "图片转换失败"
            }
        }
    }
    
    // MARK: - API Methods
    
    /// 发送视觉分析请求到 Qwen3-VL-Flash API（流式）
    /// - Parameters:
    ///   - images: 图片数组（已压缩到最长边 400，保持宽高比）
    ///   - systemPrompt: 系统提示词
    ///   - userPrompt: 用户提示词
    ///   - model: 使用的模型（默认 qwen-vl-flash）
    ///   - temperature: 温度参数（0-2，默认 0.7）
    ///   - maxTokens: 最大生成 token 数
    ///   - onToken: 每收到一个 token 的回调
    ///   - onComplete: 流式传输完成的回调
    func analyzeImagesStreaming(
        images: [UIImage],
        systemPrompt: String,
        userPrompt: String,
        model: String = "qwen-vl-flash",
        temperature: Double = 0.7,
        maxTokens: Int? = 2000,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void
    ) async throws {
        
        // 构建请求 URL
        guard let url = URL(string: apiConfig.qwenEndpoint) else {
            throw QwenError.invalidResponse
        }
        
        // 转换图片为 base64
        print("🖼️ 开始编码 \(images.count) 张图片（格式转换为 JPEG）...")
        var imageContentItems: [VisionChatRequest.ContentItem] = []
        
        for (index, image) in images.enumerated() {
            guard let imageData = image.jpegData(compressionQuality: 1.0) else {
                print("⚠️ 图片 \(index + 1) 转换失败，跳过")
                continue
            }
            
            let base64String = imageData.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(base64String)"
            
            imageContentItems.append(
                VisionChatRequest.ContentItem(
                    type: "image_url",
                    text: nil,
                    imageUrl: VisionChatRequest.ImageURL(url: dataURL)
                )
            )
            
            print("   ✓ 图片 \(index + 1)/\(images.count) 编码完成 (\(imageData.count / 1024) KB)")
        }
        
        guard !imageContentItems.isEmpty else {
            throw QwenError.imageCompressionFailed
        }
        
        // 构建消息
        let messages: [VisionChatRequest.Message] = [
            VisionChatRequest.Message(
                role: "system",
                content: [
                    VisionChatRequest.ContentItem(
                        type: "text",
                        text: systemPrompt,
                        imageUrl: nil
                    )
                ]
            ),
            VisionChatRequest.Message(
                role: "user",
                content: imageContentItems + [
                    VisionChatRequest.ContentItem(
                        type: "text",
                        text: userPrompt,
                        imageUrl: nil
                    )
                ]
            )
        ]
        
        let chatRequest = VisionChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )
        
        // 编码请求体
        let encoder = JSONEncoder()
        let requestBody = try encoder.encode(chatRequest)
        
        print("📤 建立 SSE 连接到 Qwen API...")
        print("   📌 使用模型: \(model)")
        print("   📦 请求体大小: \(requestBody.count / 1024) KB")
        
        // 取消之前的连接（如果有）
        currentSSEClient?.cancel()
        
        // 创建新的 SSE 客户端并保持引用
        let sseClient = SSEClient()
        currentSSEClient = sseClient
        
        sseClient.connect(
            url: url,
            body: requestBody,
            onToken: { token in
                onToken(token)
            },
            onComplete: { [weak self] in
                onComplete()
                self?.currentSSEClient = nil
            },
            onError: { [weak self] error in
                print("❌ SSE 错误: \(error.localizedDescription)")
                // 错误时也调用 onComplete，避免 UI 卡住
                onComplete()
                self?.currentSSEClient = nil
            }
        )
        
        // 立即返回，不等待流式传输完成
    }
    
    /// 发送视觉分析请求到 Qwen3-VL-Flash API
    /// - Parameters:
    ///   - images: 图片数组（已压缩到最长边 400，保持宽高比）
    ///   - systemPrompt: 系统提示词
    ///   - userPrompt: 用户提示词
    ///   - model: 使用的模型（默认 qwen-vl-flash）
    ///   - temperature: 温度参数（0-2，默认 0.7）
    ///   - maxTokens: 最大生成 token 数
    /// - Returns: AI 生成的回复内容
    func analyzeImages(
        images: [UIImage],
        systemPrompt: String,
        userPrompt: String,
        model: String = "qwen-vl-flash",
        temperature: Double = 0.7,
        maxTokens: Int? = 2000
    ) async throws -> String {
        
        // 构建请求
        guard let url = URL(string: apiConfig.qwenEndpoint) else {
            throw QwenError.invalidResponse
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        // Function Compute endpoint doesn't require Authorization header
        
        // 转换图片为 base64（图片已在加载时压缩到最长边 400，这里只做格式转换）
        print("🖼️ 开始编码 \(images.count) 张图片（格式转换为 JPEG）...")
        var imageContentItems: [VisionChatRequest.ContentItem] = []
        
        for (index, image) in images.enumerated() {
            // 转换为 JPEG 格式（质量 1.0，因为尺寸已压缩，不需要再降低质量）
            guard let imageData = image.jpegData(compressionQuality: 1.0) else {
                print("⚠️ 图片 \(index + 1) 转换失败，跳过")
                continue
            }
            
            let base64String = imageData.base64EncodedString()
            let dataURL = "data:image/jpeg;base64,\(base64String)"
            
            imageContentItems.append(
                VisionChatRequest.ContentItem(
                    type: "image_url",
                    text: nil,
                    imageUrl: VisionChatRequest.ImageURL(url: dataURL)
                )
            )
            
            print("   ✓ 图片 \(index + 1)/\(images.count) 编码完成 (\(imageData.count / 1024) KB)")
        }
        
        guard !imageContentItems.isEmpty else {
            throw QwenError.imageCompressionFailed
        }
        
        // 构建消息
        let messages: [VisionChatRequest.Message] = [
            // System message
            VisionChatRequest.Message(
                role: "system",
                content: [
                    VisionChatRequest.ContentItem(
                        type: "text",
                        text: systemPrompt,
                        imageUrl: nil
                    )
                ]
            ),
            // User message with images
            VisionChatRequest.Message(
                role: "user",
                content: imageContentItems + [
                    VisionChatRequest.ContentItem(
                        type: "text",
                        text: userPrompt,
                        imageUrl: nil
                    )
                ]
            )
        ]
        
        let chatRequest = VisionChatRequest(
            model: model,
            messages: messages,
            temperature: temperature,
            maxTokens: maxTokens
        )
        
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = .prettyPrinted
            request.httpBody = try encoder.encode(chatRequest)
            
            // 打印请求详情（用于调试）
            if let bodyString = String(data: request.httpBody!, encoding: .utf8) {
                print("📤 发送请求到 Qwen API...")
                print("   🔗 URL: \(apiConfig.qwenEndpoint)")
                print("   📌 使用模型: \(model)")
                print("   📦 请求体大小: \(request.httpBody!.count / 1024) KB")
                print("   📝 请求体预览 (前 500 字符):")
                print(String(bodyString.prefix(500)))
            }
        } catch {
            throw QwenError.decodingError(error)
        }
        
        // 发送请求
        let data: Data
        let response: URLResponse
        
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw QwenError.networkError(error)
        }
        
        // 检查 HTTP 状态码
        guard let httpResponse = response as? HTTPURLResponse else {
            throw QwenError.invalidResponse
        }
        
        print("📥 收到响应，状态码: \(httpResponse.statusCode)")
        
        // 如果状态码不是 2xx，尝试解析错误信息
        guard (200...299).contains(httpResponse.statusCode) else {
            // 打印详细的错误信息
            print("❌ API 返回错误状态码: \(httpResponse.statusCode)")
            
            if let errorString = String(data: data, encoding: .utf8) {
                print("   📄 错误响应内容:")
                print(errorString)
                
                // 尝试解析标准 API 错误格式
                if let apiError = try? JSONDecoder().decode(APIError.self, from: data) {
                    throw QwenError.apiError(apiError.error.message)
                } else {
                    throw QwenError.apiError("HTTP \(httpResponse.statusCode): \(errorString)")
                }
            } else {
                print("   📄 错误响应: 无法解析为文本")
                throw QwenError.apiError("HTTP \(httpResponse.statusCode)")
            }
        }
        
        // 解析响应
        let chatResponse: ChatResponse
        do {
            chatResponse = try JSONDecoder().decode(ChatResponse.self, from: data)
        } catch {
            print("❌ 响应解析失败: \(error)")
            if let responseString = String(data: data, encoding: .utf8) {
                print("   原始响应: \(responseString.prefix(500))")
            }
            throw QwenError.decodingError(error)
        }
        
        // 提取回复内容
        guard let firstChoice = chatResponse.choices.first else {
            throw QwenError.invalidResponse
        }
        
        let content = firstChoice.message.content
        
        if let usage = chatResponse.usage {
            print("✅ Qwen API 调用成功")
            print("   📌 实际使用模型: \(chatResponse.model)")
            print("   📊 Token 使用: \(usage.promptTokens) + \(usage.completionTokens) = \(usage.totalTokens)")
        } else {
            print("✅ Qwen API 调用成功")
            print("   📌 实际使用模型: \(chatResponse.model)")
        }
        
        return content
    }
}

