//
//  TLSConfig.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/12/12.
//  TLS 证书验证配置
//

import Foundation

/// TLS 证书验证配置
struct TLSConfig {
    
    /// 是否启用严格的证书验证
    /// - true: 严格验证证书（生产环境推荐）
    /// - false: 允许自签名证书（仅开发环境）
    static let strictValidation: Bool = {
        #if DEBUG
        return false  // 开发环境：允许自签名证书
        #else
        return true   // 生产环境：严格验证
        #endif
    }()
    
    /// 受信任的主机列表（用于开发环境的自签名证书）
    /// 注意：生产环境不应该使用此列表
    static let trustedHosts: Set<String> = [
        // Aliyun Function Compute 域名
        ".fcapp.run",
        ".fc.aliyuncs.com",
        
        // 本地开发环境
        "localhost",
        "127.0.0.1",
        
        // 添加你的其他受信任主机（仅开发环境）
        // 例如：".example.com"
    ]
    
    /// 检查主机是否在受信任列表中
    /// - Parameter host: 主机名
    /// - Returns: 是否受信任
    static func isTrustedHost(_ host: String) -> Bool {
        // 如果启用严格验证，不使用受信任列表
        if strictValidation {
            return false
        }
        
        // 检查是否完全匹配
        if trustedHosts.contains(host) {
            return true
        }
        
        // 检查是否匹配通配符域名
        for trustedHost in trustedHosts {
            if trustedHost.hasPrefix(".") {
                // 通配符匹配（例如 ".fcapp.run" 匹配 "xxx.fcapp.run"）
                if host.hasSuffix(trustedHost) || host.contains(trustedHost.dropFirst()) {
                    return true
                }
            }
        }
        
        return false
    }
    
    /// 是否允许证书固定（Certificate Pinning）
    /// 生产环境建议启用，需要预先获取服务器证书的公钥哈希
    static let enableCertificatePinning: Bool = false
    
    /// 固定的证书公钥哈希（SHA256）
    /// 格式：Base64 编码的 SHA256 哈希值
    /// 获取方法：openssl s_client -connect domain.com:443 | openssl x509 -pubkey -noout | openssl pkey -pubin -outform der | openssl dgst -sha256 -binary | openssl enc -base64
    static let pinnedPublicKeyHashes: Set<String> = [
        // 添加你的服务器证书公钥哈希
        // 例如：
        // "AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA="
    ]
}
