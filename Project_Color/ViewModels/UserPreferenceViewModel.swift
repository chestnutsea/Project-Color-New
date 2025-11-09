//
//  UserPreferenceViewModel.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/9.
//


/*
功能    说明
🎨 聚合所有 ColorSwatchEntity    计算平均明度、饱和度、冷暖比例
🧠 聚合所有 StyleEntity    统计风格分布，如「复古 40%」「奶油风 25%」
📈 计算用户偏好指标    输出如 “你偏好浅色 + 暖色调 + 日系风” 的结果
💾 更新 UserPreferenceEntity    将聚合结果保存为一条记录（便于持久化和展示）
🔄 提供数据给 DashboardView    用于图表展示用户风格与色调偏好
*/

import Foundation
import CoreData
import SwiftUI
import Combine

final class UserPreferenceViewModel: ObservableObject {
    @Published var preference: UserPreferenceEntity?
    
    private let context = CoreDataManager.shared.viewContext

    // MARK: - 计算整体偏好
    func analyzeUserPreference() {
        let colorFetch: NSFetchRequest<ColorSwatchEntity> = ColorSwatchEntity.fetchRequest()
        let styleFetch: NSFetchRequest<StyleEntity> = StyleEntity.fetchRequest()
        
        do {
            let colors = try context.fetch(colorFetch)
            let styles = try context.fetch(styleFetch)
            
            guard !colors.isEmpty else { return }
            
            // 平均明度与饱和度
            let avgL = colors.map { $0.l }.reduce(0, +) / Double(colors.count)
            let avgSaturation = colors.map {
                sqrt(pow($0.a, 2) + pow($0.b, 2)) / 128.0
            }.reduce(0, +) / Double(colors.count)
            
            // 冷暖色占比（依据 a 轴）
            let warmCount = colors.filter { $0.a > 10 }.count
            let coolCount = colors.filter { $0.a < -10 }.count
            let neutralCount = colors.count - warmCount - coolCount
            
            let dominantTone: String
            if warmCount > coolCount { dominantTone = "Warm" }
            else if coolCount > warmCount { dominantTone = "Cool" }
            else { dominantTone = "Neutral" }
            
            // 风格统计
            var styleDistribution: [String: Int] = [:]
            for style in styles {
                styleDistribution[style.label ?? "Unknown", default: 0] += 1
            }
            
            // 更新或创建 UserPreferenceEntity
            let userPref = preference ?? UserPreferenceEntity(context: context)
            userPref.id = userPref.id ?? UUID()
            userPref.avgLightness = avgL
            userPref.avgSaturation = avgSaturation
            userPref.dominantTone = dominantTone
            userPref.lastUpdated = Date()
            
            // 将 styleDistribution 存为 JSON（简化 Transformable 存储）
            if let jsonData = try? JSONSerialization.data(withJSONObject: styleDistribution) {
                userPref.styleDistribution = jsonData
            }

            preference = userPref
            try? CoreDataManager.shared.save(context: context)
            
        } catch {
            print("❌ User preference analysis failed: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 读取现有偏好
    func fetchPreference() {
        let request: NSFetchRequest<UserPreferenceEntity> = UserPreferenceEntity.fetchRequest()
        request.fetchLimit = 1
        do {
            preference = try context.fetch(request).first
        } catch {
            print("❌ Fetch preference failed: \(error.localizedDescription)")
        }
    }
}

