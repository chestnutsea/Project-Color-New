#if canImport(UIKit)
import SwiftUI
import simd

struct LookUpColorView: View {
    @FocusState private var isTextFieldFocused: Bool
    
    // MARK: - 布局常量
    private let nameFontSize: CGFloat = 24
    private let hexFontSize: CGFloat = 18
    private let rgbFontSize: CGFloat = 16
    private let dividerPadding: CGFloat = 10
    private let dividerLineWidth: CGFloat = 0.5
    
    // MARK: - State
    @State private var hexInput: String = ""
    @State private var topBackgroundColor: Color = Color(.systemBackground)
    @State private var bottomBackgroundColor: Color = Color(.systemBackground)
    @State private var topTextColor: Color = .primary
    @State private var bottomTextColor: Color = .primary
    @State private var dividerColor: Color = .primary
    @State private var colorName: String = ""
    @State private var colorHex: String = ""
    @State private var topRgbText: String = ""
    @State private var bottomRgbText: String = ""
    @State private var isValidHex: Bool = false
    
    // MARK: - Services
    private let colorResolver = ColorNameResolver.shared
    private let converter = ColorSpaceConverter()
    
    var body: some View {
        ZStack {
            // 背景色填充整个屏幕（包括安全区域）
            VStack(spacing: 0) {
                topBackgroundColor
                bottomBackgroundColor
            }
            .ignoresSafeArea()
            
            // 主内容
            GeometryReader { geometry in
                VStack(spacing: 0) {
                    upperSection(height: geometry.size.height / 2)
                    divider
                    lowerSection(height: geometry.size.height / 2)
                }
            }
        }
        // 隐藏导航栏标题，只保留返回按钮
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            // 使用空的 principal 来隐藏标题
            ToolbarItem(placement: .principal) {
                EmptyView()
            }
            // 键盘收起按钮
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(action: {
                    isTextFieldFocused = false
                }) {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16))
                }
            }
        }
    }
    
    // MARK: - Sections
    private func upperSection(height: CGFloat) -> some View {
        ZStack {
            topBackgroundColor
            
            VStack {
                Spacer()
                
                TextField(
                    "",
                    text: $hexInput,
                    prompt: Text("输入 HEX 值，如  FFFFFF").foregroundColor(topTextColor.opacity(0.6))
                )
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .foregroundColor(topTextColor)
                .multilineTextAlignment(.center)
                .focused($isTextFieldFocused)
                #if os(iOS)
                .keyboardType(.asciiCapable)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled(true)
                #endif
                .padding(.horizontal, 40)
                .onChange(of: hexInput) { newValue in
                    validateAndUpdateColor(newValue)
                }
                
                Spacer()
            }
        }
        .frame(height: height)
        .overlay(alignment: .bottom) {
            if isValidHex && !topRgbText.isEmpty {
                rgbTextView(text: topRgbText, textColor: topTextColor)
                    .padding(.bottom, dividerPadding)
            }
        }
    }
    
    private var divider: some View {
        Rectangle()
            .fill(dividerColor)
            .frame(height: dividerLineWidth)
    }
    
    private func lowerSection(height: CGFloat) -> some View {
        ZStack {
            bottomBackgroundColor
            
            VStack {
                if isValidHex && !bottomRgbText.isEmpty {
                    rgbTextView(text: bottomRgbText, textColor: bottomTextColor)
                        .padding(.top, dividerPadding)
                }
                
                Spacer()
                
                if isValidHex && !colorName.isEmpty {
                    VStack(spacing: 12) {
                        Text(colorName)
                            .font(.system(size: nameFontSize, weight: .semibold))
                            .foregroundColor(bottomTextColor)
                        
                        Text(colorHex)
                            .font(.system(size: hexFontSize))
                            .foregroundColor(bottomTextColor)
                    }
                }
                
                Spacer()
            }
        }
        .frame(height: height)
    }
    
    // MARK: - 颜色验证和更新
    private func validateAndUpdateColor(_ input: String) {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            resetToDefault()
            return
        }
        
        // 标准化 HEX 值：移除 # 前缀（如果有），然后检查是否为 6 位十六进制
        var hexValue = trimmed
        if hexValue.hasPrefix("#") {
            hexValue = String(hexValue.dropFirst())
        }
        
        // 验证是否为 6 位十六进制字符
        let hexPattern = "^[0-9A-Fa-f]{6}$"
        guard hexValue.range(of: hexPattern, options: .regularExpression) != nil else {
            resetToDefault()
            return
        }
        
        // 统一添加 # 前缀用于查询
        let normalizedHex = "#" + hexValue.uppercased()
        
        guard let result = colorResolver.findNearestColor(byHex: normalizedHex) else {
            resetToDefault()
            return
        }
        
        guard let inputRgb = hexToRGB(normalizedHex), let nearestRgb = hexToRGB(result.hex) else {
            resetToDefault()
            return
        }
        
        let inputLab = converter.rgbToLab(inputRgb)
        let nearestLab = converter.rgbToLab(nearestRgb)
        
        let inputR = Int((inputRgb.x * 255).rounded())
        let inputG = Int((inputRgb.y * 255).rounded())
        let inputB = Int((inputRgb.z * 255).rounded())
        let nearestR = Int((nearestRgb.x * 255).rounded())
        let nearestG = Int((nearestRgb.y * 255).rounded())
        let nearestB = Int((nearestRgb.z * 255).rounded())
        
        withAnimation(.easeInOut(duration: 0.25)) {
            isValidHex = true
            colorName = result.name
            colorHex = result.hex.uppercased()  // 确保 HEX 值大写显示
            topRgbText = formatRgbText(r: inputR, g: inputG, b: inputB)
            bottomRgbText = formatRgbText(r: nearestR, g: nearestG, b: nearestB)
            
            topBackgroundColor = Color(red: Double(inputRgb.x), green: Double(inputRgb.y), blue: Double(inputRgb.z))
            bottomBackgroundColor = Color(red: Double(nearestRgb.x), green: Double(nearestRgb.y), blue: Double(nearestRgb.z))
            
            topTextColor = inputLab.x < 50 ? .white : .black
            bottomTextColor = nearestLab.x < 50 ? .white : .black
            
            let averageLightness = (inputLab.x + nearestLab.x) / 2.0
            dividerColor = averageLightness < 50 ? .white : .black
        }
    }
    
    private func resetToDefault() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isValidHex = false
            colorName = ""
            colorHex = ""
            topRgbText = ""
            bottomRgbText = ""
            topBackgroundColor = Color(.systemBackground)
            bottomBackgroundColor = Color(.systemBackground)
            topTextColor = .primary
            bottomTextColor = .primary
            dividerColor = .primary
        }
    }
    
    // MARK: - Helpers
    private func hexToRGB(_ hex: String) -> SIMD3<Float>? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: "#", with: "")
        guard cleaned.count == 6, let value = Int(cleaned, radix: 16) else { return nil }
        let r = Float((value >> 16) & 0xFF) / 255.0
        let g = Float((value >> 8) & 0xFF) / 255.0
        let b = Float(value & 0xFF) / 255.0
        return SIMD3<Float>(r, g, b)
    }
    
    private func formatRgbText(r: Int, g: Int, b: Int) -> String {
        "R\(r)    G\(g)    B\(b)"
    }
    
    private func rgbTextView(text: String, textColor: Color) -> some View {
        let components = text.components(separatedBy: "    ")
        return HStack(spacing: 0) {
            ForEach(Array(components.enumerated()), id: \.offset) { index, component in
                if index > 0 {
                    Text("    ")
                        .font(.system(size: rgbFontSize))
                        .foregroundColor(textColor)
                }
                formattedRGBComponent(component, color: textColor)
            }
        }
    }
    
    private func formattedRGBComponent(_ component: String, color: Color) -> some View {
        guard let prefix = component.first else {
            return Text(component).foregroundColor(color)
        }
        let value = String(component.dropFirst())
        return (
            Text(String(prefix)).fontWeight(.bold) + Text(value).fontWeight(.regular)
        )
        .font(.system(size: rgbFontSize))
        .foregroundColor(color)
    }
}

#else

import SwiftUI

struct LookUpColorView: View {
    var body: some View {
        Text("LookUpColorView 仅在 iOS 上可用")
            .font(.headline)
            .foregroundColor(.secondary)
            .padding()
    }
}

#endif

#Preview {
    LookUpColorView()
}
