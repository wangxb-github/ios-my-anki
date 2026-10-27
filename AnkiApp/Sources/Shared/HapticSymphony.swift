import UIKit
import CoreHaptics
import AnkiKit

/// 基于 CoreHaptics 的触觉反馈引擎
@MainActor
public final class HapticSymphony {
    public static let shared = HapticSymphony()

    private var engine: CHHapticEngine?
    private var supportsHaptics: Bool = false

    private init() {
        createEngine()
    }

    private func createEngine() {
        supportsHaptics = CHHapticEngine.capabilitiesForHardware().supportsHaptics
        guard supportsHaptics else { return }

        do {
            engine = try CHHapticEngine()
            engine?.stoppedHandler = { reason in
                print("[HapticSymphony] Engine stopped: \(reason)")
            }
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            try engine?.start()
        } catch {
            print("[HapticSymphony] Failed to start engine: \(error)")
        }
    }

    /// 180° 弹簧翻牌棘轮震感
    public func playFlipRatchet() {
        guard supportsHaptics, let engine else {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            return
        }
        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.8)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.9)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)
        
        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    /// 拖拽卡片达到评分吸附阈值时的触觉脉冲
    public func playThresholdSnap(for rating: Rating) {
        guard supportsHaptics, let engine else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
            return
        }

        let intensityValue: Float
        let sharpnessValue: Float
        switch rating {
        case .again:
            intensityValue = 1.0; sharpnessValue = 0.9
        case .hard:
            intensityValue = 0.75; sharpnessValue = 0.7
        case .good:
            intensityValue = 0.85; sharpnessValue = 0.6
        case .easy:
            intensityValue = 0.95; sharpnessValue = 0.8
        }

        let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: intensityValue)
        let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: sharpnessValue)
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: 0)

        do {
            let pattern = try CHHapticPattern(events: [event], parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred()
        }
    }

    /// Easy 斩杀解体微爆震感
    public func playDissolveBurst() {
        guard supportsHaptics, let engine else {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
            return
        }

        var events: [CHHapticEvent] = []
        for i in 0..<3 {
            let relativeTime = Double(i) * 0.04
            let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: Float(1.0 - Double(i) * 0.25))
            let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: Float(0.85 - Double(i) * 0.2))
            events.append(CHHapticEvent(eventType: .hapticTransient, parameters: [intensity, sharpness], relativeTime: relativeTime))
        }

        do {
            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: 0)
        } catch {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        }
    }

    /// 连击升频触觉脉冲
    public func playComboPulse(streak: Int) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = streak > 10 ? .heavy : .medium
        UIImpactFeedbackGenerator(style: style).impactOccurred()
    }
}
