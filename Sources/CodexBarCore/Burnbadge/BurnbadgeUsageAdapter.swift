import Foundation

public enum BurnbadgeUsageAdapter {
    public static func dailyUsage(from snapshot: CostUsageTokenSnapshot) -> [BurnbadgeDailyUsage] {
        snapshot.daily.compactMap { entry in
            guard let cost = entry.costUSD, cost >= 0 else { return nil }
            let breakdown = entry.modelBreakdowns?
                .compactMap { model -> BurnbadgeBreakdownItem? in
                    guard let modelCost = model.costUSD, modelCost > 0 else { return nil }
                    return BurnbadgeBreakdownItem(model: model.modelName, cost: modelCost)
                }
            return BurnbadgeDailyUsage(
                date: entry.date,
                cost: cost,
                breakdown: breakdown?.isEmpty == false ? breakdown : nil)
        }
    }
}
