//
//  SSEClient.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/25.
//  Server-Sent Events (SSE) 客户端
//

import Foundation

/// SSE 客户端，用于处理流式数据传输
class SSEClient: NSObject {
    
    // MARK: - Error Types
    
    enum SSEError: LocalizedError {
        case invalidURL
        case connectionFailed(Error)
        case invalidData
        case streamClosed
        
        var errorDescription: String? {
            switch self {
            case .invalidURL:
                return "无效的 URL"
            case .connectionFailed(let error):
                return "连接失败: \(error.localizedDescription)"
            case .invalidData:
                return "无效的数据格式"
            case .streamClosed:
                return "数据流已关闭"
            }
        }
    }
    
    // MARK: - Properties
    
    private var dataTask: URLSessionDataTask?
    private var buffer = Data()
    private var onToken: ((String) -> Void)?
    private var onComplete: (() -> Void)?
    private var onError: ((Error) -> Void)?
    
    // MARK: - Public Methods
    
    /// 建立 SSE 连接并开始接收数据
    /// - Parameters:
    ///   - url: SSE 端点 URL
    ///   - body: 请求体数据
    ///   - onToken: 每收到一个 token 的回调
    ///   - onComplete: 流式传输完成的回调
    ///   - onError: 错误回调
    func connect(
        url: URL,
        body: Data,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void
    ) {
        self.onToken = onToken
        self.onComplete = onComplete
        self.onError = onError
        self.buffer = Data()
        
        // 创建请求
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.httpBody = body
        request.timeoutInterval = 120
        
        // 创建 URLSession 配置（禁用缓冲以支持真正的流式传输）
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 180
        configuration.httpMaximumConnectionsPerHost = 1
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.urlCache = nil
        
        // 创建操作队列，确保回调在后台线程
        let queue = OperationQueue()
        queue.maxConcurrentOperationCount = 1
        queue.qualityOfService = .userInitiated
        
        let session = URLSession(configuration: configuration, delegate: self, delegateQueue: queue)
        
        // 创建数据任务
        dataTask = session.dataTask(with: request)
        dataTask?.resume()
        
        print("📡 SSE 连接已建立")
    }
    
    /// 取消连接
    func cancel() {
        dataTask?.cancel()
        dataTask = nil
        buffer = Data()
        print("📡 SSE 连接已取消")
    }
    
    // MARK: - Private Methods
    
    /// 解析 SSE 数据
    private func parseSSEData(_ data: Data) {
        buffer.append(data)
        
        // 将缓冲区转换为字符串
        guard let bufferString = String(data: buffer, encoding: .utf8) else {
            return
        }
        
        // 按行分割
        let lines = bufferString.components(separatedBy: "\n")
        
        // 保留最后一行（可能不完整）
        if lines.count > 1 {
            // 处理完整的行
            for i in 0..<(lines.count - 1) {
                let line = lines[i].trimmingCharacters(in: .whitespacesAndNewlines)
                processSSELine(line)
            }
            
            // 更新缓冲区为最后一行（可能不完整）
            if let lastLine = lines.last, !lastLine.isEmpty {
                buffer = lastLine.data(using: .utf8) ?? Data()
            } else {
                buffer = Data()
            }
        }
    }
    
    /// 处理单行 SSE 数据
    private func processSSELine(_ line: String) {
        // SSE 格式：data: {...}
        if line.hasPrefix("data: ") {
            let jsonString = String(line.dropFirst(6))
            
            // 检查是否是结束标记
            if jsonString == "[DONE]" {
                print("📡 SSE 流式传输完成")
                onComplete?()
                return
            }
            
            // 解析 JSON
            guard let jsonData = jsonString.data(using: .utf8) else {
                return
            }
            
            do {
                if let json = try JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {
                    // 提取 content 字段
                    if let content = json["content"] as? String {
                        print("📝 收到 token: \(content)")
                        onToken?(content)
                    }
                    // 兼容 OpenAI 格式：choices[0].delta.content
                    else if let choices = json["choices"] as? [[String: Any]],
                            let firstChoice = choices.first,
                            let delta = firstChoice["delta"] as? [String: Any],
                            let content = delta["content"] as? String {
                        print("📝 收到 token: \(content)")
                        onToken?(content)
                    }
                }
            } catch {
                print("⚠️ SSE JSON 解析失败: \(error)")
                print("   原始 JSON: \(jsonString)")
            }
        }
    }
}

// MARK: - URLSessionDataDelegate

extension SSEClient: URLSessionDataDelegate {
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive data: Data) {
        print("📡 收到数据块: \(data.count) 字节")
        parseSSEData(data)
    }
    
    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        if let error = error {
            print("❌ SSE 连接错误: \(error.localizedDescription)")
            onError?(SSEError.connectionFailed(error))
        } else {
            print("✅ SSE 连接正常关闭")
            // 处理缓冲区中剩余的数据
            if !buffer.isEmpty {
                parseSSEData(Data())
            }
            onComplete?()
        }
        
        // 清理
        buffer = Data()
        dataTask = nil
    }
    
    func urlSession(_ session: URLSession, dataTask: URLSessionDataTask, didReceive response: URLResponse, completionHandler: @escaping (URLSession.ResponseDisposition) -> Void) {
        guard let httpResponse = response as? HTTPURLResponse else {
            completionHandler(.cancel)
            onError?(SSEError.invalidData)
            return
        }
        
        print("📡 SSE 响应状态码: \(httpResponse.statusCode)")
        
        if (200...299).contains(httpResponse.statusCode) {
            completionHandler(.allow)
        } else {
            completionHandler(.cancel)
            onError?(SSEError.connectionFailed(NSError(domain: "SSEClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])))
        }
    }
}

