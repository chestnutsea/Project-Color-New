//
//  SimpleColorExtractor.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 1: 简化的主色提取（RGB空间）
//

import Foundation
import CoreGraphics
import Accelerate
import Combine

class SimpleColorExtractor {
    
    // MARK: - 预处理器
    
    private let preprocessor = ImagePreprocessor()
    
    // MARK: - Configuration
    
    struct Config {
        let algorithm: Algorithm
        let quality: Quality
        let autoMergeSimilarColors: Bool
        
        enum Algorithm {
            case labWeighted
            case medianCut
        }
        
        enum Quality {
            case fast      // 100px + 1000 samples
            case balanced  // 256px + 2000 samples (默认)
            case fine      // 512px + 3000 samples
            
            var imageSize: Int {
                switch self {
                case .fast: return 100
                case .balanced: return 256
                case .fine: return 512
                }
            }
            
            var sampleCount: Int {
                switch self {
                case .fast: return 1000
                case .balanced: return 2000
                case .fine: return 3000
                }
            }
        }
        
        static let `default` = Config(
            algorithm: .labWeighted,
            quality: .balanced,
            autoMergeSimilarColors: true
        )
    }
    
    // MARK: - 提取结果
    struct ExtractionResult {
        let dominantColors: [DominantColor]
        let brightnessCDF: [Float]
    }
    
    // MARK: - 提取主色（返回5个）
    func extractDominantColors(
        from cgImage: CGImage,
        count: Int = 5,
        config: Config = .default
    ) -> [DominantColor] {
        let result = extractDominantColorsWithCDF(from: cgImage, count: count, config: config)
        return result.dominantColors
    }
    
    // MARK: - 提取主色和亮度 CDF
    func extractDominantColorsWithCDF(
        from cgImage: CGImage,
        count: Int = 5,
        config: Config = .default
    ) -> ExtractionResult {
        switch config.algorithm {
        case .labWeighted:
            return extractWithLabKMeansAndCDF(cgImage, count: count, config: config)
        case .medianCut:
            return extractWithMedianCutAndCDF(cgImage, count: count, config: config)
        }
    }
    
    // MARK: - 计算亮度累计分布函数（CDF）
    /// 从已有的像素数据计算亮度 CDF
    /// - Parameter pixels: RGB 像素数组（0-1 范围）
    /// - Returns: 256 个累计百分比值（0-1 范围）
    func calculateBrightnessCDF(from pixels: [SIMD3<Float>]) -> [Float] {
        guard !pixels.isEmpty else {
            return Array(repeating: 0, count: 256)
        }
        
        // 1. 计算每个像素的亮度（使用感知亮度公式）
        var histogram = [Int](repeating: 0, count: 256)
        
        for pixel in pixels {
            // 感知亮度：0.299R + 0.587G + 0.114B
            let brightness = 0.299 * pixel.x + 0.587 * pixel.y + 0.114 * pixel.z
            let bin = min(Int(brightness * 255), 255)
            histogram[bin] += 1
        }
        
        // 2. 计算累计分布
        var cdf = [Float](repeating: 0, count: 256)
        var cumulative = 0
        let totalPixels = pixels.count
        
        for i in 0..<256 {
            cumulative += histogram[i]
            cdf[i] = Float(cumulative) / Float(totalPixels)
        }
        
        return cdf
    }
    
    // MARK: - 图像缩放
    private func resizeImage(_ image: CGImage, maxDimension: Int) -> CGImage? {
        let width = image.width
        let height = image.height
        
        let scale: CGFloat
        if width > height {
            scale = CGFloat(maxDimension) / CGFloat(width)
        } else {
            scale = CGFloat(maxDimension) / CGFloat(height)
        }
        
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: nil,
            width: newWidth,
            height: newHeight,
            bitsPerComponent: 8,
            bytesPerRow: newWidth * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.interpolationQuality = .medium
        context.draw(image, in: CGRect(x: 0, y: 0, width: newWidth, height: newHeight))
        
        return context.makeImage()
    }
    
    // MARK: - 提取像素颜色
    private func extractPixels(from image: CGImage) -> [SIMD3<Float>]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 转换为RGB float数组（采样：每2个像素取1个）
        var pixels: [SIMD3<Float>] = []
        pixels.reserveCapacity((width * height) / 4)
        
