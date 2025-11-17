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
    
    /// DeepSeek API Key
    /// 从 Xcode Build Settings 中读取（通过 xcconfig 文件配置）
    var deepSeekAPIKey: String {
        // 尝试从 Info.plist 读取（通过 Build Settings 注入）
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "DEEPSEEK_API_KEY") as? String,
           !apiKey.isEmpty,
           !apiKey.hasPrefix("$") { // 确保不是未替换的变量
            return apiKey
        }
        
        // 如果 Build Settings 未配置，返回空字符串并打印警告
        print("⚠️ DEEPSEEK_API_KEY not found in build settings")
        return ""
    }
    
    /// DeepSeek API Endpoint
    var deepSeekEndpoint: String {
        return "https://api.deepseek.com/v1/chat/completions"
    }
    
    /// 验证 API Key 是否有效
    var isAPIKeyValid: Bool {
        let key = deepSeekAPIKey
        return !key.isEmpty && key.hasPrefix("sk-") && key.count > 20
    }
}

