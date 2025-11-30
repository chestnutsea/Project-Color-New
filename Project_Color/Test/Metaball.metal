#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>
using namespace metal;

// ✅ 真正基于“距离场”的 Metaball
[[ stitchable ]]
half4 metaball(
    float2 position,
    SwiftUI::Layer layer,
    float threshold,
    float influenceRadius
) {
    // 取当前像素颜色（用于最后上色）
    half4 baseColor = layer.sample(position);

    // ✅ 构建距离势能场
    float field = 0.0;
    constexpr float step = 6.0;

    for (float x = -influenceRadius; x <= influenceRadius; x += step) {
        for (float y = -influenceRadius; y <= influenceRadius; y += step) {
            float2 offset = float2(x, y);
            half a = layer.sample(position + offset).a;

            float d = length(offset);
            if (d > 0.0) {
                field += (float(a) * influenceRadius * influenceRadius) / (d * d);
            }
        }
    }

    // ✅ 等值面切割 → 真正鼓包融合
    float alpha = smoothstep(threshold, threshold + 0.15, field);

    return half4(baseColor.rgb, half(alpha));
}
