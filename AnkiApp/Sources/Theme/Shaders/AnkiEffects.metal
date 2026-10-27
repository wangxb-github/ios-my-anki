#include <metal_stdlib>
#include <SwiftUI/SwiftUI_Metal.h>

using namespace metal;

// MARK: - 辅助函数：简易高品质伪随机与分形噪声

static float hash21(float2 p) {
    p = fract(p * float2(234.34f, 435.345f));
    p += dot(p, p + 34.23f);
    return fract(p.x * p.y);
}

static float noise(float2 p) {
    float2 i = floor(p);
    float2 f = fract(p);
    f = f * f * (3.0f - 2.0f * f);
    
    float a = hash21(i);
    float b = hash21(i + float2(1.0f, 0.0f));
    float c = hash21(i + float2(0.0f, 1.0f));
    float d = hash21(i + float2(1.0f, 1.0f));
    
    return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

// 简易域扭曲（Domain Warping）fBm 噪声
static float domainWarping(float2 p, float seed) {
    float2 q = float2(
        noise(p + float2(0.0f, 0.0f) + seed),
        noise(p + float2(5.2f, 1.3f) + seed * 1.3f)
    );
    float2 r = float2(
        noise(p + 4.0f * q + float2(1.7f, 9.2f) + seed * 0.7f),
        noise(p + 4.0f * q + float2(8.3f, 2.8f) + seed * 0.5f)
    );
    return noise(p + 4.0f * r);
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
    if (color.a <= 0.001h || intensity <= 0.0f) {
        return color;
    }
    
    float2 uv = position / max(size, float2(1.0f, 1.0f));
    // 结合倾角与位置计算光学相位
    float phase = dot(uv, float2(0.707f, 0.707f)) * 3.0f + (tilt.x + tilt.y) * 2.2f;
    
    // 正弦彩虹光谱发生器
    half3 rainbow = half3(
        half(0.5f + 0.5f * cos(phase + 0.0f)),
        half(0.5f + 0.5f * cos(phase + 2.094f)),
        half(0.5f + 0.5f * cos(phase + 4.188f))
    );
    
    // 以柔光叠加模式混合
    half3 blended = mix(color.rgb, color.rgb + rainbow * half(intensity * 0.45f), half(intensity));
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
    if (progress <= 0.001f) {
        return layer.sample(position);
    }
    if (progress >= 0.999f) {
        return half4(0.0h);
    }
    
    float2 uv = position / max(size, float2(1.0f, 1.0f));
    float n = domainWarping(uv * 6.0f, seed);
    
    // 计算当前像素的溶解阈值
    float threshold = progress * 1.35f;
    if (n < threshold) {
        // 在边缘产生流体发光烧蚀带
        float edge = threshold - n;
        if (edge < 0.08f) {
            half3 emberColor = mix(half3(0.3h, 0.8h, 1.0h), half3(1.0h, 0.35h, 0.6h), half(edge / 0.08f));
            return half4(emberColor, half((1.0f - edge / 0.08f) * (1.0f - progress)));
        }
        return half4(0.0h);
    }
    
    // 伴随轻微空间扭曲拉扯
    float2 distortedPos = position + float2(sin(n * 6.28f), cos(n * 6.28f)) * (progress * 15.0f);
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
    if (amplitude <= 0.001f || time <= 0.0f) {
        return layer.sample(position);
    }
    
    float dist = distance(position, origin);
    float speed = 280.0f; // 传播速度
    float waveRadius = time * speed;
    float waveWidth = 48.0f;
    
    float diff = dist - waveRadius;
    if (abs(diff) < waveWidth) {
        float factor = cos(diff / waveWidth * 3.14159f) * (1.0f - min(1.0f, time * 1.5f)) * amplitude;
        float2 dir = normalize(position - origin + float2(0.0001f, 0.0001f));
        float2 displacedPos = position + dir * factor * 14.0f;
        return layer.sample(displacedPos);
    }
    
    return layer.sample(position);
}
