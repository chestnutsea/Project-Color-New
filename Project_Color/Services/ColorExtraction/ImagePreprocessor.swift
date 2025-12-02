//
//  ImagePreprocessor.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/19.
//  使用 Core Image + Accelerate 进行图像预处理
//

import Foundation
import CoreImage
import CoreGraphics
import Accelerate
#if canImport(UIKit)
import UIKit
#endif
#if canImport(Photos)
import Photos
#endif

/// 图像预处理工具类
/// 使用 Core Image 在 GPU 上缩放图像，并转换到 linear sRGB 色彩空间
class ImagePreprocessor {
    
    // MARK: - 配置
    
    struct Config {
        /// 目标最大尺寸（长边）
        let maxDimension: Int
        
        /// 是否转换到 linear sRGB
        let convertToLinearRGB: Bool
        
        static let `default` = Config(
            maxDimension: 256,
            convertToLinearRGB: true
        )
        
        static let fast = Config(
            maxDimension: 100,
            convertToLinearRGB: true
        )
        
        static let fine = Config(
            maxDimension: 512,
            convertToLinearRGB: true
        )
    }
    
    // MARK: - 预处理结果
    
    struct PreprocessedImage {
        /// 处理后的 CGImage
        let cgImage: CGImage
        
        /// 像素数据（RGBA，8-bit per channel）
        let pixelBuffer: vImage_Buffer
        
        /// 宽度
        let width: Int
        
        /// 高度
        let height: Int
        
        /// 是否已转换到 linear sRGB
        let isLinearRGB: Bool
        
        /// 释放像素缓冲区
        func freeBuffer() {
            pixelBuffer.data.deallocate()
        }
    }
    
    // MARK: - Core Image Context
    
    private let ciContext: CIContext
    
    init() {
        // 创建 Core Image 上下文（使用 GPU）
        let options: [CIContextOption: Any] = [
            .useSoftwareRenderer: false,  // 使用 GPU
            .workingColorSpace: CGColorSpace(name: CGColorSpace.linearSRGB)!
        ]
        self.ciContext = CIContext(options: options)
    }
    
    // MARK: - 主要预处理方法
    
    /// 预处理图像：缩放 + 转换色彩空间 + 提取像素
    /// - Parameters:
    ///   - cgImage: 输入的 CGImage
    ///   - config: 配置
    /// - Returns: 预处理结果
    func preprocessForAnalysis(
        cgImage: CGImage,
        config: Config = .default
    ) -> PreprocessedImage? {
        // 1. 转换为 CIImage
        var ciImage = CIImage(cgImage: cgImage)
        
        // 2. 计算缩放比例
        let width = cgImage.width
        let height = cgImage.height
        let scale: CGFloat
        
        if width > height {
            scale = CGFloat(config.maxDimension) / CGFloat(width)
        } else {
            scale = CGFloat(config.maxDimension) / CGFloat(height)
        }
        
        let newWidth = Int(CGFloat(width) * scale)
        let newHeight = Int(CGFloat(height) * scale)
        
        // 3. 使用 Core Image 在 GPU 上缩放
        if scale < 1.0 {
            let transform = CGAffineTransform(scaleX: scale, y: scale)
            ciImage = ciImage.transformed(by: transform)
        }
        
        // 4. 转换到 linear sRGB 色彩空间（如果需要）
        if config.convertToLinearRGB {
            if let linearColorSpace = CGColorSpace(name: CGColorSpace.linearSRGB) {
                ciImage = ciImage.matchedToWorkingSpace(from: linearColorSpace) ?? ciImage
            }
        }
        
        // 5. 渲染到 CGImage
        let renderRect = CGRect(x: 0, y: 0, width: newWidth, height: newHeight)
        guard let renderedCGImage = ciContext.createCGImage(ciImage, from: renderRect) else {
            print("❌ Core Image 渲染失败")
            return nil
        }
        
        // 6. 使用 Accelerate 提取像素数据到 vImage_Buffer
        guard let pixelBuffer = extractPixelsToBuffer(from: renderedCGImage) else {
            print("❌ 提取像素数据失败")
            return nil
        }
        
        return PreprocessedImage(
            cgImage: renderedCGImage,
            pixelBuffer: pixelBuffer,
            width: newWidth,
            height: newHeight,
            isLinearRGB: config.convertToLinearRGB
        )
    }
    
    // MARK: - 提取像素到 vImage_Buffer
    
    /// 使用 Accelerate 提取像素数据到 vImage_Buffer
    /// - Parameter cgImage: 输入图像
    /// - Returns: vImage_Buffer（RGBA，8-bit per channel）
    private func extractPixelsToBuffer(from cgImage: CGImage) -> vImage_Buffer? {
        let width = cgImage.width
        let height = cgImage.height
        let bytesPerRow = width * 4
        
        // 分配内存
        guard let data = malloc(height * bytesPerRow) else {
            return nil
        }
        
        // 创建 vImage_Buffer
        var buffer = vImage_Buffer(
            data: data,
            height: vImagePixelCount(height),
            width: vImagePixelCount(width),
            rowBytes: bytesPerRow
        )
        
        // 创建 CGContext 来渲染像素
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: buffer.data,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else {
            free(data)
            return nil
        }
        
        // 渲染图像到缓冲区
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        return buffer
    }
    
    // MARK: - 从 vImage_Buffer 提取 RGB 像素（用于聚类）
    
    /// 从 vImage_Buffer 提取 RGB 像素（跳过 Alpha 通道）
    /// - Parameters:
    ///   - buffer: vImage_Buffer
    ///   - sampleCount: 采样数量（0 = 全部像素）
    /// - Returns: RGB 像素数组（每个像素 3 个 UInt8）
    func extractRGBPixels(from buffer: vImage_Buffer, sampleCount: Int = 0) -> [[UInt8]] {
        let width = Int(buffer.width)
        let height = Int(buffer.height)
        let totalPixels = width * height
        
        let data = buffer.data.assumingMemoryBound(to: UInt8.self)
        
        var pixels: [[UInt8]] = []
        
        if sampleCount > 0 && sampleCount < totalPixels {
            // 采样模式
            let step = max(1, totalPixels / sampleCount)
            pixels.reserveCapacity(sampleCount)
            
            for i in Swift.stride(from: 0, to: totalPixels, by: step) {
                let offset = i * 4
                let r = data[offset]
                let g = data[offset + 1]
                let b = data[offset + 2]
                pixels.append([r, g, b])
            }
        } else {
            // 全部像素
            pixels.reserveCapacity(totalPixels)
            
            for i in 0..<totalPixels {
                let offset = i * 4
                let r = data[offset]
                let g = data[offset + 1]
                let b = data[offset + 2]
                pixels.append([r, g, b])
            }
        }
        
        return pixels
    }
    
    // MARK: - 辅助方法：从 PHAsset 加载 CGImage
    
    #if canImport(Photos)
    /// 从 PHAsset 加载 CGImage
    /// - Parameter asset: PHAsset
    /// - Returns: CGImage（如果成功）
    func loadCGImage(from asset: PHAsset) async -> CGImage? {
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .highQualityFormat
        options.isNetworkAccessAllowed = true
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false  // ✅ 防止重复 resume
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .default,
                options: options
            ) { image, _ in
                guard !hasResumed else { return }
                hasResumed = true
                
                if let uiImage = image, let cgImage = uiImage.cgImage {
                    continuation.resume(returning: cgImage)
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    #endif
}

