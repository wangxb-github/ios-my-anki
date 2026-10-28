import SwiftUI
import Foundation

public extension View {
    /// 叠加全息薄膜色散（纯 SwiftUI 合成层，不触发 Metal offscreen 渲染，100% 兼容 WKWebView）
    @ViewBuilder
    func ankiIridescentHoloFoil(
        size: CGSize,
        tilt: SIMD2<Float>,
        intensity: Float = 0.4
    ) -> some View {
        let active = intensity > 0.001 && size.width > 1 && size.height > 1
        self.overlay {
            if active {
                let angle = Double(tilt.x + tilt.y) * 90.0
                LinearGradient(
                    colors: [
                        Color.cyan.opacity(Double(intensity) * 0.22),
                        Color.purple.opacity(Double(intensity) * 0.18),
                        Color.pink.opacity(Double(intensity) * 0.15),
                        Color.mint.opacity(Double(intensity) * 0.22)
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

    /// 焦散水波纹扩散特效（纯 SwiftUI 独立 overlay，不阻碍或栅格化底层视图）
    @ViewBuilder
    func ankiCausticRipple(
        origin: CGPoint,
        time: Float,
        amplitude: Float = 1.0
    ) -> some View {
        let active = amplitude > 0.001 && time > 0.001 && time < 0.999
        self.overlay {
            if active {
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(Double((1.0 - time) * amplitude * 0.65)),
                                Color.amgiAccent.opacity(Double((1.0 - time) * amplitude * 0.45))
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: CGFloat(max(1.5, (1.0 - time) * 8.0))
                    )
                    .frame(width: CGFloat(time * 480.0), height: CGFloat(time * 480.0))
                    .position(origin)
                    .allowsHitTesting(false)
            }
        }
    }
}
