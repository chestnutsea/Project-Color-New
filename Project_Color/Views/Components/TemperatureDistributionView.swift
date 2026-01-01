//
//  TemperatureDistributionView.swift
//  Project_Color
//
//  展示全局每张图的温度（冷暖评分）分布
//

import SwiftUI

struct TemperatureDistributionView: View {
    private enum Layout {
        static let barOpacity: Double = 1.0  // 彩条透明度
        static let labelOpacity: Double = 1.0  // 冷暖文字透明度
        static let saturation: Double = 0.8  // 彩条饱和度（布局常量）
    }
    
    let distribution: WarmCoolDistribution
    let dominantColor: Color  // 全局最 dominant 的颜色（作为后备）
    var photoInfos: [PhotoColorInfo] = []  // 用于获取每张照片的主色
    
    private let barHeight: CGFloat = 12
    private let markerSize: CGFloat = 10  // 与散点图的 pointDiameter 一致
    private let markerOpacity: Double = 0.8  // 圆点透明度（布局常量）
    private let axisHeight: CGFloat = 2
    private let spacing: CGFloat = 12
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(spacing: 4) {
                // 上方：散点轴 + 所有照片的小点
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        // X 轴
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(height: axisHeight)
                            .frame(width: geo.size.width)
                        
                        // 所有照片的小点（使用每张照片最主要的主色，大小和透明度与散点图一致）
                        ForEach(Array(distribution.scores.keys.sorted()), id: \.self) { key in
                            if let score = distribution.scores[key] {
                                Circle()
                                    .fill(colorForPhoto(assetIdentifier: key).opacity(markerOpacity))
                                    .frame(width: markerSize, height: markerSize)
                                    .offset(x: xPosition(for: score.overallScore, in: geo.size.width))
                            }
                        }
                    }
                }
                .frame(height: markerSize + 4)
                
                // 中间：渐变色条
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color(hue: 0.55, saturation: Layout.saturation, brightness: 1.0),  // 蓝色
                        Color(hue: 0.5, saturation: Layout.saturation, brightness: 1.0),   // 青色
                        Color(hue: 0.0, saturation: 0.0, brightness: 0.5),                // 灰色
                        Color(hue: 0.1, saturation: Layout.saturation, brightness: 1.0),  // 橙色
                        Color(hue: 0.0, saturation: Layout.saturation, brightness: 1.0)   // 红色
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .opacity(Layout.barOpacity)
                .frame(height: barHeight)
                .cornerRadius(6)
                
                // 下方：冷、暖标签，分别对齐左右两端
                HStack {
                    Text(L10n.TemperatureDistribution.cool.localized)
                        .font(.caption)
                        .foregroundColor(.blue.opacity(Layout.labelOpacity))  // 与左端颜色一致，透明度与色相环圆一致
                    Spacer()
                    Text(L10n.TemperatureDistribution.warm.localized)
                        .font(.caption)
                        .foregroundColor(.red.opacity(Layout.labelOpacity))  // 与右端颜色一致，透明度与色相环圆一致
                }
            }
        }
        .padding()
    }
    
    // 把 -1 ~ 1 映射到 0 ~ width
    private func xPosition(for temperature: Float, in width: CGFloat) -> CGFloat {
        let normalized = (CGFloat(temperature) + 1) / 2   // 映射到 0~1
        return normalized * width - markerSize / 2
    }
    
    // 获取照片的视觉代表色（5个主色在 LAB 空间的加权平均）
    private func colorForPhoto(assetIdentifier: String) -> Color {
        // 在 photoInfos 中查找对应的照片
        if let photoInfo = photoInfos.first(where: { $0.assetIdentifier == assetIdentifier }) {
            // 使用视觉代表色
            if let visualRGB = photoInfo.visualRepresentativeColor {
                return Color(red: Double(visualRGB.x), green: Double(visualRGB.y), blue: Double(visualRGB.z))
            } else if let primaryColor = photoInfo.dominantColors.first {
                // 如果没有视觉代表色，回退到最主要的主色
                return primaryColor.color
            }
        }
        // 如果找不到，使用全局代表色
        return dominantColor
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

