//
//  WarmCoolHistogramView.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/16.
//  冷暖色调分布直方图
//

import SwiftUI

struct WarmCoolHistogramView: View {
    let distribution: WarmCoolDistribution
    let dominantClusterHue: Float        // 全局最大占比代表色的色相
    let dominantClusterSaturation: Float  // 饱和度
    let dominantClusterBrightness: Float  // 亮度
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "thermometer")
                    .foregroundColor(.orange)
                Text("冷暖色调分布")
                    .font(.headline)
            }
            
            // 直方图
            GeometryReader { geometry in
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(0..<distribution.histogram.count, id: \.self) { index in
                        histogramBar(
                            index: index,
                            count: distribution.histogram[index],
                            maxCount: distribution.histogram.max() ?? 1,
                            height: geometry.size.height
                        )
                    }
                }
            }
            .frame(height: 180)
            
            // 刻度标签
            HStack {
                Text("冷色调")
                    .font(.caption)
                    .foregroundColor(.blue)
                Spacer()
                Text("中性")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text("暖色调")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            
            // 统计信息
            if !distribution.scores.isEmpty {
                HStack(spacing: 20) {
                    StatLabel(
                        icon: "photo",
                        label: "总照片",
                        value: "\(distribution.scores.count)"
                    )
                    
                    if let avgScore = calculateAverageScore() {
                        StatLabel(
                            icon: avgScore > 0 ? "sun.max.fill" : "snowflake",
                            label: "平均倾向",
                            value: avgScore > 0 ? "暖调 \(String(format: "+%.2f", avgScore))" : "冷调 \(String(format: "%.2f", avgScore))"
                        )
                    }
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // MARK: - 直方图柱子
    
    private func histogramBar(
        index: Int,
        count: Float,
        maxCount: Float,
        height: CGFloat
    ) -> some View {
        let barColor = colorForBar(index: index)
        let barHeight = CGFloat(count / maxCount) * height
        
        return Rectangle()
            .fill(barColor)
            .frame(height: max(2, barHeight))  // 最小高度2，让空柱子也可见
            .cornerRadius(1)
    }
    
    // MARK: - 颜色计算
    
    private func colorForBar(index: Int) -> Color {
        let ratio = Float(index) / Float(distribution.histogram.count - 1)
        let score = -1.0 + 2.0 * ratio  // 映射到 [-1, 1]
        
        // 计算色相偏移，根据评分从冷到暖渐变
        // score = -1 (极冷) → hue偏移 -30°
        // score = 0 (中性) → hue偏移 0°
        // score = +1 (极暖) → hue偏移 +30°
        let hueOffset = score * 30.0
        var hue = dominantClusterHue + hueOffset
        
        // 处理色相环绕
        if hue < 0 {
            hue += 360
        } else if hue >= 360 {
            hue -= 360
        }
        
        // 调整饱和度：极端值降低饱和度，中间值保持
        let saturation: Float
        if abs(score) > 0.7 {
            saturation = dominantClusterSaturation * 0.85  // 极端值略微降低饱和度
        } else {
            saturation = dominantClusterSaturation
        }
        
        return Color(
            hue: Double(hue / 360),
            saturation: Double(saturation),
            brightness: Double(dominantClusterBrightness)
        )
    }
    
    // MARK: - 统计计算
    
    private func calculateAverageScore() -> Float? {
        guard !distribution.scores.isEmpty else { return nil }
        
        let sum = distribution.scores.values.reduce(Float(0)) { $0 + $1.overallScore }
        return sum / Float(distribution.scores.count)
    }
}

// MARK: - 统计标签组件

struct StatLabel: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.caption)
                    .fontWeight(.medium)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    let sampleDistribution = WarmCoolDistribution(
        scores: [:],
        histogram: [1, 2, 3, 5, 8, 12, 15, 18, 20, 18, 15, 12, 8, 5, 3, 2, 1, 1, 1, 1],
        histogramBins: 20,
        minScore: -1.0,
        maxScore: 1.0
    )
    
    return WarmCoolHistogramView(
        distribution: sampleDistribution,
        dominantClusterHue: 210,  // 蓝色
        dominantClusterSaturation: 0.7,
        dominantClusterBrightness: 0.8
    )
    .padding()
}

