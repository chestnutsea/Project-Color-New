//
//  CalculateColorView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/11.
//

import SwiftUI

struct CalculateColorView: View {
    enum ColorSpaceType: String, CaseIterable {
        case hex = "HEX"
        case rgb = "RGB"
        case hsl = "HSL"
        case hsv = "HSV"
        case cmyk = "CMYK"
    }
    
    @State private var activeField: ColorSpaceType? = nil
    @State private var colorTexts: [ColorSpaceType: String] = [
        .hex: "", .rgb: "", .hsl: "", .hsv: "", .cmyk: ""
    ]
    @State private var lastValidColor: Color? = nil
    @FocusState private var focusedField: ColorSpaceType?
    
    private let placeholders: [ColorSpaceType: String] = [
        .hex: "#FF0000",
        .rgb: "255, 0, 0",
        .hsl: "0, 100%, 50%",
        .hsv: "0, 100%, 100%",
        .cmyk: "0, 100, 100, 0"
    ]
    
    var body: some View {
        ZStack {
            (lastValidColor ?? .white)
                .ignoresSafeArea()
                .animation(.easeInOut(duration: 0.25), value: lastValidColor)
            
            VStack(spacing: 0) {
                ForEach(ColorSpaceType.allCases, id: \.self) { space in
                    HStack {
                        Text(space.rawValue)
                            .fontWeight(.bold)
                            .frame(width: 80, alignment: .leading)
                            .foregroundColor(.black)
                        
                        ZStack(alignment: .leading) {
                            if colorTexts.values.allSatisfy({ $0.isEmpty }) {
                                Text(placeholders[space]!)
                                    .foregroundColor(.gray)
                                    .opacity(0.5)
                            }
                            TextField("", text: Binding(
                                get: { colorTexts[space]! },
                                set: { newValue in handleInput(for: space, newValue: newValue) }
                            ))
                            .focused($focusedField, equals: space)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(.black)
                            .font(.system(size: 16))
                            .frame(height: 60)
                            .background(Color.clear)
                        }
                    }
                }
            }
            .padding(.horizontal, 24)
            .onChange(of: focusedField) { newFocus in
                activeField = newFocus
            }
        }
    }
}

extension CalculateColorView {
    // MARK: - 输入逻辑处理
    private func handleInput(for space: ColorSpaceType, newValue rawInput: String) {
        let input = normalizeInput(rawInput)
        
        colorTexts[space] = input
        
        // 如果输入为空，清空所有字段
        guard !input.isEmpty else {
            for key in ColorSpaceType.allCases where key != space {
                colorTexts[key] = ""
            }
            lastValidColor = nil
            return
        }
        
        // 校验并解析颜色
        guard let uiColor = parseColor(space: space, input: input) else {
            // 输入无效时，清空其他所有字段
            for key in ColorSpaceType.allCases where key != space {
                colorTexts[key] = ""
            }
            lastValidColor = nil
            return
        }
        
        // 输入有效时，同步更新其他栏
        syncAllSpaces(from: uiColor, except: space)
        lastValidColor = Color(uiColor)
    }
    
    // MARK: - 全角→半角 + 去空格
    private func normalizeInput(_ str: String) -> String {
        var s = str
        s = s.unicodeScalars.map { scalar in
            let value = scalar.value
            if (0xFF01...0xFF5E).contains(value) {
                return Character(UnicodeScalar(value - 0xFEE0)!)
            } else if value == 0x3000 {
                return Character(" ")
            } else {
                return Character(scalar)
            }
        }.map(String.init).joined()
        
        s = s
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: "％", with: "%")
            .replacingOccurrences(of: "＃", with: "#")
            .replacingOccurrences(of: "\\s+", with: "", options: .regularExpression)
        
