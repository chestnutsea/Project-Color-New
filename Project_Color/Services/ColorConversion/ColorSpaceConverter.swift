//
//  ColorSpaceConverter.swift
//  Project_Color
//
//  Created by AI Assistant on 2025/11/9.
//  Micro-Phase 2: 颜色空间转换（RGB ↔ LAB）
//

import Foundation
import simd

class ColorSpaceConverter {
    
    // MARK: - RGB to LAB (D65 白点)
    
    /// 将 RGB (0-1) 转换为 CIE LAB (D65)
    func rgbToLab(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        // Step 1: RGB → XYZ
        let xyz = rgbToXYZ(rgb)
        
        // Step 2: XYZ → LAB
        let lab = xyzToLab(xyz)
        
        return lab
    }
    
    /// RGB (0-1) → XYZ (使用 sRGB 色彩空间，D65 白点)
    private func rgbToXYZ(_ rgb: SIMD3<Float>) -> SIMD3<Float> {
        // 1. Gamma 校正（sRGB → 线性RGB）
        let linear = rgb.map { channel -> Float in
            if channel <= 0.04045 {
                return channel / 12.92
            } else {
                return pow((channel + 0.055) / 1.055, 2.4)
            }
        }
        
        // 2. 线性RGB → XYZ (使用 D65 白点的转换矩阵)
        let x = linear.x * 0.4124564 + linear.y * 0.3575761 + linear.z * 0.1804375
        let y = linear.x * 0.2126729 + linear.y * 0.7151522 + linear.z * 0.0721750
        let z = linear.x * 0.0193339 + linear.y * 0.1191920 + linear.z * 0.9503041
        
        return SIMD3<Float>(x, y, z)
    }
    
    /// XYZ → LAB (D65 白点)
    private func xyzToLab(_ xyz: SIMD3<Float>) -> SIMD3<Float> {
        // D65 白点参考值
        let xn: Float = 0.95047
        let yn: Float = 1.00000
        let zn: Float = 1.08883
        
        // 归一化
        let xr = xyz.x / xn
        let yr = xyz.y / yn
        let zr = xyz.z / zn
        
        // f(t) 函数
        let fx = labF(xr)
        let fy = labF(yr)
        let fz = labF(zr)
        
        // 计算 LAB
        let L = 116.0 * fy - 16.0
        let a = 500.0 * (fx - fy)
        let b = 200.0 * (fy - fz)
        
        return SIMD3<Float>(L, a, b)
    }
    
    /// LAB 转换的辅助函数
    private func labF(_ t: Float) -> Float {
        let delta: Float = 6.0 / 29.0
        let deltaCubed = delta * delta * delta
        
        if t > deltaCubed {
            return pow(t, 1.0 / 3.0)
        } else {
            return (t / (3.0 * delta * delta)) + (4.0 / 29.0)
        }
    }
    
    // MARK: - LAB to RGB
    
    /// 将 CIE LAB 转换为 RGB (0-1)
    func labToRgb(_ lab: SIMD3<Float>) -> SIMD3<Float> {
        // Step 1: LAB → XYZ
        let xyz = labToXYZ(lab)
        
        // Step 2: XYZ → RGB
        let rgb = xyzToRGB(xyz)
        
        // 限制在 [0, 1] 范围
        return simd_clamp(rgb, SIMD3<Float>(0, 0, 0), SIMD3<Float>(1, 1, 1))
    }
    
    /// LAB → XYZ
    private func labToXYZ(_ lab: SIMD3<Float>) -> SIMD3<Float> {
        let L = lab.x
        let a = lab.y
        let b = lab.z
        
        // D65 白点
        let xn: Float = 0.95047
        let yn: Float = 1.00000
        let zn: Float = 1.08883
        
        let fy = (L + 16.0) / 116.0
        let fx = a / 500.0 + fy
        let fz = fy - b / 200.0
        
        let xr = labFInverse(fx)
        let yr = labFInverse(fy)
        let zr = labFInverse(fz)
        
        let x = xr * xn
        let y = yr * yn
        let z = zr * zn
        
        return SIMD3<Float>(x, y, z)
    }
    
