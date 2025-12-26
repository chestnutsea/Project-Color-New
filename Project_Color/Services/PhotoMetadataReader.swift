//
//  PhotoMetadataReader.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/19.
//  读取照片的 EXIF、地理位置、相机参数等元数据
//

import Foundation
import Photos
import ImageIO

/// 照片元数据
struct PhotoMetadata: Codable {
    // EXIF 信息
    var aperture: Float?           // 光圈（f值）
    var shutterSpeed: String?      // 快门速度（如 "1/125"）
    var iso: Int?                  // ISO
    var focalLength: Float?        // 焦距（mm）
    
    // 相机信息
    var cameraMake: String?        // 相机品牌
    var cameraModel: String?       // 相机型号
    var lensModel: String?         // 镜头型号
    
    // 时间信息
    var captureDate: Date?         // 拍摄日期
}

/// 照片元数据读取器
class PhotoMetadataReader {
    
    // MARK: - 主要方法
    
    /// 从 PHAsset 读取元数据
    /// - Parameter asset: PHAsset 对象
    /// - Returns: PhotoMetadata（如果成功）
    func readMetadata(from asset: PHAsset) async -> PhotoMetadata? {
        var metadata = PhotoMetadata()
        
        // 1. 先设置回退值（PHAsset 的创建日期）
        let fallbackDate = asset.creationDate
        
        // 2. 从 ImageIO 读取详细的 EXIF 信息（优先读取 EXIF 时间）
        if let imageSource = await loadImageSource(from: asset) {
            if let exifMetadata = readEXIFMetadata(from: imageSource) {
                metadata.aperture = exifMetadata.aperture
                metadata.shutterSpeed = exifMetadata.shutterSpeed
                metadata.iso = exifMetadata.iso
                metadata.focalLength = exifMetadata.focalLength
                metadata.cameraMake = exifMetadata.cameraMake
                metadata.cameraModel = exifMetadata.cameraModel
                metadata.lensModel = exifMetadata.lensModel
                
                // 优先使用 EXIF 的拍摄时间
                if let exifDate = exifMetadata.captureDate {
                    metadata.captureDate = exifDate
                } else {
                    // 如果没有 EXIF 时间，使用 PHAsset 的创建日期
                    metadata.captureDate = fallbackDate
                }
            } else {
                // 如果无法读取 EXIF，使用 PHAsset 的创建日期
                metadata.captureDate = fallbackDate
            }
        } else {
            // 如果无法加载图片源，使用 PHAsset 的创建日期
            metadata.captureDate = fallbackDate
        }
        
        return metadata
    }
    
    // MARK: - 加载 CGImageSource
    
    /// 从 PHAsset 加载 CGImageSource
    private func loadImageSource(from asset: PHAsset) async -> CGImageSource? {
        return await withCheckedContinuation { continuation in
            var hasResumed = false  // ✅ 防止重复 resume
            let options = PHImageRequestOptions()
            options.isSynchronous = false
            options.deliveryMode = .highQualityFormat
            options.isNetworkAccessAllowed = true
            options.version = .current
            
            PHImageManager.default().requestImageDataAndOrientation(
                for: asset,
                options: options
            ) { data, _, _, _ in
                guard !hasResumed else { return }
                hasResumed = true
                
                guard let data = data else {
                    continuation.resume(returning: nil)
                    return
                }
                
                let imageSource = CGImageSourceCreateWithData(data as CFData, nil)
                continuation.resume(returning: imageSource)
            }
        }
    }
    
    // MARK: - 从图片数据读取元数据（隐私模式）
    
    /// 从图片数据直接读取 EXIF 元数据（不需要 PHAsset）
    /// - Parameter imageData: 图片的原始数据
    /// - Returns: PhotoMetadata（如果成功）
    func readMetadata(from imageData: Data) -> PhotoMetadata? {
        guard let imageSource = CGImageSourceCreateWithData(imageData as CFData, nil) else {
            print("⚠️ PhotoMetadataReader: 无法创建 CGImageSource")
            return nil
        }
        
        return readEXIFMetadata(from: imageSource)
    }
    
