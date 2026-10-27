import Foundation
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

/// 灵动岛复习实时活动控制器
@MainActor
public final class ReviewLiveActivityManager {
    public static let shared = ReviewLiveActivityManager()

    #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
    private var currentActivity: Activity<ReviewActivityAttributes>?
    #endif

    private init() {}

    /// 开始复习时在灵动岛启动实时活动
    public func startActivity(deckName: String, totalCards: Int) {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        // 若已有未结束的活动先静默结束
        endActivity()

        let attributes = ReviewActivityAttributes(deckName: deckName, totalSessionCards: totalCards)
        let initialContentState = ReviewActivityAttributes.ContentState(
            remainingCards: totalCards,
            streakCount: 0,
            currentRatingTitle: "Ready",
            retentionRate: 1.0
        )

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: initialContentState, staleDate: nil)
            )
            self.currentActivity = activity
        } catch {
            print("[LiveActivity] Failed to request activity: \(error)")
        }
        #endif
    }

    /// 更新复习进度与连击火焰状态
    public func updateProgress(remaining: Int, streak: Int, lastRating: String, retentionRate: Double = 1.0) {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let currentActivity else { return }

        let updatedState = ReviewActivityAttributes.ContentState(
            remainingCards: remaining,
            streakCount: streak,
            currentRatingTitle: lastRating,
            retentionRate: retentionRate
        )

        Task {
            await currentActivity.update(
                ActivityContent<ReviewActivityAttributes.ContentState>(
                    state: updatedState,
                    staleDate: nil
                )
            )
        }
        #endif
    }

    /// 复习结束或退出时关闭灵动岛活动
    public func endActivity() {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard let activity = currentActivity else { return }
        currentActivity = nil

        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        #endif
    }
}
