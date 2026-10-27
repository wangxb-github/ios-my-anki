import SwiftUI
import Charts
import Spatial

/// 基于 iOS 26 原生 Chart3D 的三维记忆山脉与空间体素统计视图
public struct MemoryTerrainChart3DView: View {
    public enum DisplayMode: String, CaseIterable, Identifiable {
        case terrain = "FSRS Terrain"
        case voxel = "3D Voxel"

        public var id: String { rawValue }
    }

    /// 真实复习计数映射：dayOffset (0 为今天, -1 为昨天...) -> 复习卡片数
    public let dayCountMap: [Int: Int]

    @State private var mode: DisplayMode = .terrain
    @State private var cameraPose: Chart3DPose = .default

    private struct VoxelSample: Identifiable {
        let id: Int
        let week: Int
        let weekday: Int
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
                items.append(VoxelSample(id: id, week: w, weekday: d, count: val))
                id += 1
            }
        }
        return items
    }

    public init(dayCountMap: [Int: Int] = [:]) {
        self.dayCountMap = dayCountMap
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("3D Memory Space")
                        .font(.system(size: 17, weight: .bold, design: .rounded))
                    Text("FSRS Stability × Difficulty × Retrievability")
                        .font(.system(size: 12, weight: .regular))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Picker("Mode", selection: $mode) {
                    ForEach(DisplayMode.allCases) { m in
                        Text(m.rawValue).tag(m)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 170)
            }

            ZStack {
                if mode == .terrain {
                    Chart3D {
                        SurfacePlot(x: "Stability", y: "Retrievability", z: "Difficulty") { (s: Double, d: Double) in
                            // FSRS 记忆保留率曲面函数
                            let stab = max(0.5, s)
                            let diff = max(1.0, min(10.0, d))
                            let decay = 19.0 / 81.0
                            let factor = 1.0 + decay * (diff * 2.5) / stab
                            return pow(factor, -0.5) * 100.0
                        }
                        .foregroundStyle(.normalBased)
                        .metalness(0.4)
                        .roughness(0.2)
                    }
                    .chart3DPose($cameraPose)
                    .chart3DCameraProjection(.perspective)
                } else {
                    Chart3D {
                        ForEach(voxels) { voxel in
                            RectangleMark(
                                x: .value("Week", voxel.week),
                                y: .value("Reviews", voxel.count),
                                z: .value("Weekday", voxel.weekday)
                            )
                            .foregroundStyle(by: .value("Reviews", voxel.count))
                            .metalness(0.3)
                            .roughness(0.25)
                        }
                    }
                    .chart3DPose($cameraPose)
                    .chart3DCameraProjection(.perspective)
                }
            }
            .frame(height: 280)
            .background(Color.black.opacity(0.15))
            .clipShape(.rect(corners: .concentric(minimum: .fixed(16)), isUniform: true))

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
                }
                .buttonStyle(.glass)
            }
        }
        .padding(16)
        .ankiLiquidGlass(minimumCorner: 20)
    }
}
