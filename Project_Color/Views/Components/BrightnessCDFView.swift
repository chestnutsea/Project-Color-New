//
//  BrightnessCDFView.swift
//  Project_Color
//
//  累计亮度分布（CDF）对比图
//

import SwiftUI

struct BrightnessCDFView: View {
    let photoInfos: [PhotoColorInfo]
    
    var body: some View {
        // 调试：统计有多少照片有 CDF 数据
        let photosWithCDF = photoInfos.filter { $0.brightnessCDF != nil && !($0.brightnessCDF?.isEmpty ?? true) }
        
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .foregroundColor(.blue)
                Text("累计亮度分布（CDF）")
                    .font(.headline)
                Spacer()
                Text("\(photosWithCDF.count)/\(photoInfos.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if photoInfos.isEmpty {
                Text("暂无数据")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if photosWithCDF.isEmpty {
                Text("照片亮度数据正在计算中...")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else {
                GeometryReader { geometry in
                    Canvas { context, size in
                        drawCDFChart(context: context, size: size)
                    }
                    .frame(height: 300)
                }
                .frame(height: 300)
                
                // 图例说明
                Text("每条曲线代表一张照片的亮度累计分布，曲线颜色为照片的主代表色")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(15)
        .shadow(color: .black.opacity(0.1), radius: 5, x: 0, y: 2)
    }
    
    private func drawCDFChart(context: GraphicsContext, size: CGSize) {
        let padding: CGFloat = 40
        let chartWidth = size.width - padding * 2
        let chartHeight = size.height - padding * 2
        
        // 调试日志
        let photosWithCDF = photoInfos.filter { $0.brightnessCDF != nil && !($0.brightnessCDF?.isEmpty ?? true) }
        print("📊 CDF 绘图：总照片数 \(photoInfos.count)，有 CDF 数据 \(photosWithCDF.count)")
        
        // 绘制坐标轴
        drawAxes(context: context, size: size, padding: padding, chartWidth: chartWidth, chartHeight: chartHeight)
        
        // 绘制每张照片的 CDF 曲线
        var drawnCount = 0
        for photoInfo in photoInfos {
            guard let cdf = photoInfo.brightnessCDF, !cdf.isEmpty else {
                continue
            }
            drawnCount += 1
            
            // 获取照片的主代表色（第一个主色）
            let color = photoInfo.dominantColors.first?.color ?? Color.gray
            
            // 绘制 CDF 曲线
            drawCDFCurve(
                context: context,
                cdf: cdf,
                color: color,
                padding: padding,
                chartWidth: chartWidth,
                chartHeight: chartHeight
            )
        }
        
        print("📊 CDF 绘图完成：绘制了 \(drawnCount) 条曲线")
    }
    
    private func drawAxes(context: GraphicsContext, size: CGSize, padding: CGFloat, chartWidth: CGFloat, chartHeight: CGFloat) {
        var contextCopy = context
        
        // X 轴
        let xAxisPath = Path { path in
            path.move(to: CGPoint(x: padding, y: size.height - padding))
            path.addLine(to: CGPoint(x: size.width - padding, y: size.height - padding))
        }
        contextCopy.stroke(xAxisPath, with: .color(.gray), lineWidth: 1)
        
        // Y 轴
        let yAxisPath = Path { path in
            path.move(to: CGPoint(x: padding, y: padding))
            path.addLine(to: CGPoint(x: padding, y: size.height - padding))
        }
        contextCopy.stroke(yAxisPath, with: .color(.gray), lineWidth: 1)
        
        // X 轴标签（亮度 0-255）
        let xLabels = [0, 64, 128, 192, 255]
        for label in xLabels {
            let x = padding + (CGFloat(label) / 255.0) * chartWidth
            let y = size.height - padding + 15
            
            contextCopy.draw(
                Text("\(label)")
                    .font(.caption2)
                    .foregroundColor(.secondary),
                at: CGPoint(x: x, y: y)
            )
        }
        
        // Y 轴标签（百分比 0-100%）
        let yLabels = [0, 25, 50, 75, 100]
        for label in yLabels {
            let x = padding - 20
            let y = size.height - padding - (CGFloat(label) / 100.0) * chartHeight
            
            contextCopy.draw(
                Text("\(label)%")
                    .font(.caption2)
                    .foregroundColor(.secondary),
                at: CGPoint(x: x, y: y)
            )
        }
        
        // 轴标题
        contextCopy.draw(
            Text("亮度")
                .font(.caption)
                .foregroundColor(.secondary),
            at: CGPoint(x: size.width / 2, y: size.height - 5)
        )
        
        contextCopy.draw(
            Text("累计百分比")
                .font(.caption)
                .foregroundColor(.secondary),
            at: CGPoint(x: 10, y: padding / 2)
        )
    }
    
    private func drawCDFCurve(
        context: GraphicsContext,
        cdf: [Float],
        color: Color,
        padding: CGFloat,
        chartWidth: CGFloat,
        chartHeight: CGFloat
    ) {
        var contextCopy = context
        
        let path = Path { path in
            for (index, value) in cdf.enumerated() {
                let x = padding + (CGFloat(index) / 255.0) * chartWidth
                let y = padding + chartHeight - (CGFloat(value) * chartHeight)
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        
        contextCopy.stroke(
            path,
            with: .color(color.opacity(0.6)),
            lineWidth: 1.5
        )
    }
}

// MARK: - 预览
struct BrightnessCDFView_Previews: PreviewProvider {
    static var previews: some View {
        // 创建示例数据
        let samplePhotos: [PhotoColorInfo] = (0..<5).map { i in
            // 生成示例 CDF（不同的分布）
            var cdf = [Float](repeating: 0, count: 256)
            for j in 0..<256 {
                // 不同照片有不同的亮度分布
                let offset = Float(i) * 0.1
                cdf[j] = min(1.0, Float(j) / 255.0 + offset)
            }
            
            var info = PhotoColorInfo(
                assetIdentifier: "sample-\(i)",
                dominantColors: [
                    DominantColor(
                        rgb: SIMD3<Float>(
                            Float.random(in: 0...1),
                            Float.random(in: 0...1),
                            Float.random(in: 0...1)
                        ),
                        weight: 1.0
                    )
                ]
            )
            info.brightnessCDF = cdf
            return info
        }
        
        return BrightnessCDFView(photoInfos: samplePhotos)
            .padding()
            .previewLayout(.sizeThatFits)
    }
}

