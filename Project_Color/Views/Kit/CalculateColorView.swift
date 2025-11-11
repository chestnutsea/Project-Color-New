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
    private let rowHeight: CGFloat = 25
    private let labelWidth: CGFloat = 72
    private let labelFontSize: CGFloat = 16
    private let valueFontSize: CGFloat = 16
    
    private let placeholders: [ColorField: String] = [
        .hex: "#FFFFFF",
        .rgb: "(255, 255, 255)",
        .hsl: "(0, 0%, 100%)",
        .hsv: "(0, 0%, 100%)",
        .cmyk: "(0, 0, 0, 0)"
    ]
    private let isccPlaceholder = "白色"
    
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
                
                VStack(alignment: .leading, spacing: 0) {
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
        .onChange(of: focusedField, perform: handleFocusChange)
    }
    
    // MARK: - Rows
    private func colorRow(for field: ColorField, label: String, text: Binding<String>) -> some View {
        HStack(spacing: 16) {
            Text(label)
                .font(.system(size: labelFontSize, weight: .medium))
                .foregroundColor(textColor)
                .frame(width: labelWidth, alignment: .leading)
            
            Spacer()
            
            ZStack(alignment: .trailing) {
                if shouldShowPlaceholder(for: field, text: text.wrappedValue) {
                    Text(placeholders[field] ?? "")
                        .font(.system(size: valueFontSize))
                        .foregroundColor(textColor.opacity(0.35))
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                
                TextField("", text: text)
                    .focused($focusedField, equals: field)
                    .font(.system(size: valueFontSize))
                    .foregroundColor(textColor)
                    .multilineTextAlignment(.trailing)
                    .textFieldStyle(.plain)
                    .disabled(activeField != nil && activeField != field)
                    .opacity(activeField == field || !text.wrappedValue.isEmpty ? 1 : 0.01)
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
        .onTapGesture {
            focusField(field)
        }
    }
    
    private func isccRow() -> some View {
        HStack(spacing: 16) {
            Text("ISCC-NBS")
                .font(.system(size: labelFontSize, weight: .medium))
                .foregroundColor(textColor)
                .frame(width: labelWidth, alignment: .leading)
            
            Spacer()
            
            Text(isccText.isEmpty ? isccPlaceholder : isccText)
                .font(.system(size: valueFontSize))
                .foregroundColor(isccText.isEmpty ? textColor.opacity(0.35) : textColor)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(height: rowHeight)
    }
    
    // MARK: - Focus Handling
    private func focusField(_ field: ColorField) {
        if activeField != field {
            prepareForEditing(field)
        }
        focusedField = field
    }
    
    private func handleFocusChange(_ newValue: ColorField?) {
        guard let newField = newValue else {
            activeField = nil
            return
        }
        if activeField != newField {
            prepareForEditing(newField)
        }
    }
    
    private func prepareForEditing(_ field: ColorField) {
        withAnimation(.easeInOut(duration: 0.2)) {
            hexText = ""
            rgbText = ""
            hslText = ""
            hsvText = ""
            cmykText = ""
            isccText = ""
            backgroundColor = .white
            textColor = .black
            activeField = field
        }
    }
    
    private func shouldShowPlaceholder(for field: ColorField, text: String) -> Bool {
        if !text.isEmpty { return false }
        if let active = activeField {
            return active == field
        }
        return true
    }
    
    // MARK: - Text Handling
    private func handleTextChange(for field: ColorField, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        if trimmed.isEmpty {
            resetWhileEditing()
            return
        }
        
        switch field {
        case .hex:
            let upper = trimmed.uppercased()
            guard isValidHex(upper), let rgb = hexToRGB(upper) else { return }
            applyColor(from: .hex, rgb: rgb)
        case .rgb:
            guard isValidRGB(trimmed) else { return }
            let numbers = extractRGBNumbers(trimmed)
            guard numbers.count == 3 else { return }
            let rgb = SIMD3<Float>(
                Float(numbers[0]) / 255.0,
                Float(numbers[1]) / 255.0,
                Float(numbers[2]) / 255.0
            )
            applyColor(from: .rgb, rgb: rgb)
        case .hsl:
            guard isValidHSL(trimmed) else { return }
            let numbers = extractHSLNumbers(trimmed)
            guard numbers.count == 3 else { return }
            let rgb = converter.hslToRgb(
                Float(numbers[0]),
                Float(numbers[1]) / 100.0,
                Float(numbers[2]) / 100.0
            )
            applyColor(from: .hsl, rgb: rgb)
        case .hsv:
            guard isValidHSV(trimmed) else { return }
            let numbers = extractHSVNumbers(trimmed)
            guard numbers.count == 3 else { return }
            let rgb = converter.hsvToRgb(
                Float(numbers[0]),
                Float(numbers[1]) / 100.0,
                Float(numbers[2]) / 100.0
            )
            applyColor(from: .hsv, rgb: rgb)
        case .cmyk:
            guard isValidCMYK(trimmed) else { return }
            let numbers = extractCMYKNumbers(trimmed)
            guard numbers.count == 4 else { return }
            let rgb = converter.cmykToRgb(
                Float(numbers[0]) / 100.0,
                Float(numbers[1]) / 100.0,
                Float(numbers[2]) / 100.0,
                Float(numbers[3]) / 100.0
            )
            applyColor(from: .cmyk, rgb: rgb)
        }
    }
    
    private func resetWhileEditing() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isccText = ""
            backgroundColor = .white
            textColor = .black
        }
    }
    
    // MARK: - Apply
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
        
        withAnimation(.easeInOut(duration: 0.3)) {
            hexText = hexValue
            rgbText = rgbValue
            hslText = hslValue
            hsvText = hsvValue
            cmykText = cmykValue
            isccText = iscc
            
            backgroundColor = Color(red: Double(clipped.x), green: Double(clipped.y), blue: Double(clipped.z))
            textColor = lab.x < 50 ? .white : .black
            activeField = nil
            focusedField = nil
        }
    }
    
    // MARK: - Validators
    private func isValidHex(_ value: String) -> Bool {
        let pattern = "^#[0-9A-F]{6}$"
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
        let pattern = "^\\(\\s*\\d{1,3}\\s*,\\s*\\d{1,3}%\\s*,\\s*\\d{1,3}%\\s*\\)$"
        guard value.range(of: pattern, options: .regularExpression) != nil else { return false }
        let numbers = extractHSVNumbers(value)
        return numbers.count == 3 && numbers[0] >= 0 && numbers[0] <= 360 && numbers[1] >= 0 && numbers[1] <= 100 && numbers[2] >= 0 && numbers[2] <= 100
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
