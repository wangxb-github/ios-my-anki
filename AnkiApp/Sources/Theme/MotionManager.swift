import SwiftUI
#if canImport(CoreMotion)
import CoreMotion
#endif
import Observation

/// 120Hz/60Hz 设备陀螺仪姿态引擎，为液态玻璃与 Metal 全息着色器提供物理倾角输入
@Observable
@MainActor
public final class MotionManager {
    public static let shared = MotionManager()

    /// 归一化设备倾角向量: x 对应 roll (-1.0 ... 1.0), y 对应 pitch (-1.0 ... 1.0)
    public var currentTilt: SIMD2<Float> = SIMD2<Float>(0, 0)

    #if os(iOS)
    private let motionManager = CMMotionManager()
    #endif
    private var isUpdating = false
    private var fallbackTimer: Timer?
    private var fallbackPhase: Double = 0.0

    public init() {
        start()
    }

    public func start() {
        guard !isUpdating else { return }
        isUpdating = true

        #if os(iOS)
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let motion else { return }
                let roll = Float(max(-1.0, min(1.0, motion.attitude.roll / (.pi / 4.0))))
                let pitch = Float(max(-1.0, min(1.0, motion.attitude.pitch / (.pi / 4.0))))
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let target = SIMD2<Float>(roll, pitch)
                    self.currentTilt = self.currentTilt * 0.8 + target * 0.2
                }
            }
            return
        }
        #endif

        // 模拟器或无传感器环境回退：平滑伪物理光泽流转
        fallbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.fallbackPhase += 0.02
                let roll = Float(sin(self.fallbackPhase) * 0.35)
                let pitch = Float(cos(self.fallbackPhase * 0.8) * 0.25)
                self.currentTilt = SIMD2<Float>(roll, pitch)
            }
        }
    }

    public func stop() {
        isUpdating = false
        #if os(iOS)
        if motionManager.isDeviceMotionAvailable {
            motionManager.stopDeviceMotionUpdates()
        }
        #endif
        fallbackTimer?.invalidate()
        fallbackTimer = nil
    }
}