        for y in stride(from: 0, to: height, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = Float(pixelData[offset]) / 255.0
                let g = Float(pixelData[offset + 1]) / 255.0
                let b = Float(pixelData[offset + 2]) / 255.0
                
                // 过滤完全透明的像素
                let alpha = pixelData[offset + 3]
                if alpha > 10 {
                    pixels.append(SIMD3<Float>(r, g, b))
                }
            }
        }
        
        return pixels
    }
    
    // MARK: - 简化的KMeans聚类
    private struct ColorClusterResult {
        var color: SIMD3<Float>
        var weight: Float
    }
    
    private func simpleKMeans(pixels: [SIMD3<Float>], k: Int) -> [ColorClusterResult] {
        guard !pixels.isEmpty else { return [] }
        
        let maxIterations = 20
        var centroids: [SIMD3<Float>] = []
        
        // 随机初始化质心
        let step = max(1, pixels.count / k)
        for i in 0..<k {
            let index = min(i * step, pixels.count - 1)
            centroids.append(pixels[index])
        }
        
        var assignments = [Int](repeating: 0, count: pixels.count)
        
        // 迭代
        for _ in 0..<maxIterations {
            // 分配像素到最近的质心
            for (pixelIndex, pixel) in pixels.enumerated() {
                var minDistance = Float.greatestFiniteMagnitude
                var closestCentroid = 0
                
                for (centroidIndex, centroid) in centroids.enumerated() {
                    let distance = euclideanDistance(pixel, centroid)
                    if distance < minDistance {
                        minDistance = distance
                        closestCentroid = centroidIndex
                    }
                }
                
                assignments[pixelIndex] = closestCentroid
            }
            
            // 更新质心
            var newCentroids = [SIMD3<Float>](repeating: SIMD3<Float>(0, 0, 0), count: k)
            var counts = [Int](repeating: 0, count: k)
            
            for (pixelIndex, pixel) in pixels.enumerated() {
                let cluster = assignments[pixelIndex]
                newCentroids[cluster] += pixel
                counts[cluster] += 1
            }
            
            for i in 0..<k {
                if counts[i] > 0 {
                    centroids[i] = newCentroids[i] / Float(counts[i])
                }
            }
        }
        
        // 计算权重
        var clusterCounts = [Int](repeating: 0, count: k)
        for assignment in assignments {
            clusterCounts[assignment] += 1
        }
        
        let totalPixels = Float(pixels.count)
        var results: [ColorClusterResult] = []
        
        for i in 0..<k {
            if clusterCounts[i] > 0 {
                results.append(ColorClusterResult(
                    color: centroids[i],
                    weight: Float(clusterCounts[i]) / totalPixels
                ))
            }
        }
        
        // 按权重排序
        results.sort { $0.weight > $1.weight }
        
        return results
    }
    
    // MARK: - 欧氏距离
    private func euclideanDistance(_ a: SIMD3<Float>, _ b: SIMD3<Float>) -> Float {
        let diff = a - b
        return sqrt(diff.x * diff.x + diff.y * diff.y + diff.z * diff.z)
    }
    
    // MARK: - Lab KMeans Implementation
    
    private func extractWithLabKMeans(
        _ cgImage: CGImage,
        count: Int,
        config: Config
    ) -> [DominantColor] {
        let result = extractWithLabKMeansAndCDF(cgImage, count: count, config: config)
        return result.dominantColors
    }
    
    private func extractWithLabKMeansAndCDF(
        _ cgImage: CGImage,
        count: Int,
        config: Config
    ) -> ExtractionResult {
        let imageSize = config.quality.imageSize
        let sampleCount = config.quality.sampleCount
        
        // 1. 使用预处理器：缩放 + 转换到 linear sRGB
        let preprocessConfig = ImagePreprocessor.Config(
            maxDimension: imageSize,
            convertToLinearRGB: true
        )
        
        guard let preprocessed = preprocessor.preprocessForAnalysis(
            cgImage: cgImage,
            config: preprocessConfig
        ) else {
            return ExtractionResult(dominantColors: [], brightnessCDF: Array(repeating: 0, count: 256))
        }
        
        defer {
            preprocessed.freeBuffer()  // 释放缓冲区
        }
        
        // 2. 从 vImage_Buffer 提取 RGB 像素
        let rgbPixels = preprocessor.extractRGBPixels(
            from: preprocessed.pixelBuffer,
            sampleCount: 0  // 先提取全部
        )
        
        // 3. 转换为 SIMD3<Float> 格式
        var allPixels: [SIMD3<Float>] = []
        allPixels.reserveCapacity(rgbPixels.count)
        
        for rgb in rgbPixels {
            let r = Float(rgb[0]) / 255.0
            let g = Float(rgb[1]) / 255.0
            let b = Float(rgb[2]) / 255.0
            allPixels.append(SIMD3<Float>(r, g, b))
        }
        
        // 4. 随机采样
        let pixels = randomSample(allPixels, count: min(sampleCount, allPixels.count))
        
        // 5. RGB → Lab 转换（注意：输入已经是 linear RGB）
        let converter = ColorSpaceConverter()
        let pixelsLab = pixels.map { converter.rgbToLab($0) }
        
        // 5. 计算权重（亮度 × 饱和度）
        let weights = pixelsLab.map { lab -> Float in
            let L = lab.x / 100.0  // 归一化到 0-1
            let a = lab.y
            let b = lab.z
            let saturation = sqrt(a * a + b * b) / 128.0  // 归一化
            return L * saturation
        }
        
        // 6. 带权重的 KMeans 聚类
        let clusters = weightedKMeans(
            points: pixelsLab,
            weights: weights,
            k: count,
            maxIterations: 30
        )
        
        // 7. Lab → RGB 转换
        var results = clusters.map { cluster -> DominantColor in
            let rgb = converter.labToRgb(cluster.centroid)
            return DominantColor(rgb: rgb, weight: cluster.weight)
        }
        
        // 8. 可选：合并相似色
        if config.autoMergeSimilarColors {
            results = mergeSimilarColors(results, threshold: 8.0, converter: converter)
        }
        
        // 9. 按占比排序
        results.sort { $0.weight > $1.weight }
        
        // 10. 计算亮度 CDF（使用全部像素，不是采样的）
        let cdf = calculateBrightnessCDF(from: allPixels)
        
        return ExtractionResult(dominantColors: results, brightnessCDF: cdf)
    }
    
    // MARK: - Median Cut Implementation
    
    private func extractWithMedianCut(
        _ cgImage: CGImage,
        count: Int,
        config: Config
    ) -> [DominantColor] {
        let result = extractWithMedianCutAndCDF(cgImage, count: count, config: config)
        return result.dominantColors
    }
    
    private func extractWithMedianCutAndCDF(
        _ cgImage: CGImage,
        count: Int,
        config: Config
    ) -> ExtractionResult {
        let imageSize = config.quality.imageSize
        
        // 1. 使用预处理器：缩放 + 转换到 linear sRGB
        let preprocessConfig = ImagePreprocessor.Config(
            maxDimension: imageSize,
            convertToLinearRGB: true
        )
        
        guard let preprocessed = preprocessor.preprocessForAnalysis(
            cgImage: cgImage,
            config: preprocessConfig
        ) else {
            return ExtractionResult(dominantColors: [], brightnessCDF: Array(repeating: 0, count: 256))
        }
        
        defer {
            preprocessed.freeBuffer()
        }
        
        // 2. 从 vImage_Buffer 提取 RGB 像素（步进采样）
        let rgbPixels = preprocessor.extractRGBPixels(
            from: preprocessed.pixelBuffer,
            sampleCount: config.quality.sampleCount
        )
        
        // 3. 转换为 SIMD3<Float> 格式
        var pixels: [SIMD3<Float>] = []
        pixels.reserveCapacity(rgbPixels.count)
        
        for rgb in rgbPixels {
            let r = Float(rgb[0]) / 255.0
            let g = Float(rgb[1]) / 255.0
            let b = Float(rgb[2]) / 255.0
            pixels.append(SIMD3<Float>(r, g, b))
        }
        
        // 3. RGB 空间的简单 KMeans
        let clusters = simpleKMeans(pixels: pixels, k: count)
        
        // 4. 转换为 DominantColor
        var results = clusters.map { cluster in
            DominantColor(rgb: cluster.color, weight: cluster.weight)
        }
        
        // 5. 可选：合并相似色
        if config.autoMergeSimilarColors {
            let converter = ColorSpaceConverter()
            results = mergeSimilarColors(results, threshold: 8.0, converter: converter)
        }
        
        // 6. 计算亮度 CDF
        let cdf = calculateBrightnessCDF(from: pixels)
        
        return ExtractionResult(dominantColors: results, brightnessCDF: cdf)
    }
    
    // MARK: - Helper Methods
    
    /// 提取所有像素（不采样）
    private func extractAllPixels(from image: CGImage) -> [SIMD3<Float>]? {
        let width = image.width
        let height = image.height
        let bytesPerPixel = 4
        let bytesPerRow = width * bytesPerPixel
        let totalBytes = height * bytesPerRow
        
        var pixelData = [UInt8](repeating: 0, count: totalBytes)
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            return nil
        }
        
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var pixels: [SIMD3<Float>] = []
        pixels.reserveCapacity(width * height)
        
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * bytesPerRow) + (x * bytesPerPixel)
                let r = Float(pixelData[offset]) / 255.0
                let g = Float(pixelData[offset + 1]) / 255.0
                let b = Float(pixelData[offset + 2]) / 255.0
                let alpha = pixelData[offset + 3]
                
                if alpha > 10 {
                    pixels.append(SIMD3<Float>(r, g, b))
                }
            }
        }
        
        return pixels
    }
    
    /// 随机采样
    private func randomSample(_ pixels: [SIMD3<Float>], count: Int) -> [SIMD3<Float>] {
        guard pixels.count > count else {
            return pixels
        }
        return Array(pixels.shuffled().prefix(count))
    }
    
    /// 带权重的 KMeans 聚类
    private struct WeightedCluster {
        var centroid: SIMD3<Float>
        var weight: Float
    }
    
    private func weightedKMeans(
        points: [SIMD3<Float>],
        weights: [Float],
        k: Int,
        maxIterations: Int
    ) -> [WeightedCluster] {
        guard !points.isEmpty else { return [] }
        
        let converter = ColorSpaceConverter()
        
        // KMeans++ 初始化
        var centroids = kMeansPlusPlusInit(points: points, k: k, converter: converter)
        var assignments = [Int](repeating: 0, count: points.count)
        
        for _ in 0..<maxIterations {
            var changed = false
            
            // 分配阶段（使用欧几里得距离）
            for (i, point) in points.enumerated() {
                var minDistance = Float.greatestFiniteMagnitude
                var closestCluster = 0
                
                for (j, centroid) in centroids.enumerated() {
                    let distance = euclideanDistance(point, centroid)
                    if distance < minDistance {
                        minDistance = distance
                        closestCluster = j
                    }
                }
                
                if assignments[i] != closestCluster {
                    assignments[i] = closestCluster
                    changed = true
                }
            }
            
            if !changed {
                break
            }
            
            // 更新阶段（加权平均）
            var newCentroids = [SIMD3<Float>](repeating: .zero, count: k)
            var totalWeights = [Float](repeating: 0, count: k)
            
            for (i, point) in points.enumerated() {
                let cluster = assignments[i]
                let weight = weights[i]
                newCentroids[cluster] += point * weight
                totalWeights[cluster] += weight
            }
            
            for i in 0..<k {
                if totalWeights[i] > 0 {
                    centroids[i] = newCentroids[i] / totalWeights[i]
                }
            }
        }
        
        // 计算最终权重（按像素数量占比）
        var clusterCounts = [Float](repeating: 0, count: k)
        for assignment in assignments {
            clusterCounts[assignment] += 1
        }
        
        let totalPixels = Float(points.count)
        return centroids.enumerated().compactMap { (i, centroid) in
            guard clusterCounts[i] > 0 else { return nil }
            return WeightedCluster(
                centroid: centroid,
                weight: clusterCounts[i] / totalPixels
            )
        }
    }
    
    /// KMeans++ 初始化
    private func kMeansPlusPlusInit(
        points: [SIMD3<Float>],
        k: Int,
        converter: ColorSpaceConverter
    ) -> [SIMD3<Float>] {
        guard !points.isEmpty else { return [] }
        
        var centroids: [SIMD3<Float>] = []
        
        // 随机选择第一个质心
        centroids.append(points.randomElement()!)
        
        // 选择剩余的质心
        for _ in 1..<k {
            var distances = [Float](repeating: Float.greatestFiniteMagnitude, count: points.count)
            
            // 计算每个点到最近质心的距离（使用欧几里得距离）
            for (i, point) in points.enumerated() {
                for centroid in centroids {
                    let distance = euclideanDistance(point, centroid)
                    distances[i] = min(distances[i], distance)
                }
            }
            
            // 按距离平方加权随机选择下一个质心
            let distanceSquares = distances.map { $0 * $0 }
            let totalWeight = distanceSquares.reduce(0, +)
            
            guard totalWeight > 0 else { break }
            
            var random = Float.random(in: 0..<totalWeight)
            for (i, weight) in distanceSquares.enumerated() {
                random -= weight
                if random <= 0 {
                    centroids.append(points[i])
                    break
                }
            }
        }
        
        return centroids
    }
    
    /// 合并相似色
    private func mergeSimilarColors(
        _ colors: [DominantColor],
        threshold: Float,
        converter: ColorSpaceConverter
    ) -> [DominantColor] {
        var merged = colors
        var i = 0
        
        while i < merged.count {
            var j = i + 1
            while j < merged.count {
                let lab1 = converter.rgbToLab(merged[i].rgb)
                let lab2 = converter.rgbToLab(merged[j].rgb)
                let distance = euclideanDistance(lab1, lab2)
                
                if distance < threshold {
                    // 合并 j 到 i（按权重加权平均）
                    let totalWeight = merged[i].weight + merged[j].weight
                    let w1 = merged[i].weight / totalWeight
                    let w2 = merged[j].weight / totalWeight
                    
                    let mergedRgb = merged[i].rgb * w1 + merged[j].rgb * w2
                    merged[i] = DominantColor(rgb: mergedRgb, weight: totalWeight)
                    merged.remove(at: j)
                } else {
                    j += 1
                }
            }
            i += 1
        }
        
        return merged
    }
}

