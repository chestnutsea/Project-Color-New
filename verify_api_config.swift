#!/usr/bin/env swift
//
//  verify_api_config.swift
//  快速验证 API 配置
//
//  在 Terminal 中运行：swift verify_api_config.swift
//

import Foundation

print("🔍 API 配置验证工具")
print("=" + String(repeating: "=", count: 50))
print("")

// 检查 Secrets.xcconfig 文件
let secretsPath = "Project_Color/Config/Secrets.xcconfig"
let fileManager = FileManager.default

print("1️⃣ 检查 Secrets.xcconfig 文件...")
if fileManager.fileExists(atPath: secretsPath) {
    print("   ✅ 文件存在: \(secretsPath)")
    
    if let content = try? String(contentsOfFile: secretsPath, encoding: .utf8) {
        if content.contains("DEEPSEEK_API_KEY") {
            print("   ✅ 包含 DEEPSEEK_API_KEY 定义")
            
            // 提取 API key
            let lines = content.components(separatedBy: .newlines)
            for line in lines {
                if line.contains("DEEPSEEK_API_KEY") && !line.hasPrefix("//") {
                    let parts = line.components(separatedBy: "=")
                    if parts.count == 2 {
                        let key = parts[1].trimmingCharacters(in: .whitespaces)
                        print("   ✅ API Key: \(key.prefix(10))... (长度: \(key.count))")
                        
                        if key.hasPrefix("sk-") && key.count > 20 {
                            print("   ✅ API Key 格式正确")
                        } else {
                            print("   ❌ API Key 格式可能有误")
                        }
                    }
                }
            }
        } else {
            print("   ❌ 文件不包含 DEEPSEEK_API_KEY")
        }
    }
} else {
    print("   ❌ 文件不存在: \(secretsPath)")
}

print("")
print("2️⃣ 检查 Info.plist 配置...")
let infoPlistPath = "Project_Color/Info.plist"

if fileManager.fileExists(atPath: infoPlistPath) {
    print("   ✅ Info.plist 存在")
    
    if let content = try? String(contentsOfFile: infoPlistPath, encoding: .utf8) {
        if content.contains("DEEPSEEK_API_KEY") {
            print("   ✅ Info.plist 包含 DEEPSEEK_API_KEY")
            
            if content.contains("$(DEEPSEEK_API_KEY)") {
                print("   ✅ 使用了正确的变量引用格式")
            } else {
                print("   ⚠️ 可能没有使用变量引用")
            }
        } else {
            print("   ❌ Info.plist 不包含 DEEPSEEK_API_KEY")
        }
    }
} else {
    print("   ❌ Info.plist 不存在")
}

print("")
print("3️⃣ 检查 APIConfig.swift...")
let apiConfigPath = "Project_Color/Config/APIConfig.swift"

if fileManager.fileExists(atPath: apiConfigPath) {
    print("   ✅ APIConfig.swift 存在")
} else {
    print("   ❌ APIConfig.swift 不存在")
}

print("")
print("=" + String(repeating: "=", count: 50))
print("")
print("📋 下一步操作：")
print("")
print("如果所有检查都通过，但仍然报错 'API key 无效'，")
print("请按照以下步骤在 Xcode 中配置：")
print("")
print("1. 打开 Project_Color.xcodeproj")
print("2. 选择 Project_Color Target")
print("3. Build Settings → 搜索 'User-Defined'")
print("4. 点击 '+' → Add User-Defined Setting")
print("5. 名称: DEEPSEEK_API_KEY")
print("6. 值: sk-02551e4b861b4d7abb754abef5d73ae5")
print("7. Clean Build (Cmd+Shift+K)")
print("8. Build (Cmd+B)")
print("9. Run (Cmd+R)")
print("")
print("详细说明请查看: TROUBLESHOOTING_API_KEY.md")
print("")

