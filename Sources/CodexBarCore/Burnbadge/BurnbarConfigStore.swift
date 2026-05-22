import Foundation

public struct BurnbarConfig: Codable, Equatable, Sendable {
    public var baseURL: URL
    public var projects: [String: BurnbarProjectConfig]

    public init(
        baseURL: URL = URL(string: "https://burnbadge.mikaelmoise00.workers.dev")!,
        projects: [String: BurnbarProjectConfig] = [:])
    {
        self.baseURL = baseURL
        self.projects = projects
    }
}

public struct BurnbarProjectConfig: Codable, Equatable, Sendable {
    public var provider: UsageProvider
    public var burnbadgeProvider: BurnbadgeProvider
    public var name: String?
    public var badgeToken: String
    public var usageToken: String
    public var badgeUrl: URL
    public var usageUrl: URL
    public var chartUrl: URL
    public var lastPublishedAt: Date?

    public init(
        provider: UsageProvider,
        burnbadgeProvider: BurnbadgeProvider,
        name: String?,
        project: BurnbadgeProject,
        lastPublishedAt: Date? = nil)
    {
        self.provider = provider
        self.burnbadgeProvider = burnbadgeProvider
        self.name = name
        self.badgeToken = project.badgeToken
        self.usageToken = project.usageToken
        self.badgeUrl = project.badgeUrl
        self.usageUrl = project.usageUrl
        self.chartUrl = project.chartUrl
        self.lastPublishedAt = lastPublishedAt
    }
}

public final class BurnbarConfigStore: Sendable {
    public let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? Self.defaultConfigURL()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func load() throws -> BurnbarConfig {
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else {
            return BurnbarConfig()
        }
        let data = try Data(contentsOf: self.fileURL)
        return try self.decoder.decode(BurnbarConfig.self, from: data)
    }

    public func save(_ config: BurnbarConfig) throws {
        let directory = self.fileURL.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try self.encoder.encode(config)
        try data.write(to: self.fileURL, options: [.atomic])
        #if os(macOS) || os(Linux)
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: self.fileURL.path)
        #endif
    }

    public func update(_ mutate: (inout BurnbarConfig) throws -> Void) throws -> BurnbarConfig {
        var config = try self.load()
        try mutate(&config)
        try self.save(config)
        return config
    }

    public static func key(for provider: UsageProvider) -> String {
        provider.rawValue
    }

    public static func defaultConfigURL() -> URL {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".burnbar/config.json")
    }
}
