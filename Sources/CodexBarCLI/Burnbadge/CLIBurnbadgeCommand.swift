import CodexBarCore
import Commander
import Foundation

extension CodexBarCLI {
    private static let burnbadgeCostProviders: Set<UsageProvider> = [.claude, .codex]

    static func runBurnbadgeCreate(_ values: ParsedValues) async {
        let output = CLIOutputPreferences.from(values: values)
        do {
            let options = try Self.decodeBurnbadgeOptions(values, requireConfiguredProject: false)
            let client = BurnbadgeClient(baseURL: options.baseURL)
            let name = options.name ?? Self.defaultBurnbadgeName(for: options.provider)
            let project = try await client.createProject(
                provider: options.burnbadgeProvider,
                name: name,
                source: "burnbar")
            let store = BurnbarConfigStore()
            let config = try store.update { config in
                config.baseURL = options.baseURL
                config.projects[BurnbarConfigStore.key(for: options.provider)] = BurnbarProjectConfig(
                    provider: options.provider,
                    burnbadgeProvider: options.burnbadgeProvider,
                    name: name,
                    project: project)
            }
            let projectConfig = config.projects[BurnbarConfigStore.key(for: options.provider)]!
            Self.printBurnbadgeProject(projectConfig, client: client, days: options.days, output: output)
            Self.exit(code: .success, output: output, kind: .runtime)
        } catch {
            Self.exit(code: .failure, message: error.localizedDescription, output: output, kind: .runtime)
        }
    }

    static func runBurnbadgeSync(_ values: ParsedValues) async {
        let output = CLIOutputPreferences.from(values: values)
        do {
            let options = try Self.decodeBurnbadgeOptions(values, requireConfiguredProject: true)
            guard Self.burnbadgeCostProviders.contains(options.provider) else {
                throw CLIArgumentError("Burnbadge sync currently supports local cost for claude and codex.")
            }
            let fetcher = CostUsageFetcher()
            let snapshot = try await fetcher.loadTokenSnapshot(
                provider: options.provider,
                forceRefresh: values.flags.contains("refresh"),
                historyDays: options.days,
                refreshPricingInBackground: false)
            let usage = BurnbadgeUsageAdapter.dailyUsage(from: snapshot)
            guard !usage.isEmpty else {
                throw CLIArgumentError("No daily cost usage found for \(options.provider.rawValue).")
            }
            let client = BurnbadgeClient(baseURL: options.baseURL)
            _ = try await client.publishUsage(
                usageToken: options.project!.usageToken,
                provider: options.burnbadgeProvider,
                usage: usage)
            let store = BurnbarConfigStore()
            _ = try store.update { config in
                config.baseURL = options.baseURL
                config.projects[BurnbarConfigStore.key(for: options.provider)]?.lastPublishedAt = Date()
            }
            if !output.jsonOnly {
                let total = usage.reduce(0) { $0 + $1.cost }
                let formattedTotal = UsageFormatter.usdString(total)
                print("Published \(usage.count) days for \(options.provider.rawValue): \(formattedTotal)")
                print(client.markdown(
                    badgeToken: options.project!.badgeToken,
                    provider: options.burnbadgeProvider,
                    days: options.days))
            }
            Self.exit(code: .success, output: output, kind: .runtime)
        } catch {
            Self.exit(code: .failure, message: error.localizedDescription, output: output, kind: .runtime)
        }
    }

    static func runBurnbadgeMarkdown(_ values: ParsedValues) async {
        let output = CLIOutputPreferences.from(values: values)
        do {
            let options = try Self.decodeBurnbadgeOptions(values, requireConfiguredProject: true)
            let client = BurnbadgeClient(baseURL: options.baseURL)
            print(client.markdown(
                badgeToken: options.project!.badgeToken,
                provider: options.burnbadgeProvider,
                days: options.days))
            Self.exit(code: .success, output: output, kind: .runtime)
        } catch {
            Self.exit(code: .failure, message: error.localizedDescription, output: output, kind: .runtime)
        }
    }

    static func runBurnbadgeStatus(_ values: ParsedValues) async {
        let output = CLIOutputPreferences.from(values: values)
        do {
            let options = try Self.decodeBurnbadgeOptions(values, requireConfiguredProject: true)
            let client = BurnbadgeClient(baseURL: options.baseURL)
            let status = try await client.fetchStatus(
                badgeToken: options.project!.badgeToken,
                days: options.days)
            if Self.decodeFormat(from: values) == .json {
                Self.printJSON(status, pretty: output.pretty)
            } else {
                print("Provider: \(status.provider?.rawValue ?? "unknown")")
                print("Total: \(UsageFormatter.usdString(status.totalCost))")
                print("Today: \(UsageFormatter.usdString(status.todayCost))")
                print("Last updated: \(status.lastUpdated.map(String.init(describing:)) ?? "never")")
                print("Badge: \(status.shieldsUrl.absoluteString)")
            }
            Self.exit(code: .success, output: output, kind: .runtime)
        } catch {
            Self.exit(code: .failure, message: error.localizedDescription, output: output, kind: .runtime)
        }
    }