    /// LAB f函数的逆
    private func labFInverse(_ t: Float) -> Float {
        let delta: Float = 6.0 / 29.0
        
        if t > delta {
            return t * t * t
        } else {
            return 3.0 * delta * delta * (t - 4.0 / 29.0)
        }
    }
    
    /// XYZ → RGB
    private func xyzToRGB(_ xyz: SIMD3<Float>) -> SIMD3<Float> {
        // XYZ → 线性RGB (D65 白点)
        let r =  xyz.x * 3.2404542 + xyz.y * -1.5371385 + xyz.z * -0.4985314
        let g =  xyz.x * -0.9692660 + xyz.y * 1.8760108 + xyz.z * 0.0415560
        let b =  xyz.x * 0.0556434 + xyz.y * -0.2040259 + xyz.z * 1.0572252
        
        let linear = SIMD3<Float>(r, g, b)
        
        // 线性RGB → sRGB (反向 Gamma 校正)
        let srgb = linear.map { channel -> Float in
            if channel <= 0.0031308 {
                return 12.92 * channel
            } else {
                return 1.055 * pow(channel, 1.0 / 2.4) - 0.055
            }
        }
        
        return srgb
    }
    
    // MARK: - 色差计算（CIEDE2000）
    
    /// 计算两个 LAB 颜色之间的色差（CIEDE2000）
    /// - Parameters:
    ///   - lab1: 第一个颜色的LAB值 (L, a, b)
    ///   - lab2: 第二个颜色的LAB值 (L, a, b)
    ///   - kL: 亮度权重因子，默认1.0
    ///   - kC: 色度权重因子，默认1.0
    ///   - kH: 色相权重因子，默认1.0
    /// - Returns: CIEDE2000色差值 ΔE00
    func deltaE(_ lab1: SIMD3<Float>, _ lab2: SIMD3<Float>, kL: Float = 1.0, kC: Float = 1.0, kH: Float = 1.0) -> Float {
        let L1 = lab1.x
        let a1 = lab1.y
        let b1 = lab1.z
        
        let L2 = lab2.x
        let a2 = lab2.y
        let b2 = lab2.z
        
        // Step 1: 计算色度 C1, C2
        let C1 = sqrt(a1 * a1 + b1 * b1)
        let C2 = sqrt(a2 * a2 + b2 * b2)
        
        // Step 2: 计算平均色度 C̄
        let Cbar = (C1 + C2) / 2.0
        
        // Step 3: 计算 G（a* 修正系数）
        let Cbar7 = pow(Cbar, 7)
        let G = 0.5 * (1.0 - sqrt(Cbar7 / (Cbar7 + pow(25.0, 7))))
        
        // Step 4: 修正 a* → a'
        let a1_prime = (1.0 + G) * a1
        let a2_prime = (1.0 + G) * a2
        
        // Step 5: 重新计算色度 C'
        let C1_prime = sqrt(a1_prime * a1_prime + b1 * b1)
        let C2_prime = sqrt(a2_prime * a2_prime + b2 * b2)
        
        // Step 6: 计算色相角 h' (度数)
        let h1_prime = computeHuePrime(a: a1_prime, b: b1)
        let h2_prime = computeHuePrime(a: a2_prime, b: b2)
        
        // Step 7: 计算 ΔL', ΔC', ΔH'
        let deltaL_prime = L2 - L1
        let deltaC_prime = C2_prime - C1_prime
        
        // 计算 Δh' (色相角差异，需要考虑周期性)
        var deltah_prime: Float = 0.0
        if C1_prime * C2_prime != 0.0 {
            let diff = h2_prime - h1_prime
            if abs(diff) <= 180.0 {
                deltah_prime = diff
            } else if diff > 180.0 {
                deltah_prime = diff - 360.0
            } else {
                deltah_prime = diff + 360.0
            }
        }
        
        // 计算 ΔH' (色相差)
        let deltaH_prime = 2.0 * sqrt(C1_prime * C2_prime) * sin(degreesToRadians(deltah_prime / 2.0))
        
        // Step 8: 计算平均值 L̄', C̄', H̄'
        let Lbar_prime = (L1 + L2) / 2.0
        let Cbar_prime = (C1_prime + C2_prime) / 2.0
        
        var Hbar_prime: Float = 0.0
        if C1_prime * C2_prime != 0.0 {
            let sum = h1_prime + h2_prime
            if abs(h1_prime - h2_prime) <= 180.0 {
                Hbar_prime = sum / 2.0
            } else if sum < 360.0 {
                Hbar_prime = (sum + 360.0) / 2.0
            } else {
                Hbar_prime = (sum - 360.0) / 2.0
            }
        }
        
        // Step 9: 计算 T（色相权重因子）
        let T = 1.0 - 0.17 * cos(degreesToRadians(Hbar_prime - 30.0))
                    + 0.24 * cos(degreesToRadians(2.0 * Hbar_prime))
                    + 0.32 * cos(degreesToRadians(3.0 * Hbar_prime + 6.0))
                    - 0.20 * cos(degreesToRadians(4.0 * Hbar_prime - 63.0))
        
        // Step 10: 计算亮度权重 SL
        let Lbar_prime_minus_50_squared = (Lbar_prime - 50.0) * (Lbar_prime - 50.0)
        let SL = 1.0 + (0.015 * Lbar_prime_minus_50_squared) / sqrt(20.0 + Lbar_prime_minus_50_squared)
        
        // Step 11: 计算色度权重 SC
        let SC = 1.0 + 0.045 * Cbar_prime
        
        // Step 12: 计算色相权重 SH
        let SH = 1.0 + 0.015 * Cbar_prime * T
        
        // Step 13: 计算旋转项 RT（处理蓝色区域的不对称性）
        let deltaTheta = 30.0 * exp(-pow((Hbar_prime - 275.0) / 25.0, 2))
        let Cbar_prime_7 = pow(Cbar_prime, 7)
        let RC = 2.0 * sqrt(Cbar_prime_7 / (Cbar_prime_7 + pow(25.0, 7)))
        let RT = -RC * sin(degreesToRadians(2.0 * deltaTheta))
        
        // Step 14: 计算最终的 ΔE00
        let term1 = deltaL_prime / (kL * SL)
        let term2 = deltaC_prime / (kC * SC)
        let term3 = deltaH_prime / (kH * SH)
        let term4 = RT * term2 * term3
        
        let deltaE00 = sqrt(term1 * term1 + term2 * term2 + term3 * term3 + term4)
        
        return deltaE00
    }
    
