#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - 辅助函数：简易高品质伪随机与分形噪声

static float hash21(float2 p) {
    p = fract(p * float2(234.34, 435.345));
    p += dot(p, p + 34.23);
    return fract(p.x * p.y);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0 - 2.0 * f);
    
    float a = hash21(i);
    float b = hash21(i + float2(1.0, 0.0));
    float c = hash21(i + float2(0.0, 1.0));
    float d = hash21(i + float2(1.0, 1.0));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 简易域扭曲（Domain Warping）fBm 噪声
static float domainWarping(float2 p, float seed) {
    float2 q = float2(
        noise(p + float2(0.0, 0.0) + seed),
        noise(p + float2(5.2, 1.3) + seed * 1.3)
    );
    float2 r = float2(
        noise(p + 4.0 * q + float2(1.7, 9.2) + seed * 0.7),
        noise(p + 4.0 * q + float2(8.3, 2.8) + seed * 0.5)
    );
    return noise(p + 4.0 * r);
}

// MARK: - 1. 全息薄膜色散 (Iridescent Holo Foil)
// colorEffect: 根据倾角与位置叠加彩虹衍射
[[ stitchable ]] half4 iridescentHoloFoil(
    float2 position,
    half4 color,
    float2 size,
    float2 tilt,
    float intensity
) {
    if (color.a <= 0.001 || intensity <= 0.0) {
        return color;
    }
    
    float2 uv = position / max(size, float2(1.0, 1.0));
    // 结合倾角与位置计算光学相位
    float phase = dot(uv, float2(0.707, 0.707)) * 3.0 + (tilt.x + tilt.y) * 2.2;
    
    // 正弦彩虹光谱发生器
    half3 rainbow = half3(
        0.5 + 0.5 * cos(phase + 0.0),
        0.5 + 0.5 * cos(phase + 2.094),
        0.5 + 0.5 * cos(phase + 4.188)
    );
    
    // 以柔光叠加模式混合
    half3 blended = mix(color.rgb, color.rgb + rainbow * half(intensity * 0.45), half(intensity));
    return half4(blended, color.a);
}

// MARK: - 2. 域扭曲流体解体/灰飞烟灭 (Domain Warped Dissolve)
// layerEffect: 随 progress 产生涡旋撕裂并溶解
[[ stitchable ]] half4 domainWarpedDissolve(
    float2 position,
    SwiftUI::Layer layer,
    float2 size,
    float progress,
    float seed
) {
    if (progress <= 0.001) {
        return layer.sample(position);
    }
    if (progress >= 0.999) {
        return half4(0.0);
    }
    
    float2 uv = position / max(size, float2(1.0, 1.0));
    float n = domainWarping(uv * 6.0, seed);
    
    // 计算当前像素的溶解阈值
    float threshold = progress * 1.35;
    if (n < threshold) {
        // 在边缘产生流体发光烧蚀带
        float edge = threshold - n;
        if (edge < 0.08) {
            half3 emberColor = mix(half3(0.3, 0.8, 1.0), half3(1.0, 0.35, 0.6), half(edge / 0.08));
            return half4(emberColor, half((1.0 - edge / 0.08) * (1.0 - progress)));
        }
        return half4(0.0);
    }
    
    // 伴随轻微空间扭曲拉扯
    float2 distortedPos = position + float2(sin(n * 6.28), cos(n * 6.28)) * (progress * 15.0);
    return layer.sample(distortedPos);
}

// MARK: - 3. 焦散水波纹折射 (Caustic Ripple)
// layerEffect: 从 origin 扩散焦散透镜畸变
[[ stitchable ]] half4 causticRipple(
    float2 position,
    SwiftUI::Layer layer,
    float2 origin,
    float time,
    float amplitude
) {
    if (amplitude <= 0.001 || time <= 0.0) {
        return layer.sample(position);
    }
    
    float dist = distance(position, origin);
    float speed = 280.0; // 传播速度
    float waveRadius = time * speed;
    float waveWidth = 48.0;
    
    float diff = dist - waveRadius;
    if (abs(diff) < waveWidth) {
        float factor = cos(diff / waveWidth * 3.14159) * (1.0 - min(1.0, time * 1.5)) * amplitude;
        float2 dir = normalize(position - origin + float2(0.0001, 0.0001));
        float2 displacedPos = position + dir * factor * 14.0;
        return layer.sample(displacedPos);
    }
    
    return layer.sample(position);
}
