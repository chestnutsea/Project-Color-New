//
//  ColorCastScatterView.swift
//  Project_Color
//
//  色偏散点图组件 - 显示所有照片的高光和阴影色偏分布
//

import SwiftUI

// MARK: - 色偏散点图视图
struct ColorCastScatterView: View {
    let points: [ColorCastPoint]
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 标题
            HStack {
                Image(systemName: "circle.hexagongrid.fill")
                    .foregroundColor(.purple)
                Text("色偏分析")
                    .font(.headline)
                
                Spacer()
                
                // 图例
                HStack(spacing: 16) {
                    LegendItem(color: .orange, label: "高光")
                    LegendItem(color: .blue, label: "阴影")
                }
                .font(.caption)
            }
            
            // 说明文字
            Text("展示照片中高光和阴影区域的色彩偏向，圆心为中性，距离表示偏色强度")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // 双圆形坐标轴
            DualPolarScatterView(points: points)
                .frame(height: 300)
            
            // 底部标签
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("高光区域")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("亮部的色彩倾向")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("阴影区域")
                        .font(.caption)
                        .fontWeight(.semibold)
                    Text("暗部的色彩倾向")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
}

// MARK: - 图例项
struct LegendItem: View {
    let color: Color
    let label: String
    
    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
        }
    }
}

// MARK: - 预览
struct ColorCastScatterView_Previews: PreviewProvider {
    static let demoPoints: [ColorCastPoint] = [
        // 高光点
        .init(hueDegrees: 30, strength: 0.8, isHighlight: true),
        .init(hueDegrees: 45, strength: 0.6, isHighlight: true),
        .init(hueDegrees: 120, strength: 0.4, isHighlight: true),
        .init(hueDegrees: 200, strength: 0.5, isHighlight: true),
        .init(hueDegrees: 310, strength: 0.7, isHighlight: true),
        
        // 阴影点
        .init(hueDegrees: 220, strength: 0.9, isHighlight: false),
        .init(hueDegrees: 240, strength: 0.7, isHighlight: false),
        .init(hueDegrees: 180, strength: 0.5, isHighlight: false),
        .init(hueDegrees: 300, strength: 0.6, isHighlight: false),
        .init(hueDegrees: 60, strength: 0.3, isHighlight: false)
    ]
    
    static var previews: some View {
        ColorCastScatterView(points: demoPoints)
            .padding()
            .background(Color(.systemGroupedBackground))
            .previewLayout(.sizeThatFits)
    }
}

