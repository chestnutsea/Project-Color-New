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

class SimpleColorExtractor {
    
    // MARK: - 提取主色（返回5个）
    func extractDominantColors(from cgImage: CGImage, count: Int = 5) -> [DominantColor] {
        // 1. 下采样图像
        guard let resizedImage = resizeImage(cgImage, maxDimension: 100) else {
            return []
        }
        
        // 2. 提取像素颜色
        guard let pixels = extractPixels(from: resizedImage) else {
            return []
        }
        
        // 3. 使用简化的KMeans提取主色
        let clusters = simpleKMeans(pixels: pixels, k: count)
        
        // 4. 转换为DominantColor
        return clusters.map { cluster in
            DominantColor(rgb: cluster.color, weight: cluster.weight)
        }
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
}

