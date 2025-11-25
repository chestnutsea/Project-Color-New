//
//  TemperatureDistributionView.swift
//  Project_Color
//
//  展示全局每张图的温度（冷暖评分）分布
//

import SwiftUI

struct TemperatureDistributionView: View {
    let distribution: WarmCoolDistribution
    let dominantColor: Color  // 全局最 dominant 的颜色
    
    private let barHeight: CGFloat = 12
    private let markerSize: CGFloat = 8
    private let axisHeight: CGFloat = 2
    private let spacing: CGFloat = 12
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "thermometer")
                    .foregroundColor(.orange)
                Text("温度分布")
                    .font(.headline)
                
                Spacer()
                
                Text("\(distribution.scores.count) 张照片")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            VStack(spacing: spacing) {
                // 上方：渐变色条
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue,
                        Color.cyan,
                        Color.gray,
                        Color.orange,
                        Color.red
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(height: barHeight)
                .cornerRadius(6)
                
                // 下方：X 轴 + 所有照片的小黑点
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // X 轴
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: axisHeight)
                            .frame(width: geo.size.width)
                        
                        // 所有照片的小黑点（使用全局代表色，透明度 0.5）
                        ForEach(Array(distribution.scores.keys.sorted()), id: \.self) { key in
                            if let score = distribution.scores[key] {
                                Circle()
                                    .fill(dominantColor.opacity(0.5))
                                    .frame(width: markerSize, height: markerSize)
                                    .offset(x: xPosition(for: score.overallScore, in: geo.size.width))
                            }
                        }
                    }
                }
                .frame(height: markerSize + 4)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    // 把 -1 ~ 1 映射到 0 ~ width
    private func xPosition(for temperature: Float, in width: CGFloat) -> CGFloat {
        let normalized = (CGFloat(temperature) + 1) / 2   // 映射到 0~1
        return normalized * width - markerSize / 2
    }
}

// MARK: - 预览
struct TemperatureDistributionView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建示例数据
        var sampleScores: [String: AdvancedColorAnalysis] = [:]
        
        // 生成一些随机分布的温度值
        for i in 0..<20 {
            let temperature = Float.random(in: -0.8...0.8)
            sampleScores["photo-\(i)"] = AdvancedColorAnalysis(
                overallScore: temperature,
                labBScore: temperature,
                dominantWarmth: temperature,
                hueWarmth: 0,
                warmPixelRatio: 0,
                coolPixelRatio: 0,
                neutralPixelRatio: 0,
                labBMean: temperature,
                overallWarmth: max(0, temperature),
                overallCoolness: max(0, -temperature),
                slicData: nil,
                hslData: nil,
                colorCastResult: nil
            )
        }
        
        let distribution = WarmCoolDistribution(
            scores: sampleScores,
            histogram: [],
            histogramBins: 20,
            minScore: -1.0,
            maxScore: 1.0
        )
        
        return TemperatureDistributionView(
            distribution: distribution,
            dominantColor: .blue  // 示例颜色
        )
        .padding()
        .background(Color(.systemGroupedBackground))
        .previewLayout(.sizeThatFits)
    }
}