        return s
    }
    
    // MARK: - 解析颜色
    private func parseColor(space: ColorSpaceType, input: String) -> UIColor? {
        switch space {
        case .hex:
            let value = input.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            guard let rgb = hexToRgb(value) else { return nil }
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        case .rgb:
            let parts = input.split(separator: ",").compactMap { Double($0) }
            guard parts.count == 3,
                  parts.allSatisfy({ (0...255).contains($0) }) else { return nil }
            return UIColor(red: parts[0]/255, green: parts[1]/255, blue: parts[2]/255, alpha: 1)
        case .hsl:
            guard let rgb = hslToRgb(input) else { return nil }
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        case .hsv:
            guard let rgb = hsvToRgb(input) else { return nil }
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        case .cmyk:
            guard let rgb = cmykToRgb(input) else { return nil }
            return UIColor(red: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
        }
    }
    
    // MARK: - 同步所有栏
    private func syncAllSpaces(from uiColor: UIColor, except origin: ColorSpaceType) {
        guard let components = uiColor.cgColor.components else { return }
        // 确保 RGB 值在 0-1 范围内
        let r = max(0, min(1, components[0]))
        let g = max(0, min(1, components[1]))
        let b = max(0, min(1, components[2]))
        
        for space in ColorSpaceType.allCases where space != origin {
            switch space {
            case .hex:
                colorTexts[.hex] = rgbToHex(r, g, b)
            case .rgb:
                colorTexts[.rgb] = "\(Int(r*255)), \(Int(g*255)), \(Int(b*255))"
            case .hsl:
                colorTexts[.hsl] = rgbToHsl(r, g, b)
            case .hsv:
                colorTexts[.hsv] = rgbToHsv(r, g, b)
            case .cmyk:
                colorTexts[.cmyk] = rgbToCmyk(r, g, b)
            }
        }
    }
    
    // MARK: - 转换函数
    private func hexToRgb(_ hex: String) -> (CGFloat, CGFloat, CGFloat)? {
        var hexValue = hex
        if hexValue.count == 3 {
            hexValue = hexValue.map { "\($0)\($0)" }.joined()
        }
        guard hexValue.count == 6,
              let intVal = Int(hexValue, radix: 16) else { return nil }
        return (
            CGFloat((intVal >> 16) & 0xFF) / 255,
            CGFloat((intVal >> 8) & 0xFF) / 255,
            CGFloat(intVal & 0xFF) / 255
        )
    }
    
    private func rgbToHex(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> String {
        String(format: "#%02X%02X%02X", Int(r*255), Int(g*255), Int(b*255))
    }
    
    private func rgbToCmyk(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> String {
        let c = 1 - r, m = 1 - g, y = 1 - b
        let k = min(c, m, y)
        
        // 处理纯黑色的特殊情况（避免除以零）
        if k >= 1 {
            return "0, 0, 0, 100"
        }
        
        let cc = (c - k) / (1 - k)
        let mm = (m - k) / (1 - k)
        let yy = (y - k) / (1 - k)
        return "\(Int(cc*100)), \(Int(mm*100)), \(Int(yy*100)), \(Int(k*100))"
    }
    
    private func hslToRgb(_ input: String) -> (CGFloat, CGFloat, CGFloat)? {
        let parts = input.split(separator: ",")
        guard parts.count == 3,
              let h = Double(parts[0]),
              let s = Double(parts[1].replacingOccurrences(of: "%", with: "")),
              let l = Double(parts[2].replacingOccurrences(of: "%", with: "")) else { return nil }
        
        // 验证范围：H: 0-360, S: 0-100, L: 0-100
        guard (0...360).contains(h),
              (0...100).contains(s),
              (0...100).contains(l) else { return nil }
        
        let ss = s / 100, ll = l / 100
        let c = (1 - abs(2*ll - 1)) * ss
        let x = c * (1 - abs(fmod(h/60.0, 2) - 1))
        let m = ll - c/2
        let (r, g, b): (Double, Double, Double)
        switch h {
        case 0..<60: (r, g, b) = (c, x, 0)
        case 60..<120: (r, g, b) = (x, c, 0)
        case 120..<180: (r, g, b) = (0, c, x)
        case 180..<240: (r, g, b) = (0, x, c)
        case 240..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return (CGFloat(r+m), CGFloat(g+m), CGFloat(b+m))
    }
    
    private func rgbToHsl(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> String {
        let maxv = max(r, g, b), minv = min(r, g, b)
        let d = maxv - minv
        var h: CGFloat = 0
        if d != 0 {
            if maxv == r { h = (g - b) / d + (g < b ? 6 : 0) }
            else if maxv == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h *= 60
        }
        let l = (maxv + minv) / 2
        
        // 修复饱和度计算，避免除以零和负值
        let denominator = 1 - abs(2*l - 1)
        let s: CGFloat
        if d == 0 || denominator <= 0.0001 {
            s = 0
        } else {
            s = max(0, min(1, d / denominator))
        }
        
        return "\(Int(h)), \(Int(s*100))%, \(Int(l*100))%"
    }
    
    private func hsvToRgb(_ input: String) -> (CGFloat, CGFloat, CGFloat)? {
        let parts = input.split(separator: ",")
        guard parts.count == 3,
              let h = Double(parts[0]),
              let s = Double(parts[1].replacingOccurrences(of: "%", with: "")),
              let v = Double(parts[2].replacingOccurrences(of: "%", with: "")) else { return nil }
        
        // 验证范围：H: 0-360, S: 0-100, V: 0-100
        guard (0...360).contains(h),
              (0...100).contains(s),
              (0...100).contains(v) else { return nil }
        
        let ss = s / 100, vv = v / 100
        let c = vv * ss
        let x = c * (1 - abs(fmod(h/60.0, 2) - 1))
        let m = vv - c
        let (r, g, b): (Double, Double, Double)
        switch h {
        case 0..<60: (r, g, b) = (c, x, 0)
        case 60..<120: (r, g, b) = (x, c, 0)
        case 120..<180: (r, g, b) = (0, c, x)
        case 180..<240: (r, g, b) = (0, x, c)
        case 240..<300: (r, g, b) = (x, 0, c)
        default: (r, g, b) = (c, 0, x)
        }
        return (CGFloat(r+m), CGFloat(g+m), CGFloat(b+m))
    }
    
    private func rgbToHsv(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> String {
        let maxv = max(r, g, b), minv = min(r, g, b)
        let d = maxv - minv
        var h: CGFloat = 0
        if d != 0 {
            if maxv == r { h = (g - b) / d + (g < b ? 6 : 0) }
            else if maxv == g { h = (b - r) / d + 2 }
            else { h = (r - g) / d + 4 }
            h *= 60
        }
        let s = maxv == 0 ? 0 : d / maxv
        let v = maxv
        return "\(Int(h)), \(Int(s*100))%, \(Int(v*100))%"
    }
    
    private func cmykToRgb(_ input: String) -> (CGFloat, CGFloat, CGFloat)? {
        let parts = input.split(separator: ",").compactMap { Double($0) }
        // 验证：必须有 4 个值，且每个值都在 0-100 范围内
        guard parts.count == 4,
              parts.allSatisfy({ (0...100).contains($0) }) else { return nil }
        let c = parts[0]/100, m = parts[1]/100, y = parts[2]/100, k = parts[3]/100
        return (
            CGFloat((1 - c) * (1 - k)),
            CGFloat((1 - m) * (1 - k)),
            CGFloat((1 - y) * (1 - k))
        )
    }
}

#Preview {
    CalculateColorView()
}
