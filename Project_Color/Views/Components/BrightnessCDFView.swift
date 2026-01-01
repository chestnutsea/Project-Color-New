//
//  BrightnessCDFView.swift
//  Project_Color
//
//  累计亮度分布（CDF）对比图
//

import SwiftUI

struct BrightnessCDFView: View {
    private enum Layout {
        static let curveOpacity: Double = 0.8  // CDF 曲线透明度（布局常量）
        static var labelSpace: CGFloat { ChartLabelMetrics.captionLineHeight }  // 标签占用的高度/宽度
    }
    
    let photoInfos: [PhotoColorInfo]
    var showTitle: Bool = true  // 控制是否显示标题
    var fixedChartSize: CGFloat? = nil  // 外部传入的固定图表尺寸（包含标签）
    var labelSpaceOverride: CGFloat? = nil  // 允许外部控制标签占用空间（与卡片计算保持一致）
    
    private var resolvedLabelSpace: CGFloat {
        labelSpaceOverride ?? Layout.labelSpace
    }
    
    var body: some View {
        // 调试：统计有多少照片有 CDF 数据
        let photosWithCDF = photoInfos.filter { $0.brightnessCDF != nil && !($0.brightnessCDF?.isEmpty ?? true) }
        
        if showTitle {
            // 有标题时，使用 VStack 布局
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .foregroundColor(.blue)
                    Text(L10n.AnalysisResult.brightnessCdfTitle.localized)
                        .font(.headline)
                    Spacer()
                    Text("\(photosWithCDF.count)/\(photoInfos.count)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                chartContent(photosWithCDF: photosWithCDF)
                
                // 图例说明
                Text(L10n.AnalysisResult.brightnessCdfDescription.localized)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.top, 8)
            }
            .padding(5)
        } else {
            // 无标题时，使用固定尺寸或自适应
            chartContent(photosWithCDF: photosWithCDF)
        }
    }
    
    @ViewBuilder
    private func chartContent(photosWithCDF: [PhotoColorInfo]) -> some View {
        if photoInfos.isEmpty {
            Text(L10n.BrightnessCDF.noData.localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else if photosWithCDF.isEmpty {
            Text(L10n.AnalysisResult.brightnessCalculating.localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding()
        } else {
            GeometryReader { geometry in
                cdfChartContent(geometry: geometry)
            }
            .frame(width: fixedChartSize, height: fixedChartSize)
        }
    }
    
    @ViewBuilder
    private func cdfChartContent(geometry: GeometryProxy) -> some View {
        // 图表总尺寸
        let chartSize: CGFloat = fixedChartSize ?? min(geometry.size.width, geometry.size.height)
        // 坐标轴长度 = 图表尺寸 - 标签空间
        let axisSize: CGFloat = max(chartSize - resolvedLabelSpace, 0)
        
        // 顶部留出一些空间，避免曲线被截断
        let topPadding: CGFloat = 2
        let adjustedAxisSize = axisSize - topPadding
        
        // 坐标轴区域（为左侧和底部的标签留空间）
        let chartRect = CGRect(
            x: resolvedLabelSpace,
            y: topPadding,
            width: adjustedAxisSize,
            height: adjustedAxisSize
        )
        
        ZStack {
            Canvas { context, size in
                let currentChartSize: CGFloat = fixedChartSize ?? min(size.width, size.height)
                let currentAxisSize: CGFloat = max(currentChartSize - resolvedLabelSpace, 0)
                let currentTopPadding: CGFloat = 2
                let currentAdjustedAxisSize = currentAxisSize - currentTopPadding
                
                // 传递正方形区域给绘制函数，顶部留出空间
                drawCDFChart(
                    context: context,
                    size: size,
                    squareSize: currentAdjustedAxisSize,
                    offsetX: resolvedLabelSpace,
                    offsetY: currentTopPadding
                )
            }
            
            // Y 轴标签：累计百分比，旋转 -90 度
            Text(L10n.AnalysisResult.cumulativePercentage.localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .rotationEffect(.degrees(-90))
                .position(x: resolvedLabelSpace / 2, y: chartRect.midY)
            
            // X 轴标签：亮度
            Text(L10n.AnalysisResult.brightness.localized)
                .font(.caption)
                .foregroundColor(.secondary)
                .position(x: chartRect.midX, y: chartSize - resolvedLabelSpace / 2 + 5)
        }
    }
    
    private func drawCDFChart(context: GraphicsContext, size: CGSize, squareSize: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        // 调试日志
        let photosWithCDF = photoInfos.filter { $0.brightnessCDF != nil && !($0.brightnessCDF?.isEmpty ?? true) }
        print("📊 CDF 绘图：总照片数 \(photoInfos.count)，有 CDF 数据 \(photosWithCDF.count)")
        
        // 绘制坐标轴（使用正方形区域）
        drawAxes(context: context, squareSize: squareSize, offsetX: offsetX, offsetY: offsetY)
        
        // 绘制每张照片的 CDF 曲线
        var drawnCount = 0
        for photoInfo in photoInfos {
            guard let cdf = photoInfo.brightnessCDF, !cdf.isEmpty else {
                continue
            }
            drawnCount += 1
            
            // 使用照片的视觉代表色（5个主色在 LAB 空间的加权平均）
            let color: Color
            if let visualRGB = photoInfo.visualRepresentativeColor {
                color = Color(red: Double(visualRGB.x), green: Double(visualRGB.y), blue: Double(visualRGB.z))
            } else {
                // 如果没有视觉代表色，回退到最主要的主色
                color = photoInfo.dominantColors.first?.color ?? Color.gray
            }
            
            // 绘制 CDF 曲线
            drawCDFCurve(
                context: context,
                cdf: cdf,
                color: color,
                squareSize: squareSize,
                offsetX: offsetX,
                offsetY: offsetY
            )
        }
        
        print("📊 CDF 绘图完成：绘制了 \(drawnCount) 条曲线")
    }
    
    private func drawAxes(context: GraphicsContext, squareSize: CGFloat, offsetX: CGFloat, offsetY: CGFloat) {
        var contextCopy = context
        
        // X 轴（正方形区域的底部）
        let xAxisY = offsetY + squareSize
        let xAxisPath = Path { path in
            path.move(to: CGPoint(x: offsetX, y: xAxisY))
            path.addLine(to: CGPoint(x: offsetX + squareSize, y: xAxisY))
        }
        contextCopy.stroke(xAxisPath, with: .color(Color.secondary.opacity(0.7)), lineWidth: 1)
        
        // Y 轴（正方形区域的左侧）
        let yAxisPath = Path { path in
            path.move(to: CGPoint(x: offsetX, y: offsetY))
            path.addLine(to: CGPoint(x: offsetX, y: offsetY + squareSize))
        }
        contextCopy.stroke(yAxisPath, with: .color(Color.secondary.opacity(0.7)), lineWidth: 1)
        
        // 去掉刻度值，不绘制 X 轴和 Y 轴的数字标签
        // X 轴和 Y 轴标题通过 ZStack overlay 实现，不在 Canvas 中绘制
    }
    
    private func drawCDFCurve(
        context: GraphicsContext,
        cdf: [Float],
        color: Color,
        squareSize: CGFloat,
        offsetX: CGFloat,
        offsetY: CGFloat
    ) {
        var contextCopy = context
        
        let path = Path { path in
            for (index, value) in cdf.enumerated() {
                let x = offsetX + (CGFloat(index) / 255.0) * squareSize
                // 确保当 value = 1.0 时，y 坐标不会超出绘制区域
                // 使用 squareSize - 1 来确保顶部有足够空间显示完整的曲线
                let clampedValue = min(1.0, CGFloat(value))
                let y = offsetY + squareSize - (clampedValue * squareSize)
                
                if index == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
        
        contextCopy.stroke(
            path,
            with: .color(color.opacity(Layout.curveOpacity)),
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
