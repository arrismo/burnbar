import Foundation
import Testing
@testable import CodexBarCore

struct OpenCodeUsageParserTests {
    @Test
    func `parses workspace I ds`() {
        let text = ";0x00000089;((self.$R=self.$R||{})[\"codexbar\"]=[]," +
            "($R=>$R[0]=[$R[1]={id:\"wrk_01K6AR1ZET89H8NB691FQ2C2VB\",name:\"Default\",slug:null}])" +
            "($R[\"codexbar\"]))"
        let ids = OpenCodeUsageFetcher.parseWorkspaceIDs(text: text)
        #expect(ids == ["wrk_01K6AR1ZET89H8NB691FQ2C2VB"])
    }

    @Test
    func `parses subscription usage`() throws {
        let text = "$R[16]($R[30],$R[41]={rollingUsage:$R[42]={status:\"ok\",resetInSec:5944,usagePercent:17}," +
            "weeklyUsage:$R[43]={status:\"ok\",resetInSec:278201,usagePercent:75}});"
        let now = Date(timeIntervalSince1970: 0)
        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)
        #expect(snapshot.rollingUsagePercent == 17)
        #expect(snapshot.weeklyUsagePercent == 75)
        #expect(snapshot.rollingResetInSec == 5944)
        #expect(snapshot.weeklyResetInSec == 278_201)
    }

    @Test
    func `parses subscription from JSON with reset at`() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let resetAt = now.addingTimeInterval(3600)
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let payload: [String: Any] = [
            "usage": [
                "rollingUsage": [
                    "usagePercent": 0.25,
                    "resetAt": formatter.string(from: resetAt),
                ],
                "weeklyUsage": [
                    "usagePercent": 75,
                    "resetInSec": 7200,
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(data: data, encoding: .utf8) ?? ""

        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)

        #expect(snapshot.rollingUsagePercent == 25)
        #expect(snapshot.weeklyUsagePercent == 75)
        #expect(snapshot.rollingResetInSec == 3600)
        #expect(snapshot.weeklyResetInSec == 7200)
    }

    @Test
    func `parses subscription from candidate windows`() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "windows": [
                "primaryWindow": [
                    "percent": 0.1,
                    "resetInSec": 300,
                ],
                "secondaryWindow": [
                    "percent": 0.5,
                    "resetInSec": 1200,
                ],
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(data: data, encoding: .utf8) ?? ""

        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)

        #expect(snapshot.rollingUsagePercent == 10)
        #expect(snapshot.weeklyUsagePercent == 50)
        #expect(snapshot.rollingResetInSec == 300)
        #expect(snapshot.weeklyResetInSec == 1200)
    }

    @Test
    func `computes usage percent from totals`() throws {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let payload: [String: Any] = [
            "rollingUsage": [
                "used": 25,
                "limit": 100,
                "resetInSec": 600,
            ],
            "weeklyUsage": [
                "used": 50,
                "limit": 200,
                "resetInSec": 3600,
            ],
        ]
        let data = try JSONSerialization.data(withJSONObject: payload)
        let text = String(data: data, encoding: .utf8) ?? ""

        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)

        #expect(snapshot.rollingUsagePercent == 25)
        #expect(snapshot.weeklyUsagePercent == 25)
    }

    @Test
    func `parse subscription throws when fields missing`() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let text = "{\"ok\":true}"

        #expect(throws: OpenCodeUsageError.self) {
            _ = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)
        }
    }

    @Test
    func `derives cost from percentage × Go plan dollar limits`() throws {
        let text = "$R[16]($R[30],$R[41]={rollingUsage:$R[42]={status:\"ok\",resetInSec:5944,usagePercent:17}," +
            "weeklyUsage:$R[43]={status:\"ok\",resetInSec:278201,usagePercent:75}});"
        let now = Date(timeIntervalSince1970: 0)
        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)

        // 17% of $12 = $2.04
        #expect(abs(snapshot.rollingCostUSD - 2.04) < 0.001)
        // 75% of $30 = $22.50
        #expect(abs(snapshot.weeklyCostUSD - 22.50) < 0.001)
    }

    @Test
    func `snapshot toUsageSnapshot includes provider cost`() throws {
        let text = "$R[16]($R[30],$R[41]={rollingUsage:$R[42]={status:\"ok\",resetInSec:3600,usagePercent:50}," +
            "weeklyUsage:$R[43]={status:\"ok\",resetInSec:86400,usagePercent:0}});"
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let snapshot = try OpenCodeUsageFetcher.parseSubscription(text: text, now: now)
        let usage = snapshot.toUsageSnapshot()

        #expect(usage.providerCost != nil)
        #expect(abs(usage.providerCost?.used ?? 0 - 6.00) < 0.001) // 50% × $12
        #expect(usage.providerCost?.limit == OpenCodeGoLimits.rollingUSD)
        #expect(usage.providerCost?.period == "5-hour")
        #expect(usage.providerCost?.currencyCode == "USD")
        #expect(usage.providerCost?.resetsAt != nil)
    }
}