    private static func decodeBurnbadgeOptions(
        _ values: ParsedValues,
        requireConfiguredProject: Bool) throws -> DecodedBurnbadgeOptions
    {
        let provider = try Self.decodeBurnbadgeProvider(from: values)
        guard let burnbadgeProvider = BurnbadgeProvider(usageProvider: provider) else {
            throw CLIArgumentError("Provider \(provider.rawValue) cannot be published to Burnbadge yet.")
        }
        let store = BurnbarConfigStore()
        let config = try store.load()
        let rawBaseURL = values.options["baseURL"]?.last
        let baseURL = try Self.decodeBurnbadgeBaseURL(rawBaseURL) ?? config.baseURL
        let days = try Self.decodeBurnbadgeDays(values.options["days"]?.last)
        let project = config.projects[BurnbarConfigStore.key(for: provider)]
        if requireConfiguredProject, project == nil {
            throw CLIArgumentError("No Burnbadge project for \(provider.rawValue). Run burnbadge create first.")
        }
        return DecodedBurnbadgeOptions(
            provider: provider,
            burnbadgeProvider: burnbadgeProvider,
            baseURL: baseURL,
            name: values.options["name"]?.last,
            days: days,
            project: project)
    }

    private static func decodeBurnbadgeProvider(from values: ParsedValues) throws -> UsageProvider {
        guard let raw = values.options["provider"]?.last else {
            throw CLIArgumentError("Missing --provider.")
        }
        guard let selection = ProviderSelection(argument: raw),
              case let .single(provider) = selection
        else {
            throw CLIArgumentError("--provider must be one provider name.")
        }
        return provider
    }

    private static func decodeBurnbadgeBaseURL(_ raw: String?) throws -> URL? {
        guard let raw, !raw.isEmpty else { return nil }
        guard let url = URL(string: raw), url.scheme != nil, url.host != nil else {
            throw CLIArgumentError("--base-url must be a full URL.")
        }
        return url
    }

    private static func decodeBurnbadgeDays(_ raw: String?) throws -> Int {
        guard let raw else { return 30 }
        guard let days = Int(raw), days > 0, days <= 366 else {
            throw CLIArgumentError("--days must be between 1 and 366.")
        }
        return days
    }

    private static func defaultBurnbadgeName(for provider: UsageProvider) -> String {
        let displayName = ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
        return "\(displayName) README badge"
    }

    private static func printBurnbadgeProject(
        _ project: BurnbarProjectConfig,
        client: BurnbadgeClient,
        days: Int,
        output: CLIOutputPreferences)
    {
        guard !output.jsonOnly else { return }
        print("Created Burnbadge project for \(project.provider.rawValue).")
        print("Public badge token: \(project.badgeToken)")
        print("Private usage token: \(project.usageToken)")
        print("README markdown:")
        print(client.markdown(
            badgeToken: project.badgeToken,
            provider: project.burnbadgeProvider,
            days: days))
    }
}

private struct DecodedBurnbadgeOptions {
    let provider: UsageProvider
    let burnbadgeProvider: BurnbadgeProvider
    let baseURL: URL
    let name: String?
    let days: Int
    let project: BurnbarProjectConfig?
}

struct BurnbadgeOptions: CommanderParsable {
    @Flag(names: [.short("v"), .long("verbose")], help: "Enable verbose logging")
    var verbose: Bool = false

    @Flag(name: .long("json-output"), help: "Emit machine-readable logs")
    var jsonOutput: Bool = false

    @Option(name: .long("log-level"), help: "Set log level (trace|verbose|debug|info|warning|error|critical)")
    var logLevel: String?

    @Option(name: .long("provider"), help: "Provider to publish: claude | codex")
    var provider: ProviderSelection?

    @Option(name: .long("base-url"), help: "Burnbadge base URL")
    var baseURL: String?

    @Option(name: .long("name"), help: "Burnbadge project name")
    var name: String?

    @Option(name: .long("days"), help: "Usage window in days (1...366)")
    var days: Int?

    @Option(name: .long("format"), help: "Output format: text | json")
    var format: OutputFormat?

    @Flag(name: .long("json"), help: "")
    var jsonShortcut: Bool = false

    @Flag(name: .long("json-only"), help: "Emit JSON only (suppress non-JSON output)")
    var jsonOnly: Bool = false

    @Flag(name: .long("pretty"), help: "Pretty-print JSON output")
    var pretty: Bool = false

    @Flag(name: .long("refresh"), help: "Force refresh by ignoring cached scans")
    var refresh: Bool = false
}