    // MARK: - 读取 EXIF 元数据
    
    /// 从 CGImageSource 读取 EXIF 元数据
    private func readEXIFMetadata(from imageSource: CGImageSource) -> PhotoMetadata? {
        guard let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] else {
            return nil
        }
        
        var metadata = PhotoMetadata()
        
        // 读取 EXIF 字典
        if let exif = properties[kCGImagePropertyExifDictionary as String] as? [String: Any] {
            // 拍摄时间（优先读取 DateTimeOriginal）
            if let dateTimeOriginal = exif[kCGImagePropertyExifDateTimeOriginal as String] as? String {
                metadata.captureDate = parseEXIFDate(dateTimeOriginal)
            } else if let dateTimeDigitized = exif[kCGImagePropertyExifDateTimeDigitized as String] as? String {
                // 如果没有 DateTimeOriginal，尝试 DateTimeDigitized
                metadata.captureDate = parseEXIFDate(dateTimeDigitized)
            }
            
            // 光圈
            if let apertureValue = exif[kCGImagePropertyExifFNumber as String] as? NSNumber {
                metadata.aperture = apertureValue.floatValue
            }
            
            // 快门速度
            if let exposureTime = exif[kCGImagePropertyExifExposureTime as String] as? NSNumber {
                metadata.shutterSpeed = formatShutterSpeed(exposureTime.doubleValue)
            }
            
            // ISO
            if let isoArray = exif[kCGImagePropertyExifISOSpeedRatings as String] as? [NSNumber],
               let iso = isoArray.first {
                metadata.iso = iso.intValue
            }
            
            // 焦距
            if let focalLength = exif[kCGImagePropertyExifFocalLength as String] as? NSNumber {
                metadata.focalLength = focalLength.floatValue
            }
            
            // 镜头型号
            if let lensModel = exif[kCGImagePropertyExifLensModel as String] as? String {
                metadata.lensModel = lensModel
            }
        }
        
        // 读取 TIFF 字典（相机信息）
        if let tiff = properties[kCGImagePropertyTIFFDictionary as String] as? [String: Any] {
            // 相机品牌
            if let make = tiff[kCGImagePropertyTIFFMake as String] as? String {
                metadata.cameraMake = make.trimmingCharacters(in: .whitespaces)
            }
            
            // 相机型号
            if let model = tiff[kCGImagePropertyTIFFModel as String] as? String {
                metadata.cameraModel = model.trimmingCharacters(in: .whitespaces)
            }
        }
        
        return metadata
    }
    
    // MARK: - 辅助方法
    
    /// 解析 EXIF 日期时间字符串
    /// EXIF 日期格式通常是 "2023:12:25 14:30:00" 或 "2023-12-25T14:30:00"
    /// - Parameter dateString: EXIF 日期时间字符串
    /// - Returns: Date 对象（如果解析成功）
    private func parseEXIFDate(_ dateString: String) -> Date? {
        let trimmed = dateString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        
        // EXIF 标准格式：YYYY:MM:DD HH:MM:SS（使用冒号分隔日期）
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy:MM:dd HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
                formatter.locale = Locale(identifier: "en_US_POSIX")
                formatter.timeZone = TimeZone.current
                return formatter
            }()
        ]
        
        // 尝试使用不同的格式解析
        for formatter in formatters {
            if let date = formatter.date(from: trimmed) {
                return date
            }
        }
        
        return nil
    }
    
    /// 格式化快门速度
    /// - Parameter exposureTime: 曝光时间（秒）
    /// - Returns: 格式化的快门速度字符串（如 "1/125"）
    private func formatShutterSpeed(_ exposureTime: Double) -> String {
        if exposureTime >= 1.0 {
            return String(format: "%.1f\"", exposureTime)
        } else {
            let denominator = Int(1.0 / exposureTime)
            return "1/\(denominator)"
        }
    }
    
}

