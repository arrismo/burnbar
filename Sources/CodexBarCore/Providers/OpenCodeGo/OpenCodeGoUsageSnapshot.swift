import Foundation

/// OpenCode subscription Go plan dollar limits (see opencode.ai/docs/go).
public enum OpenCodeGoLimits {
    public static let rollingUSD: Double = 12 // 5-hour window
    public static let weeklyUSD: Double = 30
    public static let monthlyUSD: Double = 60
}

public struct OpenCodeGoUsageSnapshot: Sendable {
    public let hasMonthlyUsage: Bool
    public let rollingUsagePercent: Double
    public let weeklyUsagePercent: Double
    public let monthlyUsagePercent: Double
    public let rollingResetInSec: Int
    public let weeklyResetInSec: Int
    public let monthlyResetInSec: Int
    public let zenBalanceUSD: Double?
    public let updatedAt: Date

    /// Derived cost from percentage × Go plan dollar limits.
    public var rollingCostUSD: Double {
        self.rollingUsagePercent / 100 * OpenCodeGoLimits.rollingUSD
    }

    /// Derived cost from percentage × Go plan dollar limits.
    public var weeklyCostUSD: Double {
        self.weeklyUsagePercent / 100 * OpenCodeGoLimits.weeklyUSD
    }

    /// Derived cost from percentage × Go plan dollar limits.
    public var monthlyCostUSD: Double {
        self.monthlyUsagePercent / 100 * OpenCodeGoLimits.monthlyUSD
    }

    public init(
        hasMonthlyUsage: Bool,
        rollingUsagePercent: Double,
        weeklyUsagePercent: Double,
        monthlyUsagePercent: Double,
        rollingResetInSec: Int,
        weeklyResetInSec: Int,
        monthlyResetInSec: Int,
        zenBalanceUSD: Double? = nil,
        updatedAt: Date)
    {
        self.hasMonthlyUsage = hasMonthlyUsage
        self.rollingUsagePercent = rollingUsagePercent
        self.weeklyUsagePercent = weeklyUsagePercent
        self.monthlyUsagePercent = monthlyUsagePercent
        self.rollingResetInSec = rollingResetInSec
        self.weeklyResetInSec = weeklyResetInSec
        self.monthlyResetInSec = monthlyResetInSec
        self.zenBalanceUSD = zenBalanceUSD
        self.updatedAt = updatedAt
    }

    public func toUsageSnapshot() -> UsageSnapshot {
        let rollingReset = self.updatedAt.addingTimeInterval(TimeInterval(self.rollingResetInSec))
        let weeklyReset = self.updatedAt.addingTimeInterval(TimeInterval(self.weeklyResetInSec))

        let primary = RateWindow(
            usedPercent: self.rollingUsagePercent,
            windowMinutes: 5 * 60,
            resetsAt: rollingReset,
            resetDescription: nil)
        let secondary = RateWindow(
            usedPercent: self.weeklyUsagePercent,
            windowMinutes: 7 * 24 * 60,
            resetsAt: weeklyReset,
            resetDescription: nil)
        let tertiary: RateWindow?
        if self.hasMonthlyUsage {
            let monthlyReset = self.updatedAt.addingTimeInterval(TimeInterval(self.monthlyResetInSec))
            tertiary = RateWindow(
                usedPercent: self.monthlyUsagePercent,
                windowMinutes: 30 * 24 * 60,
                resetsAt: monthlyReset,
                resetDescription: nil)
        } else {
            tertiary = nil
        }

        return UsageSnapshot(
            primary: primary,
            secondary: secondary,
            tertiary: tertiary,
            providerCost: ProviderCostSnapshot(
                used: self.rollingCostUSD,
                limit: OpenCodeGoLimits.rollingUSD,
                currencyCode: "USD",
                period: "5-hour",
                resetsAt: rollingReset,
                updatedAt: self.updatedAt),
            updatedAt: self.updatedAt,
            identity: nil)
    }

    public func withZenBalanceUSD(_ balance: Double?) -> OpenCodeGoUsageSnapshot {
        OpenCodeGoUsageSnapshot(
            hasMonthlyUsage: self.hasMonthlyUsage,
            rollingUsagePercent: self.rollingUsagePercent,
            weeklyUsagePercent: self.weeklyUsagePercent,
            monthlyUsagePercent: self.monthlyUsagePercent,
            rollingResetInSec: self.rollingResetInSec,
            weeklyResetInSec: self.weeklyResetInSec,
            monthlyResetInSec: self.monthlyResetInSec,
            zenBalanceUSD: balance,
            updatedAt: self.updatedAt)
    }
}
