//
//  CalculateColorView.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/11.
//

import SwiftUI
import simd

struct CalculateColorView: View {
    private enum ColorField: Hashable {
        case hex, rgb, hsl, hsv, cmyk
    }
    
    // MARK: - Layout Constants
    private let topPadding: CGFloat = 30
    private let rowHeight: CGFloat = 46
    private let labelWidth: CGFloat = 90
    private let labelFontSize: CGFloat = 16
    private let valueFontSize: CGFloat = 16
    
    // MARK: - State
    @State private var hexText: String = ""
    @State private var rgbText: String = ""
    @State private var hslText: String = ""
    @State private var hsvText: String = ""
    @State private var cmykText: String = ""
    @State private var isccText: String = ""
    
    @State private var activeField: ColorField? = nil
    @FocusState private var focusedField: ColorField?
    
    @State private var backgroundColor: Color = .white
    @State private var textColor: Color = .black
    
    private let converter = ColorSpaceConverter()
    
    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 0) {
                Spacer().frame(height: topPadding)
                
                VStack(alignment: .leading, spacing: 10) {
                    colorRow(for: .hex, label: "HEX", text: $hexText)
                    colorRow(for: .rgb, label: "RGB", text: $rgbText)
                    colorRow(for: .hsl, label: "HSL", text: $hslText)
                    colorRow(for: .hsv, label: "HSV", text: $hsvText)
                    colorRow(for: .cmyk, label: "CMYK", text: $cmykText)
                    isccRow()
                }
                .padding(.horizontal, 20)
                
                Spacer()
            }
        }
        .navigationTitle("算色")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false) // 仅保留系统返回按钮
        .onChange(of: focusedField, perform: handleFocusChange)
    }
    
    // MARK: - Rows
    private func colorRow(for field: ColorField, label: String, text: Binding<String>) -> some View {
        HStack(spacing: 12) {
            Text(label)
                .font(.system(size: labelFontSize, weight: .medium))
                .foregroundColor(textColor)
                .frame(width: labelWidth, alignment: .leading)
            
            Spacer(minLength: 8)
            
            ZStack(alignment: .trailing) {
                // 底纹：非强烈干扰的淡色条纹/渐变
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(field == activeField ? 0.28 : 0.16),
                                Color.black.opacity(0.06)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                
                // 真正的输入/显示控件
                TextField("", text: text)
                    .focused($focusedField, equals: field)
                    .font(.system(size: valueFontSize))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .frame(height: rowHeight)
                    .disabled(activeField != nil && activeField != field)
                    .onTapGesture {
                        focusField(field)
                    }
                    .onChange(of: text.wrappedValue) { newValue in
                        guard activeField == field else { return }
                        handleTextChange(for: field, text: newValue)
                    }
                    #if os(iOS)
                    .keyboardType(field == .hex ? .asciiCapable : .numbersAndPunctuation)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled(true)
                    #endif
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: rowHeight)
        .contentShape(Rectangle())
        .animation(.easeInOut(duration: 0.25), value: text.wrappedValue)
        .animation(.easeInOut(duration: 0.25), value: activeField)
    }
    
    private func isccRow() -> some View {
        HStack(spacing: 12) {
            Text("ISCC-NBS")
                .font(.system(size: labelFontSize, weight: .medium))
                .foregroundColor(textColor)
                .frame(width: labelWidth, alignment: .leading)
            
            Spacer(minLength: 8)
            
            ZStack(alignment: .trailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.16),
                                Color.black.opacity(0.06)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                
                Text(isccText)
                    .font(.system(size: valueFontSize))
                    .foregroundColor(isccText.isEmpty ? textColor.opacity(0.35) : textColor)
                    .padding(.horizontal, 12)
                    .frame(height: rowHeight, alignment: .center)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
        }
        .frame(height: rowHeight)
        .animation(.easeInOut(duration: 0.25), value: isccText)
    }
    
    // MARK: - Focus Handling
    private func focusField(_ field: ColorField) {
        if activeField != field {
            // 切换到新行：清空所有内容 & 恢复默认背景
            clearAllTexts()
        }
        activeField = field
        focusedField = field
    }
    
    private func handleFocusChange(_ newValue: ColorField?) {
        // 当完全失焦时，退出编辑态，但不清空已有匹配结果
        if newValue == nil {
            activeField = nil
        }
    }
    
    // MARK: - Text Handling
    private func handleTextChange(for field: ColorField, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            clearComputedValues(keeping: field)
            return
        }
        
        // 仅当匹配成功时，联动更新其它行和背景
        var rgb: SIMD3<Float>? = nil
        
        switch field {
        case .hex:
            let upper = trimmed.uppercased()
            if isValidHex(upper), let val = hexToRGB(upper) { rgb = val }
        case .rgb:
            if isValidRGB(trimmed) {
                let n = extractRGBNumbers(trimmed)
                rgb = SIMD3<Float>(Float(n[0])/255, Float(n[1])/255, Float(n[2])/255)
            }
        case .hsl:
            if isValidHSL(trimmed) {
                let n = extractHSLNumbers(trimmed)
                rgb = converter.hslToRgb(Float(n[0]), Float(n[1])/100, Float(n[2])/100)
            }
        case .hsv:
            if isValidHSV(trimmed) {
                let n = extractHSVNumbers(trimmed)
                rgb = converter.hsvToRgb(Float(n[0]), Float(n[1])/100, Float(n[2])/100)
            }
        case .cmyk:
            if isValidCMYK(trimmed) {
                let n = extractCMYKNumbers(trimmed)
                rgb = converter.cmykToRgb(Float(n[0])/100, Float(n[1])/100, Float(n[2])/100, Float(n[3])/100)
            }
        }
        
        if let rgb = rgb {
            applyColor(from: field, rgb: rgb)
        } else {
            // 未匹配：保持仅当前行在编辑，其他行清空与底纹
            clearComputedValues(keeping: field)
        }
    }
    
    // MARK: - Clear Helpers
    private func clearAllTexts() {
        withAnimation(.easeInOut(duration: 0.2)) {
            hexText = ""
            rgbText = ""
            hslText = ""
            hsvText = ""
            cmykText = ""
            isccText = ""
            backgroundColor = .white
            textColor = .black
        }
    }
    
    private func clearComputedValues(keeping field: ColorField) {
        withAnimation(.easeInOut(duration: 0.2)) {
            switch field {
            case .hex:
                rgbText = ""; hslText = ""; hsvText = ""; cmykText = ""
            case .rgb:
                hexText = ""; hslText = ""; hsvText = ""; cmykText = ""
            case .hsl:
                hexText = ""; rgbText = ""; hsvText = ""; cmykText = ""
            case .hsv:
                hexText = ""; rgbText = ""; hslText = ""; cmykText = ""
            case .cmyk:
                hexText = ""; rgbText = ""; hslText = ""; hsvText = ""
            }
            isccText = ""
            backgroundColor = .white
            textColor = .black
        }
    }
    
    // MARK: - Apply (only when matched)
    private func applyColor(from field: ColorField, rgb: SIMD3<Float>) {
        let clipped = simd_clamp(rgb, SIMD3<Float>(repeating: 0), SIMD3<Float>(repeating: 1))
        let hexValue = rgbToHex(clipped)
        let rgbValue = formatRGB(clipped)
        let hsl = converter.rgbToHSL(clipped)
        let hslValue = formatHSL(hsl)
        let hsv = converter.rgbToHSV(clipped)
        let hsvValue = formatHSV(hsv)
        let cmyk = converter.rgbToCMYK(clipped)
        let cmykValue = formatCMYK(cmyk)
        let iscc = getISCCNBSName(h: hsl.h, s: hsl.s, l: hsl.l)
        let lab = converter.rgbToLab(clipped)
        
        withAnimation(.easeInOut(duration: 0.28)) {
            // 当前行保留用户输入，不覆盖
            switch field {
            case .hex:
                rgbText = rgbValue; hslText = hslValue; hsvText = hsvValue; cmykText = cmykValue
            case .rgb:
                hexText = hexValue; hslText = hslValue; hsvText = hsvValue; cmykText = cmykValue
            case .hsl:
                hexText = hexValue; rgbText = rgbValue; hsvText = hsvValue; cmykText = cmykValue
            case .hsv:
                hexText = hexValue; rgbText = rgbValue; hslText = hslValue; cmykText = cmykValue
            case .cmyk:
                hexText = hexValue; rgbText = rgbValue; hslText = hslValue; hsvText = hsvValue
            }
            
            isccText = iscc
            backgroundColor = Color(red: Double(clipped.x), green: Double(clipped.y), blue: Double(clipped.z))
            textColor = lab.x < 50 ? .white : .black
        }
    }
    
    // MARK: - Validators
    private func isValidHex(_ value: String) -> Bool {
        let pattern = "^#[0-9A-Fa-f]{6}$"
        return value.range(of: pattern, options: .regularExpression) != nil
    }
    
    private func isValidRGB(_ value: String) -> Bool {
        let pattern = "^\\(\\s*\\d{1,3}\\s*,\\s*\\d{1,3}\\s*,\\s*\\d{1,3}\\s*\\)$"
        guard value.range(of: pattern, options: .regularExpression) != nil else { return false }
        let numbers = extractRGBNumbers(value)
        return numbers.count == 3 && numbers.allSatisfy { $0 >= 0 && $0 <= 255 }
    }
    
    private func isValidHSL(_ value: String) -> Bool {
        let pattern = "^\\(\\s*\\d{1,3}\\s*,\\s*\\d{1,3}%\\s*,\\s*\\d{1,3}%\\s*\\)$"
        guard value.range(of: pattern, options: .regularExpression) != nil else { return false }
        let numbers = extractHSLNumbers(value)
        return numbers.count == 3 && numbers[0] >= 0 && numbers[0] <= 360 && numbers[1] >= 0 && numbers[1] <= 100 && numbers[2] >= 0 && numbers[2] <= 100
    }
    
    private func isValidHSV(_ value: String) -> Bool {
        // 与 HSL 同样的结构校验
        return isValidHSL(value)
    }
    
    private func isValidCMYK(_ value: String) -> Bool {
        let pattern = "^\\(\\s*\\d{1,3}\\s*,\\s*\\d{1,3}\\s*,\\s*\\d{1,3}\\s*,\\s*\\d{1,3}\\s*\\)$"
        guard value.range(of: pattern, options: .regularExpression) != nil else { return false }
        let numbers = extractCMYKNumbers(value)
        return numbers.count == 4 && numbers.allSatisfy { $0 >= 0 && $0 <= 100 }
    }
    
    // MARK: - Parsing Helpers
    private func extractRGBNumbers(_ value: String) -> [Int] {
        value
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    private func extractHSLNumbers(_ value: String) -> [Int] {
        value
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
            .replacingOccurrences(of: "%", with: "")
            .components(separatedBy: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespaces)) }
    }
    
    private func extractHSVNumbers(_ value: String) -> [Int] {
        extractHSLNumbers(value)
    }
    
    private func extractCMYKNumbers(_ value: String) -> [Int] {
        extractRGBNumbers(value)
    }
    
    // MARK: - Formatting Helpers
    private func hexToRGB(_ hex: String) -> SIMD3<Float>? {
        let cleaned = hex.replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        let r = Float((value >> 16) & 0xFF) / 255.0
        let g = Float((value >> 8) & 0xFF) / 255.0
        let b = Float(value & 0xFF) / 255.0
        return SIMD3<Float>(r, g, b)
    }
    
    private func rgbToHex(_ rgb: SIMD3<Float>) -> String {
        let r = Int((rgb.x * 255).rounded())
        let g = Int((rgb.y * 255).rounded())
        let b = Int((rgb.z * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
    
    private func formatRGB(_ rgb: SIMD3<Float>) -> String {
        let r = Int((rgb.x * 255).rounded())
        let g = Int((rgb.y * 255).rounded())
        let b = Int((rgb.z * 255).rounded())
        return "(\(r), \(g), \(b))"
    }
    
    private func formatHSL(_ hsl: (h: Float, s: Float, l: Float)) -> String {
        let h = Int(hsl.h.rounded())
        let s = Int((hsl.s * 100).rounded())
        let l = Int((hsl.l * 100).rounded())
        return "(\(h), \(s)%, \(l)%)"
    }
    
    private func formatHSV(_ hsv: (h: Float, s: Float, v: Float)) -> String {
        let h = Int(hsv.h.rounded())
        let s = Int((hsv.s * 100).rounded())
        let v = Int((hsv.v * 100).rounded())
        return "(\(h), \(s)%, \(v)%)"
    }
    
    private func formatCMYK(_ cmyk: SIMD4<Float>) -> String {
        let c = Int((cmyk.x * 100).rounded())
        let m = Int((cmyk.y * 100).rounded())
        let y = Int((cmyk.z * 100).rounded())
        let k = Int((cmyk.w * 100).rounded())
        return "(\(c), \(m), \(y), \(k))"
    }
    
    private func getISCCNBSName(h: Float, s: Float, l: Float) -> String {
        let hue = ((h.truncatingRemainder(dividingBy: 360)) + 360).truncatingRemainder(dividingBy: 360)
        if s <= 0.1 {
            if l >= 0.9 { return "白色" }
            if l <= 0.1 { return "黑色" }
            if l >= 0.65 { return "浅灰色" }
            if l <= 0.35 { return "深灰色" }
            return "灰色"
        }
        
        var base = "红"
        switch hue {
        case 0..<20, 340..<360: base = "红"
        case 20..<40: base = "橙"
        case 40..<70: base = "黄"
        case 70..<160: base = "绿"
        case 160..<200: base = "青"
        case 200..<260: base = "蓝"
        case 260..<320: base = "紫"
        default: base = "红"
        }
        
        var prefix = ""
        if l >= 0.7 {
            prefix = "浅"
        } else if l <= 0.3 {
            prefix = "深"
        }
        
        if s <= 0.3 {
            prefix += "灰"
        } else if s >= 0.75 && prefix.isEmpty {
            prefix = "鲜"
        }
        
        return prefix + base + "色"
    }
}

#Preview {
    NavigationStack {
        CalculateColorView()
    }
}
