import Foundation

public enum BurnbadgeProvider: String, Codable, Sendable, CaseIterable {
    case anthropic
    case openai
    case openrouter
    case opencode
    case mock

    public init?(usageProvider: UsageProvider) {
        switch usageProvider {
        case .claude:
            self = .anthropic
        case .codex, .openai:
            self = .openai
        case .openrouter:
            self = .openrouter
        case .opencode, .opencodego:
            self = .opencode
        default:
            return nil
        }
    }
}

public struct BurnbadgeBreakdownItem: Codable, Equatable, Sendable {
    public let model: String
    public let cost: Double

    public init(model: String, cost: Double) {
        self.model = model
        self.cost = cost
    }
}

public struct BurnbadgeDailyUsage: Codable, Equatable, Sendable {
    public let date: String
    public let cost: Double
    public let breakdown: [BurnbadgeBreakdownItem]?

    public init(date: String, cost: Double, breakdown: [BurnbadgeBreakdownItem]? = nil) {
        self.date = date
        self.cost = cost
        self.breakdown = breakdown
    }
}

public struct BurnbadgeCreateProjectRequest: Codable, Sendable {
    public let provider: BurnbadgeProvider?
    public let name: String?
    public let source: String?

    public init(provider: BurnbadgeProvider?, name: String?, source: String? = "burnbar") {
        self.provider = provider
        self.name = name
        self.source = source
    }
}

public struct BurnbadgeProject: Codable, Equatable, Sendable {
    public let token: String
    public let badgeToken: String
    public let usageToken: String
    public let badgeUrl: URL
    public let chartUrl: URL
    public let usageUrl: URL

    public init(
        token: String,
        badgeToken: String,
        usageToken: String,
        badgeUrl: URL,
        chartUrl: URL,
        usageUrl: URL)
    {
        self.token = token
        self.badgeToken = badgeToken
        self.usageToken = usageToken
        self.badgeUrl = badgeUrl
        self.chartUrl = chartUrl
        self.usageUrl = usageUrl
    }
}

public struct BurnbadgeUsageIngestRequest: Codable, Sendable {
    public let provider: BurnbadgeProvider?
    public let usage: [BurnbadgeDailyUsage]

    public init(provider: BurnbadgeProvider?, usage: [BurnbadgeDailyUsage]) {
        self.provider = provider
        self.usage = usage
    }
}

public struct BurnbadgeUsageIngestResponse: Codable, Equatable, Sendable {
    public let provider: BurnbadgeProvider?
    public let usage: [BurnbadgeDailyUsage]
    public let lastUpdated: Date?
    public let updatedAt: Date?
}

public struct BurnbadgeStatus: Codable, Equatable, Sendable {
    public let provider: BurnbadgeProvider?
    public let name: String?
    public let source: String?
    public let days: Int?
    public let totalCost: Double
    public let todayCost: Double
    public let currency: String
    public let latestDate: String?
    public let lastUpdated: Date?
    public let updatedAt: Date?
    public let badgeUrl: URL
    public let shieldsUrl: URL
}