    // MARK: - CIEDE2000辅助函数
    
    /// 计算色相角 h' (度数)
    private func computeHuePrime(a: Float, b: Float) -> Float {
        if a == 0.0 && b == 0.0 {
            return 0.0
        }
        
        let hueRadians = atan2(b, a)
        var hueDegrees = radiansToDegrees(hueRadians)
        
        if hueDegrees < 0.0 {
            hueDegrees += 360.0
        }
        
        return hueDegrees
    }
    
    /// 角度转弧度
    private func degreesToRadians(_ degrees: Float) -> Float {
        return degrees * Float.pi / 180.0
    }
    
    /// 弧度转角度
    private func radiansToDegrees(_ radians: Float) -> Float {
        return radians * 180.0 / Float.pi
    }
    
    // MARK: - RGB to HSL（保留原有功能）
    
    /// RGB to HSL 转换
    func rgbToHSL(_ rgb: SIMD3<Float>) -> (h: Float, s: Float, l: Float) {
        let r = rgb.x
        let g = rgb.y
        let b = rgb.z
        
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC
        
        // Lightness
        let l = (maxC + minC) / 2.0
        
        // Saturation
        var s: Float = 0
        if delta != 0 {
            s = delta / (1 - abs(2 * l - 1))
        }
        
        // Hue
        var h: Float = 0
        if delta != 0 {
            if maxC == r {
                h = 60 * (((g - b) / delta).truncatingRemainder(dividingBy: 6))
            } else if maxC == g {
                h = 60 * (((b - r) / delta) + 2)
            } else {
                h = 60 * (((r - g) / delta) + 4)
            }
        }
        
        if h < 0 {
            h += 360
        }
        
        return (h: h, s: s, l: l)
    }
}

// MARK: - SIMD3 扩展（map 方法）
extension SIMD3 where Scalar == Float {
    func map(_ transform: (Float) -> Float) -> SIMD3<Float> {
        return SIMD3<Float>(
            transform(self.x),
            transform(self.y),
            transform(self.z)
        )
    }
}

