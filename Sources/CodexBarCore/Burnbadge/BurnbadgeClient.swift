import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public final class BurnbadgeClient: Sendable {
    public let baseURL: URL
    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        self.encoder = encoder
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        self.decoder = decoder
    }

    public func createProject(
        provider: BurnbadgeProvider?,
        name: String?,
        source: String = "burnbar") async throws -> BurnbadgeProject
    {
        let requestBody = BurnbadgeCreateProjectRequest(provider: provider, name: name, source: source)
        var request = try self.makeRequest(path: "/api/projects", method: "POST")
        request.httpBody = try self.encoder.encode(requestBody)
        return try await self.send(request, as: BurnbadgeProject.self)
    }

    public func publishUsage(
        usageToken: String,
        provider: BurnbadgeProvider?,
        usage: [BurnbadgeDailyUsage]) async throws -> BurnbadgeUsageIngestResponse
    {
        let requestBody = BurnbadgeUsageIngestRequest(provider: provider, usage: usage)
        var request = try self.makeRequest(path: "/api/usage/\(usageToken)", method: "POST")
        request.httpBody = try self.encoder.encode(requestBody)
        return try await self.send(request, as: BurnbadgeUsageIngestResponse.self)
    }

    public func fetchStatus(badgeToken: String, days: Int? = nil) async throws -> BurnbadgeStatus {
        guard let base = URL(string: "/api/status/\(badgeToken)", relativeTo: self.baseURL)?.absoluteURL,
              var components = URLComponents(url: base, resolvingAgainstBaseURL: false)
        else {
            throw BurnbadgeClientError.invalidURL
        }
        if let days {
            components.queryItems = [URLQueryItem(name: "days", value: String(days))]
        }
        guard let url = components.url else {
            throw BurnbadgeClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "accept")
        return try await self.send(request, as: BurnbadgeStatus.self)
    }

    public func markdown(badgeToken: String, provider: BurnbadgeProvider?, days: Int? = nil) -> String {
        let imageURL = self.shieldsEndpointURL(badgeToken: badgeToken, provider: provider, days: days)
        let label = provider.map { "\($0.rawValue) spend" } ?? "AI spend"
        return "![\(label)](\(imageURL))"
    }

    public func shieldsEndpointURL(
        badgeToken: String,
        provider: BurnbadgeProvider?,
        days: Int? = nil) -> String
    {
        let badgeURL = self.badgeEndpointURL(badgeToken: badgeToken, days: days)
        var components = URLComponents(string: "https://img.shields.io/endpoint")!
        var queryItems = [URLQueryItem(name: "url", value: badgeURL)]
        if let provider {
            let logoName = Self.logoName(for: provider)
            if !logoName.isEmpty {
                queryItems.append(URLQueryItem(name: "logo", value: logoName))
            }
        }
        components.queryItems = queryItems
        return components.url!.absoluteString
    }

    private func badgeEndpointURL(badgeToken: String, days: Int?) -> String {
        let base = URL(string: "/api/badge/\(badgeToken)", relativeTo: self.baseURL)!.absoluteURL
        var components = URLComponents(url: base, resolvingAgainstBaseURL: false)!
        if let days {
            components.queryItems = [URLQueryItem(name: "days", value: String(days))]
        }
        return components.url!.absoluteString
    }

    private func makeRequest(path: String, method: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: self.baseURL)?.absoluteURL else {
            throw BurnbadgeClientError.invalidURL
        }
        var request = URLRequest(url: url)
        request.httpMethod = method
        request.setValue("application/json", forHTTPHeaderField: "accept")
        request.setValue("application/json", forHTTPHeaderField: "content-type")
        return request
    }

    private func send<Response: Decodable>(_ request: URLRequest, as type: Response.Type) async throws -> Response {
        let (data, response) = try await self.session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw BurnbadgeClientError.invalidResponse
        }
        guard 200..<300 ~= http.statusCode else {
            let body = String(data: data, encoding: .utf8)
            throw BurnbadgeClientError.httpStatus(http.statusCode, body)
        }
        return try self.decoder.decode(type, from: data)
    }

    private static func logoName(for provider: BurnbadgeProvider) -> String {
        switch provider {
        case .anthropic: "anthropic"
        case .openai: "openai"
        case .openrouter: "openrouter"
        case .opencode: "opencode"
        case .mock: ""
        }
    }
}

public enum BurnbadgeClientError: LocalizedError, Sendable {
    case invalidURL
    case invalidResponse
    case httpStatus(Int, String?)

    public var errorDescription: String? {
        switch self {
        case .invalidURL:
            "Invalid Burnbadge URL."
        case .invalidResponse:
            "Burnbadge returned an invalid response."
        case let .httpStatus(status, body):
            "Burnbadge request failed with HTTP \(status): \(body ?? "")"
        }
    }
}
