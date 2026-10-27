import SwiftUI
import Foundation

public enum AnkiMetalAvailability {
    /// 检测当前 Bundle 是否包含已编译的 default.metallib（兼容 Swift Playgrounds 纯源码预览）
    public static let hasCompiledMetalLibrary: Bool = {
        Bundle.main.url(forResource: "default", withExtension: "metallib") != nil
    }()
}

public extension View {
    /// 叠加全息薄膜色散（随着设备倾角流转彩虹光泽）
    @ViewBuilder
    func ankiIridescentHoloFoil(
        size: CGSize,
        tilt: SIMD2<Float>,
        intensity: Float = 0.4
    ) -> some View {
        let active = intensity > 0.001 && size.width > 1 && size.height > 1
        if AnkiMetalAvailability.hasCompiledMetalLibrary {
            self.colorEffect(
                ShaderLibrary.bundle(.main).iridescentHoloFoil(
                    .float2(Float(size.width), Float(size.height)),
                    .float2(tilt.x, tilt.y),
                    .float(intensity)
                ),
                isEnabled: active
            )
        } else {
            self.overlay {
                if active {
                    let angle = Double(tilt.x + tilt.y) * 90.0
                    LinearGradient(
                        colors: [
                            Color.cyan.opacity(Double(intensity) * 0.25),
                            Color.purple.opacity(Double(intensity) * 0.22),
                            Color.pink.opacity(Double(intensity) * 0.18),
                            Color.mint.opacity(Double(intensity) * 0.25)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .hueRotation(.degrees(angle))
                    .blendMode(.plusLighter)
                    .allowsHitTesting(false)
                }
            }
        }
    }

    /// 域扭曲流体解体/斩杀撕裂特效（仅在 progress > 0.001 时激活离屏着色器，避免影响 WKWebView 滚动与交互）
    @ViewBuilder
    func ankiDomainWarpedDissolve(
        size: CGSize,
        progress: Float,
        seed: Float = 1.0
    ) -> some View {
        let active = progress > 0.001 && size.width > 1 && size.height > 1
        if AnkiMetalAvailability.hasCompiledMetalLibrary {
            self.layerEffect(
                ShaderLibrary.bundle(.main).domainWarpedDissolve(
                    .float2(Float(size.width), Float(size.height)),
                    .float(progress),
                    .float(seed)
                ),
                maxSampleOffset: CGSize(width: 30, height: 30),
                isEnabled: active
            )
        } else {
            self
                .scaleEffect(active ? CGFloat(max(0.72, 1.0 - progress * 0.28)) : 1.0)
                .blur(radius: active ? CGFloat(progress * 16.0) : 0.0)
                .opacity(active ? Double(max(0.0, 1.0 - progress)) : 1.0)
        }
    }

    /// 焦散水波纹折射扩散特效（仅在波纹传播期间激活）
    @ViewBuilder
    func ankiCausticRipple(
        origin: CGPoint,
        time: Float,
        amplitude: Float = 1.0
    ) -> some View {
        let active = amplitude > 0.001 && time > 0.001 && time < 0.999
        if AnkiMetalAvailability.hasCompiledMetalLibrary {
            self.layerEffect(
                ShaderLibrary.bundle(.main).causticRipple(
                    .float2(Float(origin.x), Float(origin.y)),
                    .float(time),
                    .float(amplitude)
                ),
                maxSampleOffset: CGSize(width: 25, height: 25),
                isEnabled: active
            )
        } else {
            self.overlay {
                if active {
                    Circle()
                        .stroke(
                            Color.cyan.opacity(Double((1.0 - time) * amplitude * 0.55)),
                            lineWidth: CGFloat(max(1.0, (1.0 - time) * 6.0))
                        )
                        .frame(width: CGFloat(time * 420.0), height: CGFloat(time * 420.0))
                        .position(origin)
                        .blur(radius: 2)
                        .allowsHitTesting(false)
                }
            }
        }
    }
}
