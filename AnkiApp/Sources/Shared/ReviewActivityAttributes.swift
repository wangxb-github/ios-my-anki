import Foundation
#if canImport(ActivityKit) && !targetEnvironment(macCatalyst)
import ActivityKit

/// 灵动岛与实时活动（Live Activity）状态属性
public struct ReviewActivityAttributes: ActivityAttributes, Sendable {
    public struct ContentState: Codable, Hashable, Sendable {
        public var remainingCards: Int
        public var streakCount: Int
        public var currentRatingTitle: String
        public var retentionRate: Double

        public init(
            remainingCards: Int,
            streakCount: Int = 0,
            currentRatingTitle: String = "",
            retentionRate: Double = 1.0
        ) {
            self.remainingCards = remainingCards
            self.streakCount = streakCount
            self.currentRatingTitle = currentRatingTitle
            self.retentionRate = retentionRate
        }
    }

    public var deckName: String
    public var totalSessionCards: Int

    public init(deckName: String, totalSessionCards: Int) {
        self.deckName = deckName
        self.totalSessionCards = totalSessionCards
    }
}
#endif
