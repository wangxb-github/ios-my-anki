import SwiftUI
import Charts
import Spatial

/// 基于 iOS 26 原生 Chart3D 的三维记忆山脉与空间体素统计视图
public struct MemoryTerrainChart3DView: View {
    public enum DisplayMode: String, CaseIterable, Identifiable {
        case terrain = "Terrain"
        case voxel = "3D Voxel"

        public var id: String { rawValue }
    }

    /// 真实复习计数映射：dayOffset (0 为今天, -1 为昨天...) -> 复习卡片数
    public let dayCountMap: [Int: Int]

    @State private var mode: DisplayMode = .terrain
    @State private var cameraPose: Chart3DPose = .default

    private struct VoxelSample: Identifiable {
        let id: Int
        let week: Double
        let weekday: Double
        let count: Double
    }

    private var voxels: [VoxelSample] {
        var items: [VoxelSample] = []
        var id = 0
        let hasRealData = !dayCountMap.isEmpty
        for w in 1...6 {
            for d in 1...7 {
                let dayOffset = -((6 - w) * 7 + (7 - d))
                let val: Double
                if hasRealData {
                    val = Double(dayCountMap[dayOffset] ?? 0)
                } else {
                    val = Double((w * 7 + d * 13) % 25 + 5)
                }
                items.append(
                    VoxelSample(
                        id: id,
                        week: Double(w),
                        weekday: Double(d),
                        count: val
                    )
                )
                id += 1
            }
        }
        return items
    }

    private var maxVoxelY: Double {
        let maxVal = voxels.map(\.count).max() ?? 10.0
        return max(10.0, maxVal * 1.15)
    }

    public init(dayCountMap: [Int: Int] = [:]) {
        self.dayCountMap = dayCountMap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("3D Memory Space")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text(mode == .terrain ? "FSRS Stability × Difficulty × Retrievability" : "6-Week 3D Review Matrix")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 4)
                Picker("Mode", selection: $mode) {
                    ForEach(DisplayMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }

            ZStack {
                if mode == .terrain {
                    Chart3D {
                        SurfacePlot(x: "Stability", y: "Retrievability", z: "Difficulty") { (s: Double, d: Double) in
                            // FSRS 记忆保留率曲面函数 (x: 1...30d, z: 1...10, y: 40...100%)
                            let stab = max(0.5, s)
                            let diff = max(1.0, min(10.0, d))
                            let decay = 19.0 / 81.0
                            let factor = 1.0 + decay * (diff * 2.5) / stab
                            return pow(factor, -0.5) * 100.0
                        }
                        .foregroundStyle(.heightBased)
                        .metalness(0.35)
                        .roughness(0.22)
                    }
                    .chartXScale(domain: 1.0...30.0)
                    .chartYScale(domain: 40.0...100.0)
                    .chartZScale(domain: 1.0...10.0)
                    .chart3DPose($cameraPose)
                    .chart3DCameraProjection(.perspective)
                } else {
                    Chart3D(voxels) { voxel in
                        RuleMark(
                            x: .value("Week", voxel.week),
                            y: .value("Reviews", 0.0..<max(0.5, voxel.count)),
                            z: .value("Weekday", voxel.weekday)
                        )
                        .foregroundStyle(by: .value("Reviews", voxel.count))
                        .metalness(0.3)
                        .roughness(0.25)
                    }
                    .chartXScale(domain: 0.5...6.5)
                    .chartYScale(domain: 0.0...maxVoxelY)
                    .chartZScale(domain: 0.5...7.5)
                    .chart3DPose($cameraPose)
                    .chart3DCameraProjection(.perspective)
                }
            }
            .frame(height: 260)
            .background(Color.black.opacity(0.18), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

            HStack {
                Label("Drag to orbit 3D camera", systemImage: "hand.draw")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
                        cameraPose = .default
                    }
                } label: {
                    Text("Reset Camera")
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
        }
        .amgiCard(elevated: true)
    }
}
