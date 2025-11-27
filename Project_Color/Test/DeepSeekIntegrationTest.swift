//
//  DeepSeekIntegrationTest.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/16.
//  测试 DeepSeek API 集成
//

import Foundation
import UIKit

/// DeepSeek 集成测试
class DeepSeekIntegrationTest {
    
    // MARK: - Test API Configuration
    
    static func testAPIConfig() {
        print("🧪 Testing API Configuration...")
        
        let config = APIConfig.shared
        
        print("   - API Key: \(config.deepSeekAPIKey.prefix(10))...")
        print("   - Is Valid: \(config.isAPIKeyValid)")
        print("   - Endpoint: \(config.deepSeekEndpoint)")
        
        if config.isAPIKeyValid {
            print("   ✅ API Config is valid")
        } else {
            print("   ❌ API Config is invalid")
        }
    }
    
    // MARK: - Test DeepSeek Service
    
    static func testDeepSeekService() async {
        print("\n🧪 Testing DeepSeek Service...")
        
        let service = DeepSeekService.shared
        
        do {
            let response = try await service.chat(
                systemPrompt: "你是一位色彩专家。",
                userMessage: "请用一句话描述红色。"
            )
            
            print("   ✅ API Request Successful")
            print("   Response: \(response)")
        } catch {
            print("   ❌ API Request Failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Test Color Analysis Evaluator
    
    static func testColorAnalysisEvaluator() async {
        print("\n🧪 Testing Color Analysis Evaluator...")
        
        // 创建测试数据
        let testResult = AnalysisResult()
        testResult.clusters = [
            ColorCluster(
                index: 0,
                centroid: SIMD3<Float>(0.8, 0.2, 0.2),
                colorName: "红色",
                photoCount: 5
            ),
            ColorCluster(
                index: 1,
                centroid: SIMD3<Float>(0.2, 0.4, 0.8),
                colorName: "蓝色",
                photoCount: 3
            )
        ]
        
        let evaluator = ColorAnalysisEvaluator()
        
        // 注意：这个测试使用空图片数组，实际使用时需要提供真实图片
        let emptyImages: [UIImage] = []
        
        do {
            let evaluation = try await evaluator.evaluateColorAnalysis(
                result: testResult,
                compressedImages: emptyImages,
                onUpdate: { @MainActor updatedEvaluation in
                    // 测试中打印实时更新
                    if let overall = updatedEvaluation.overallEvaluation {
                        print("   📝 Streaming: \(overall.fullText.count) chars received...")
                    }
                }
            )
            
            print("   ✅ Evaluation Successful")
            
            if let overall = evaluation.overallEvaluation {
                print("   Overall Evaluation:")
                print("   \(overall.fullText.prefix(100))...")
            }
            
            print("   Cluster Evaluations: \(evaluation.clusterEvaluations.count)")
            for clusterEval in evaluation.clusterEvaluations {
                print("   - \(clusterEval.colorName): \(clusterEval.evaluation.prefix(50))...")
            }
            
        } catch {
            print("   ❌ Evaluation Failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Run All Tests
    
    static func runAllTests() async {
        print("🚀 Running DeepSeek Integration Tests\n")
        print("=" + String(repeating: "=", count: 50))
        
        testAPIConfig()
        await testDeepSeekService()
        await testColorAnalysisEvaluator()
        
        print("\n" + String(repeating: "=", count: 50))
        print("✅ All tests completed\n")
    }
}

// MARK: - Usage Example
/*
 
 // 在 SwiftUI View 中使用:
 
 Button("Test DeepSeek Integration") {
     Task {
         await DeepSeekIntegrationTest.runAllTests()
     }
 }
 
 // 或者在 App 启动时测试:
 
 @main
 struct Project_ColorApp: App {
     init() {
         Task {
             await DeepSeekIntegrationTest.testAPIConfig()
         }
     }
     
     var body: some Scene {
         WindowGroup {
             ContentView()
         }
     }
 }
 
 */

