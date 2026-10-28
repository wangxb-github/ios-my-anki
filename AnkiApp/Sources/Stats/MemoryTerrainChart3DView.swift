import SwiftUI
import Charts
import Spatial

/// 基于 iOS 26 原生 Chart3D 的 FSRS 三维记忆留存曲面视图（支持双指捏合缩放、按钮无级缩放与多视角切换）
public struct MemoryTerrainChart3DView: View {
    public let dayCountMap: [Int: Int]

    @State private var cameraPose: Chart3DPose = .default
    @State private var zoomScale: CGFloat = 1.35
    @State private var gestureZoom: CGFloat = 1.0
    @State private var isExpanded: Bool = false

    private static let surfaceGradient = Gradient(colors: [
        Color.amgiRatingAgain,
        Color.amgiRatingHard,
        Color.amgiRatingGood,
        Color.amgiRatingEasy,
        Color.cyan
    ])

    private var effectiveZoom: CGFloat {
        min(2.6, max(0.95, zoomScale * gestureZoom))
    }

    public init(dayCountMap: [Int: Int] = [:]) {
        self.dayCountMap = dayCountMap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerBar
            chartViewport
            footerBar
        }
        .amgiCard(elevated: true)
    }

    private var headerBar: some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Image(systemName: "cube.transparent.fill")
                        .foregroundStyle(Color.amgiAccent)
                    Text("3D 记忆留存空间")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                }
                Text("稳定性 S (1~30天) × 难度 D (1~10) → 记忆留存率 R%")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 4)
            expandButton
        }
    }

    private var expandButton: some View {
        let iconName = isExpanded ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right"
        return Button {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.78)) {
                isExpanded.toggle()
            }
        } label: {
            Image(systemName: iconName)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(Color.amgiTextPrimary)
                .frame(width: 32, height: 32)
                .background(Color.amgiSurface, in: Circle())
                .overlay(
                    Circle()
                        .stroke(Color.amgiBorder.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private var chartViewport: some View {
        let targetHeight: CGFloat = isExpanded ? 480 : 350
        return ZStack(alignment: .topTrailing) {
            surfaceChart
                .scaleEffect(effectiveZoom)
                .frame(maxWidth: .infinity)
                .frame(height: targetHeight)
                .contentShape(Rectangle())
                .simultaneousGesture(pinchZoomGesture)

            zoomControlPill
                .padding(10)
        }
        .background(Color.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.amgiBorder.opacity(0.25), lineWidth: 1)
        )
    }

    private var surfaceChart: some View {
        Chart3D {
            SurfacePlot(x: "稳定性(S)", y: "留存率(%)", z: "难度(D)") { (s: Double, d: Double) in
                Self.computeRetention(stability: s, difficulty: d)
            }
            .foregroundStyle(.heightBased(Self.surfaceGradient, yRange: 40.0...100.0))
            .metalness(0.38)
            .roughness(0.18)
        }
        .chartXScale(domain: 1.0...30.0)
        .chartYScale(domain: 40.0...100.0)
        .chartZScale(domain: 1.0...10.0)
        .chart3DPose($cameraPose)
        .chart3DCameraProjection(.perspective)
    }

    private var pinchZoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                gestureZoom = value.magnification
            }
            .onEnded { value in
                zoomScale = min(2.6, max(0.95, zoomScale * value.magnification))
                gestureZoom = 1.0
            }
    }

    private var zoomControlPill: some View {
        let percentText = "\(Int(round(effectiveZoom * 100)))%"
        return HStack(spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    zoomScale = max(0.95, zoomScale - 0.2)
                }
            } label: {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)

            Text(percentText)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .frame(minWidth: 38)

            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                    zoomScale = min(2.6, zoomScale + 0.2)
                }
            } label: {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 13, weight: .bold))
                    .frame(width: 28, height: 28)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.55), in: Capsule())
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private var footerBar: some View {
        HStack(spacing: 8) {
            Label("单指旋转 · 双指缩放", systemImage: "hand.draw")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            Spacer()

            HStack(spacing: 6) {
                cameraPresetButton(title: "立体", pose: .default, targetZoom: 1.35)
                cameraPresetButton(title: "正视", pose: .front, targetZoom: 1.45)
                cameraPresetButton(title: "俯视", pose: .top, targetZoom: 1.45)
            }
        }
    }

    private func cameraPresetButton(title: String, pose: Chart3DPose, targetZoom: CGFloat) -> some View {
        Button {
            withAnimation(.spring(response: 0.42, dampingFraction: 0.76)) {
                cameraPose = pose
                zoomScale = targetZoom
            }
        } label: {
            Text(title)
                .font(.caption2.bold())
                .foregroundStyle(Color.amgiAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.amgiSurface, in: Capsule())
                .overlay(
                    Capsule()
                        .stroke(Color.amgiBorder.opacity(0.3), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private nonisolated static func computeRetention(stability: Double, difficulty: Double) -> Double {
        let stab = max(0.5, stability)
        let diff = max(1.0, min(10.0, difficulty))
        let decay = 19.0 / 81.0
        let factor = 1.0 + decay * (diff * 2.5) / stab
        return pow(factor, -0.5) * 100.0
    }
}
