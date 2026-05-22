import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import Testing
@testable import CodexBarCore

@Suite(.serialized)
struct BurnbadgeTests {
    @Test
    func `provider mapping covers supported publish providers`() {
        #expect(BurnbadgeProvider(usageProvider: .codex) == .openai)
        #expect(BurnbadgeProvider(usageProvider: .openai) == .openai)
        #expect(BurnbadgeProvider(usageProvider: .claude) == .anthropic)
        #expect(BurnbadgeProvider(usageProvider: .openrouter) == .openrouter)
        #expect(BurnbadgeProvider(usageProvider: .opencode) == .opencode)
        #expect(BurnbadgeProvider(usageProvider: .opencodego) == .opencode)
        #expect(BurnbadgeProvider(usageProvider: .cursor) == nil)
    }

    @Test
    func `usage adapter drops invalid days and keeps positive model breakdowns`() {
        let snapshot = CostUsageTokenSnapshot(
            sessionTokens: nil,
            sessionCostUSD: nil,
            last30DaysTokens: nil,
            last30DaysCostUSD: nil,
            daily: [
                CostUsageDailyReport.Entry(
                    date: "2026-04-20",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: nil,
                    costUSD: 1.25,
                    modelsUsed: nil,
                    modelBreakdowns: [
                        CostUsageDailyReport.ModelBreakdown(modelName: "gpt-5.4", costUSD: 1.0),
                        CostUsageDailyReport.ModelBreakdown(modelName: "zero-cost", costUSD: 0),
                        CostUsageDailyReport.ModelBreakdown(modelName: "unknown-cost", costUSD: nil),
                    ]),
                CostUsageDailyReport.Entry(
                    date: "2026-04-21",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: nil,
                    costUSD: 0,
                    modelsUsed: nil,
                    modelBreakdowns: []),
                CostUsageDailyReport.Entry(
                    date: "2026-04-22",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: nil,
                    costUSD: -0.1,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
                CostUsageDailyReport.Entry(
                    date: "2026-04-23",
                    inputTokens: nil,
                    outputTokens: nil,
                    totalTokens: nil,
                    costUSD: nil,
                    modelsUsed: nil,
                    modelBreakdowns: nil),
            ],
            updatedAt: Date(timeIntervalSince1970: 0))

        let usage = BurnbadgeUsageAdapter.dailyUsage(from: snapshot)

        #expect(usage == [
            BurnbadgeDailyUsage(
                date: "2026-04-20",
                cost: 1.25,
                breakdown: [BurnbadgeBreakdownItem(model: "gpt-5.4", cost: 1.0)]),
            BurnbadgeDailyUsage(date: "2026-04-21", cost: 0),
        ])
    }

    @Test
    func `client creates project and publishes usage with expected requests`() async throws {
        let session = Self.stubbedSession()
        let baseURL = try #require(URL(string: "https://burnbadge.test"))
        let client = BurnbadgeClient(baseURL: baseURL, session: session)
        BurnbadgeStubURLProtocol.requests = []
        BurnbadgeStubURLProtocol.handler = { request in
            let path = request.url?.path
            if path == "/api/projects" {
                #expect(request.httpMethod == "POST")
                #expect(request.value(forHTTPHeaderField: "accept") == "application/json")
                #expect(request.value(forHTTPHeaderField: "content-type") == "application/json")
                let payload = try Self.jsonBody(from: request)
                #expect(payload?["provider"] as? String == "openai")
                #expect(payload?["name"] as? String == "Codex badge")
                #expect(payload?["source"] as? String == "burnbar")
                return Self.response(
                    request: request,
                    json: """
                    {
                      "token": "badge-token",
                      "badgeToken": "badge-token",
                      "usageToken": "usage-token",
                      "badgeUrl": "https://burnbadge.test/api/badge/badge-token",
                      "chartUrl": "https://burnbadge.test/api/chart/usage-token",
                      "usageUrl": "https://burnbadge.test/api/usage/usage-token"
                    }
                    """)
            }
            if path == "/api/usage/usage-token" {
                #expect(request.httpMethod == "POST")
                let payload = try Self.jsonBody(from: request)
                let usage = try #require(payload?["usage"] as? [[String: Any]])
                #expect(payload?["provider"] as? String == "openai")
                #expect(usage.count == 1)
                #expect(usage.first?["date"] as? String == "2026-04-20")
                #expect(usage.first?["cost"] as? Double == 1.25)
                return Self.response(
                    request: request,
                    json: """
                    {
                      "provider": "openai",
                      "usage": [{"date": "2026-04-20", "cost": 1.25}],
                      "lastUpdated": "2026-04-21T00:00:00Z",
                      "updatedAt": "2026-04-21T00:00:00Z"
                    }
                    """)
            }
            return Self.response(request: request, status: 404, json: "{}")
        }
        defer {
            BurnbadgeStubURLProtocol.requests = []
            BurnbadgeStubURLProtocol.handler = nil
        }

        let project = try await client.createProject(provider: .openai, name: "Codex badge")
        let result = try await client.publishUsage(
            usageToken: project.usageToken,
            provider: .openai,
            usage: [BurnbadgeDailyUsage(date: "2026-04-20", cost: 1.25)])

        #expect(project.badgeToken == "badge-token")
        #expect(project.usageToken == "usage-token")
        #expect(result.provider == .openai)
        #expect(result.usage == [BurnbadgeDailyUsage(date: "2026-04-20", cost: 1.25)])
        #expect(BurnbadgeStubURLProtocol.requests.map { $0.url?.path } == [
            "/api/projects",
            "/api/usage/usage-token",
        ])
    }

    @Test
    func `client fetches status and renders markdown URLs`() async throws {
        let session = Self.stubbedSession()
        let baseURL = try #require(URL(string: "https://burnbadge.test"))
        let client = BurnbadgeClient(baseURL: baseURL, session: session)
        BurnbadgeStubURLProtocol.requests = []
        BurnbadgeStubURLProtocol.handler = { request in
            #expect(request.httpMethod == "GET")
            #expect(request.url?.path == "/api/status/badge-token")
            #expect(request.url?.query == "days=14")
            return Self.response(
                request: request,
                json: """
                {
                  "provider": "openai",
                  "name": "Codex badge",
                  "source": "burnbar",
                  "days": 14,
                  "totalCost": 12.5,
                  "todayCost": 1.5,
                  "currency": "USD",
                  "latestDate": "2026-04-21",
                  "lastUpdated": "2026-04-21T00:00:00Z",
                  "updatedAt": "2026-04-21T00:00:00Z",
                  "badgeUrl": "https://burnbadge.test/api/badge/badge-token?days=14",
                  "shieldsUrl": "https://img.shields.io/endpoint?url=x"
                }
                """)
        }
        defer {
            BurnbadgeStubURLProtocol.requests = []
            BurnbadgeStubURLProtocol.handler = nil
        }

        let status = try await client.fetchStatus(badgeToken: "badge-token", days: 14)
        let markdown = client.markdown(badgeToken: "badge-token", provider: .openai, days: 14)

        #expect(status.provider == .openai)
        #expect(status.totalCost == 12.5)
        #expect(markdown.hasPrefix("![openai spend](https://img.shields.io/endpoint?"))
        #expect(markdown.contains("url=https://burnbadge.test/api/badge/badge-token?days%3D14"))
        #expect(markdown.contains("logo=openai"))
    }

    @Test
    func `config store saves project tokens and reloads them`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let configURL = directory.appendingPathComponent("config.json")
        let store = BurnbarConfigStore(fileURL: configURL)
        let badgeURL = try #require(URL(string: "https://burnbadge.test/api/badge/badge-token"))
        let chartURL = try #require(URL(string: "https://burnbadge.test/api/chart/usage-token"))
        let usageURL = try #require(URL(string: "https://burnbadge.test/api/usage/usage-token"))
        let baseURL = try #require(URL(string: "https://burnbadge.test"))
        let project = BurnbadgeProject(
            token: "badge-token",
            badgeToken: "badge-token",
            usageToken: "usage-token",
            badgeUrl: badgeURL,
            chartUrl: chartURL,
            usageUrl: usageURL)

        let saved = try store.update { config in
            config.baseURL = baseURL
            config.projects[BurnbarConfigStore.key(for: .codex)] = BurnbarProjectConfig(
                provider: .codex,
                burnbadgeProvider: .openai,
                name: "Codex README badge",
                project: project,
                lastPublishedAt: Date(timeIntervalSince1970: 1_776_273_600))
        }
        let loaded = try store.load()

        #expect(saved == loaded)
        #expect(loaded.baseURL.absoluteString == "https://burnbadge.test")
        #expect(loaded.projects["codex"]?.provider == .codex)
        #expect(loaded.projects["codex"]?.burnbadgeProvider == .openai)
        #expect(loaded.projects["codex"]?.badgeToken == "badge-token")
        #expect(loaded.projects["codex"]?.usageToken == "usage-token")
        #expect(FileManager.default.fileExists(atPath: configURL.path))
    }

    private static func stubbedSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [BurnbadgeStubURLProtocol.self]
        return URLSession(configuration: config)
    }

    private static func jsonBody(from request: URLRequest) throws -> [String: Any]? {
        let data: Data
        if let httpBody = request.httpBody {
            data = httpBody
        } else {
            let stream = try #require(request.httpBodyStream)
            stream.open()
            defer { stream.close() }
            var buffer = [UInt8](repeating: 0, count: 1024)
            var collected = Data()
            while stream.hasBytesAvailable {
                let count = stream.read(&buffer, maxLength: buffer.count)
                if count < 0 {
                    throw stream.streamError ?? URLError(.cannotDecodeContentData)
                }
                if count == 0 { break }
                collected.append(buffer, count: count)
            }
            data = collected
        }
        return try JSONSerialization.jsonObject(with: data) as? [String: Any]
    }

    private static func response(
        request: URLRequest,
        status: Int = 200,
        json: String) -> (HTTPURLResponse, Data)
    {
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: status,
            httpVersion: nil,
            headerFields: ["Content-Type": "application/json"])!
        return (response, Data(json.utf8))
    }
}

final class BurnbadgeStubURLProtocol: URLProtocol {
    nonisolated(unsafe) static var requests: [URLRequest] = []
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        Self.requests.append(self.request)
        guard let handler = Self.handler else {
            self.client?.urlProtocol(self, didFailWithError: URLError(.badServerResponse))
            return
        }

        do {
            let (response, data) = try handler(self.request)
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        } catch {
            self.client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
