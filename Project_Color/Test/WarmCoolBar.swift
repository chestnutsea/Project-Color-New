//
//  WarmCoolBar.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/23.
//

//
//  WarmCool.swift
//  Project_Color
//
//  Created by Linya Huang on 2025/11/23.
//

import SwiftUI

struct TemperatureBarView: View {
    // 冷暖值：-1 到 1
    var temperature: CGFloat
    let barHeight: CGFloat = 12
    let markerSize: CGFloat = 12   // 黑色小点
    
    var body: some View {
        VStack(spacing: 8) {
            
            // 上方色条
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue,
                    Color.cyan,
                    Color.gray,
                    Color.orange,
                    Color.red
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: barHeight)
            .cornerRadius(6)
            
            // 下方 X 轴 + 黑点
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    
                    // X 轴
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 2)
                    
                    // 小黑点
                    Circle()
                        .fill(Color.black)
                        .frame(width: markerSize, height: markerSize)
                        .offset(x: xPosition(in: geo.size.width))
                }
            }
            .frame(height: markerSize) // 限制区域
            
            // 标签（可选）
            HStack {
                Text("冷")
                    .font(.caption)
                Spacer()
                Text("暖")
                    .font(.caption)
            }
        }
        .padding()
    }
    
    // 把 -1 ~ 1 映射到 0 ~ width
    private func xPosition(in width: CGFloat) -> CGFloat {
        let normalized = (temperature + 1) / 2   // 映射到 0~1
        return normalized * width - markerSize / 2
    }
}

struct TemperatureBarView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 40) {
            TemperatureBarView(temperature: -0.9)  // frío
            TemperatureBarView(temperature: 0.0)   // neutral
            TemperatureBarView(temperature: 0.8)   // warm
        }
        .padding()
        .previewLayout(.sizeThatFits)
    }
}
