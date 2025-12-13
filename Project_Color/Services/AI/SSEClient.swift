//
//  SSEClient.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/25.
//  Server-Sent Events (SSE) 客户端
//

import Foundation
import CommonCrypto

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
    private var onUsage: ((Int, Int, Int) -> Void)?  // promptTokens, completionTokens, totalTokens
    
    // MARK: - Public Methods
    
    /// 建立 SSE 连接并开始接收数据
    /// - Parameters:
    ///   - url: SSE 端点 URL
    ///   - body: 请求体数据
    ///   - onToken: 每收到一个 token 的回调
    ///   - onComplete: 流式传输完成的回调
    ///   - onError: 错误回调
    ///   - onUsage: 收到 token 使用量统计的回调（可选）
    func connect(
        url: URL,
        body: Data,
        onToken: @escaping (String) -> Void,
        onComplete: @escaping () -> Void,
        onError: @escaping (Error) -> Void,
        onUsage: ((Int, Int, Int) -> Void)? = nil
    ) {
        self.onToken = onToken
        self.onComplete = onComplete
        self.onError = onError
        self.onUsage = onUsage
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
                    // 检查是否包含 usage 信息（通常在最后一个响应中）
                    if let usage = json["usage"] as? [String: Any],
                       let promptTokens = usage["prompt_tokens"] as? Int,
                       let completionTokens = usage["completion_tokens"] as? Int,
                       let totalTokens = usage["total_tokens"] as? Int {
                        // Token 统计会在 QwenVLService 中统一打印，这里只记录
                        onUsage?(promptTokens, completionTokens, totalTokens)
                    }
                    
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
    
    // MARK: - TLS 证书处理
    
    /// 处理 TLS 认证挑战（严格的证书验证）
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        // 检查是否是服务器信任挑战
        guard challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust else {
            completionHandler(.performDefaultHandling, nil)
            return
        }
        
        // 获取服务器信任对象
        guard let serverTrust = challenge.protectionSpace.serverTrust else {
            print("❌ TLS 验证失败: 无法获取服务器信任对象")
            completionHandler(.cancelAuthenticationChallenge, nil)
            return
        }
        
        // 获取主机名
        let host = challenge.protectionSpace.host
        print("🔐 开始验证 TLS 证书，主机: \(host)")
        
        // 验证证书是否有效
        if validateServerTrust(serverTrust, forHost: host) {
            let credential = URLCredential(trust: serverTrust)
            completionHandler(.useCredential, credential)
            print("✅ TLS 证书验证通过")
        } else {
            print("❌ TLS 证书验证失败")
            completionHandler(.cancelAuthenticationChallenge, nil)
        }
    }
    
    /// 验证服务器证书
    /// - Parameters:
    ///   - serverTrust: 服务器信任对象
    ///   - host: 主机名
    /// - Returns: 证书是否有效
    private func validateServerTrust(_ serverTrust: SecTrust, forHost host: String) -> Bool {
        // 1. 设置证书验证策略（验证主机名匹配）
        let policy = SecPolicyCreateSSL(true, host as CFString)
        SecTrustSetPolicies(serverTrust, policy)
        
        // 2. 执行证书评估
        var error: CFError?
        let isValid = SecTrustEvaluateWithError(serverTrust, &error)
        
        if let error = error {
            print("⚠️ 证书评估错误: \(error.localizedDescription)")
        }
        
        // 3. 检查证书链
        if isValid {
            // 获取证书数量
            let certificateCount = SecTrustGetCertificateCount(serverTrust)
            print("📜 证书链长度: \(certificateCount)")
            
            // 检查证书信息（可选）
            if certificateCount > 0 {
                if let certificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {
                    logCertificateInfo(certificate)
                    
                    // 可选：证书固定（Certificate Pinning）
                    if TLSConfig.enableCertificatePinning {
                        return validateCertificatePinning(certificate)
                    }
                }
            }
            
            return true
        }
        
        // 4. 如果标准验证失败，检查是否是已知的可信主机（用于开发环境）
        if TLSConfig.isTrustedHost(host) {
            print("⚠️ 开发模式: 允许受信任的主机（\(host)）")
            return true
        }
        
        return false
    }
    
    /// 验证证书固定（Certificate Pinning）
    /// - Parameter certificate: 证书
    /// - Returns: 是否匹配固定的公钥
    private func validateCertificatePinning(_ certificate: SecCertificate) -> Bool {
        // 获取证书公钥
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            print("❌ 无法获取证书公钥")
            return false
        }
        
        // 导出公钥数据
        var error: Unmanaged<CFError>?
        guard let publicKeyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            print("❌ 无法导出公钥数据")
            return false
        }
        
        // 计算 SHA256 哈希
        let hash = sha256(data: publicKeyData)
        let base64Hash = hash.base64EncodedString()
        
        print("📜 证书公钥哈希: \(base64Hash)")
        
        // 检查是否匹配固定的哈希值
        if TLSConfig.pinnedPublicKeyHashes.contains(base64Hash) {
            print("✅ 证书固定验证通过")
            return true
        } else {
            print("❌ 证书固定验证失败: 公钥哈希不匹配")
            return false
        }
    }
    
    /// 计算 SHA256 哈希
    /// - Parameter data: 数据
    /// - Returns: SHA256 哈希值
    private func sha256(data: Data) -> Data {
        var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        data.withUnsafeBytes {
            _ = CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash)
        }
        return Data(hash)
    }
    
    /// 记录证书信息（用于调试）
    private func logCertificateInfo(_ certificate: SecCertificate) {
        // 获取证书摘要
        var commonName: CFString?
        SecCertificateCopyCommonName(certificate, &commonName)
        
        if let commonName = commonName as String? {
            print("📜 证书 Common Name: \(commonName)")
        }
        
        // 获取证书摘要（Subject）
        if let summary = SecCertificateCopySubjectSummary(certificate) as String? {
            print("📜 证书主题: \(summary)")
        }
    }
}

