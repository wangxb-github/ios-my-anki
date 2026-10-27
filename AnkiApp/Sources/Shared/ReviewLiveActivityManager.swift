import Foundation
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit
#endif

/// 灵动岛复习实时活动控制器
@MainActor
public final class ReviewLiveActivityManager {
    public static let shared = ReviewLiveActivityManager()

    private init() {}

    /// 开始复习时在灵动岛启动实时活动
    public func startActivity(deckName: String, totalCards: Int) {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let attributes = ReviewActivityAttributes(deckName: deckName, totalSessionCards: totalCards)
        let initialContentState = ReviewActivityAttributes.ContentState(
            remainingCards: totalCards,
            streakCount: 0,
            currentRatingTitle: "Ready",
            retentionRate: 1.0
        )

        Task.detached {
            for existing in Activity<ReviewActivityAttributes>.activities {
                await existing.end(nil, dismissalPolicy: .immediate)
            }
            _ = try? Activity.request(
                attributes: attributes,
                content: ActivityContent(state: initialContentState, staleDate: nil)
            )
        }
        #endif
    }

    /// 更新复习进度与连击火焰状态
    public func updateProgress(remaining: Int, streak: Int, lastRating: String, retentionRate: Double = 1.0) {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        let updatedState = ReviewActivityAttributes.ContentState(
            remainingCards: remaining,
            streakCount: streak,
            currentRatingTitle: lastRating,
            retentionRate: retentionRate
        )

        Task.detached {
            let content = ActivityContent(state: updatedState, staleDate: nil)
            for activity in Activity<ReviewActivityAttributes>.activities {
                await activity.update(content)
            }
        }
        #endif
    }

    /// 复习结束或退出时关闭灵动岛活动
    public func endActivity() {
        #if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
        Task.detached {
            for activity in Activity<ReviewActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        #endif
    }
}
