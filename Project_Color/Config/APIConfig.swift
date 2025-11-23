//
//  APIConfig.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/16.
//  API 配置管理
//

import Foundation

/// API 配置类，用于安全地读取 API 密钥
class APIConfig {
    
    static let shared = APIConfig()
    
    private init() {}
    
    /// Qwen API Key
    /// 从环境变量中读取
    var qwenAPIKey: String {
        // 尝试从环境变量读取
        if let apiKey = ProcessInfo.processInfo.environment["QWEN_API_KEY"],
           !apiKey.isEmpty {
            return apiKey
        }
        
        // 尝试从 Info.plist 读取（通过 Build Settings 注入）
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "QWEN_API_KEY") as? String,
           !apiKey.isEmpty,
           !apiKey.hasPrefix("$") { // 确保不是未替换的变量
            return apiKey
        }
        
        // 如果都未配置，返回空字符串并打印警告
        print("⚠️ QWEN_API_KEY not found in environment or build settings")
        return ""
    }
    
    /// Qwen API Endpoint
    var qwenEndpoint: String {
        return "https://dashscope.aliyuncs.com/compatible-mode/v1/chat/completions"
    }
    
    /// 验证 Qwen API Key 是否有效
    var isQwenAPIKeyValid: Bool {
        let key = qwenAPIKey
        return !key.isEmpty && key.hasPrefix("sk-") && key.count > 20
    }
    
    // MARK: - Deprecated DeepSeek API (保留以便兼容)
    
    /// DeepSeek API Key (已弃用)
    var deepSeekAPIKey: String {
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String,
           !apiKey.isEmpty,
           !apiKey.hasPrefix("$") {
            return apiKey
        }
        return ""
    }
    
    /// DeepSeek API Endpoint (已弃用)
    var deepSeekEndpoint: String {
        return "https://api.deepseek.com/v1/chat/completions"
    }
    
    /// 验证 DeepSeek API Key 是否有效 (已弃用)
    var isAPIKeyValid: Bool {
        let key = deepSeekAPIKey
        return !key.isEmpty && key.hasPrefix("sk-") && key.count > 20
    }
}

