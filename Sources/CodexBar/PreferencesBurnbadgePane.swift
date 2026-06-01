import AppKit
import CodexBarCore
import SwiftUI

@MainActor
struct BurnbadgePane: View {
    let settings: SettingsStore
    let store: UsageStore

    @State private var selectedProvider: UsageProvider?
    @State private var projectName = ""
    @State private var days = 30
    @State private var config = BurnbarConfig()
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    private let configStore = BurnbarConfigStore()

    private var enabledProviders: [UsageProvider] {
        self.settings.enabledProvidersOrdered(metadataByProvider: self.store.providerMetadata)
    }

    var body: some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 16) {
                SettingsSection(contentSpacing: 12) {
                    Text("BURNBADGE")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Publish README badges without the CLI")
                            .font(.headline)
                        Text(
                            "Burnbar uploads only normalized daily spend totals. " +
                                "Provider credentials and local session files stay on this Mac.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    HStack(alignment: .top, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Provider")
                                .font(.body)
                            if self.enabledProviders.isEmpty {
                                Text("No providers connected. Enable a provider in the Providers tab first.")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("Only connected providers are shown. Enable more in the Providers tab.")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        Spacer()
                        if self.enabledProviders.isEmpty {
                            Text("None connected")
                                .foregroundStyle(.tertiary)
                        } else {
                            Picker("Provider", selection: self.$selectedProvider) {
                                ForEach(self.enabledProviders, id: \.self) { provider in
                                    Text(Self.displayName(for: provider)).tag(provider as UsageProvider?)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(maxWidth: 180)
                        }
                    }

                    if self.selectedProvider != nil {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Badge name")
                                    .font(.body)
                                Text("Used on Burnbadge to identify this project.")
                                    .font(.footnote)
                                    .foregroundStyle(.tertiary)
                            }
                            Spacer()
                            TextField(self.defaultProjectName, text: self.$projectName)
                                .textFieldStyle(.roundedBorder)
                                .frame(width: 220)
                        }

                        Stepper(value: self.$days, in: 1...366, step: 1) {
                            Text("Publish the last \(self.days) days")
                        }

                        HStack(spacing: 8) {
                            Button(self.project == nil ? "Create badge" : "Create new badge") {
                                self.runCreate()
                            }
                            .disabled(self.isWorking)

                            Button("Sync now") {
                                self.runSync()
                            }
                            .disabled(self.isWorking || self.project == nil)

                            Button("Create & sync") {
                                self.runCreateAndSync()
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(self.isWorking)

                            if self.isWorking {
                                ProgressView()
                                    .controlSize(.small)
                            }
                        }
                    }
                }

                if self.selectedProvider != nil {
                    Divider()

                    SettingsSection(contentSpacing: 12) {
                        Text("CURRENT BADGE")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        if let project = self.project {
                            LabeledContent("Provider", value: Self.displayName(for: project.provider))
                            LabeledContent("Badge token", value: project.badgeToken)
                            LabeledContent("Last published", value: self.lastPublishedText(project.lastPublishedAt))

                            VStack(alignment: .leading, spacing: 6) {
                                Text("README markdown")
                                    .font(.body)
                                Text(self.markdown(for: project))
                                    .font(.system(.footnote, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                            }

                            HStack(spacing: 8) {
                                Button("Copy markdown") { self.copyMarkdown(project) }
                                Button("Open badge") { NSWorkspace.shared.open(project.badgeUrl) }
                                Button("Open chart") { NSWorkspace.shared.open(project.chartUrl) }
                            }
                        } else if let provider = self.selectedProvider {
                            Text(
                                "No Burnbadge project has been created for " +
                                    "\(Self.displayName(for: provider)) yet.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                        .textSelection(.enabled)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .onAppear {
            self.loadConfig()
            if self.selectedProvider == nil {
                self.selectedProvider = self.enabledProviders.first
            }
        }
        .onChange(of: self.enabledProviders) { _, newProviders in
            if self.selectedProvider == nil || !newProviders.contains(self.selectedProvider!) {
                self.selectedProvider = newProviders.first
            }
        }
        .onChange(of: self.selectedProvider) { _, _ in
            self.projectName = ""
            self.statusMessage = nil
            self.errorMessage = nil
        }
    }

    private var project: BurnbarProjectConfig? {
        guard let provider = self.selectedProvider else { return nil }
        return self.config.projects[BurnbarConfigStore.key(for: provider)]
    }

    private var burnbadgeProvider: BurnbadgeProvider {
        guard let provider = self.selectedProvider else { return .openai }
        return BurnbadgeProvider(usageProvider: provider) ?? .openai
    }

    private var defaultProjectName: String {
        guard let provider = self.selectedProvider else { return "README badge" }
        return "\(Self.displayName(for: provider)) README badge"
    }

    private func loadConfig() {
        do {
            self.config = try self.configStore.load()
        } catch {
            self.errorMessage = "Could not load Burnbadge settings: \(error.localizedDescription)"
        }
    }

    private func runCreate() {
        Task { await self.createProject() }
    }

    private func runSync() {
        Task { await self.syncProject() }
    }

    private func runCreateAndSync() {
        Task {
            if await self.createProject() {
                await self.syncProject()
            }
        }
    }

    @discardableResult
    private func createProject() async -> Bool {
        guard let provider = self.selectedProvider else { return false }
        self.isWorking = true
        self.statusMessage = "Creating Burnbadge project…"
        self.errorMessage = nil
        defer { self.isWorking = false }

        do {
            let name = self.projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? self.defaultProjectName
                : self.projectName.trimmingCharacters(in: .whitespacesAndNewlines)
            let client = BurnbadgeClient(baseURL: self.config.baseURL)
            let project = try await client.createProject(
                provider: self.burnbadgeProvider,
                name: name,
                source: "burnbar")
            self.config = try self.configStore.update { config in
                config.baseURL = self.config.baseURL
                config.projects[BurnbarConfigStore.key(for: provider)] = BurnbarProjectConfig(
                    provider: provider,
                    burnbadgeProvider: self.burnbadgeProvider,
                    name: name,
                    project: project)
            }
            self.statusMessage = "Created badge. Copy the markdown below or sync local usage now."
            return true
        } catch {
            self.errorMessage = "Create failed: \(error.localizedDescription)"
            return false
        }
    }

    private func syncProject() async {
        guard let project = self.project, let provider = self.selectedProvider else { return }
        self.isWorking = true
        self.statusMessage = "Scanning local usage and publishing totals…"
        self.errorMessage = nil
        defer { self.isWorking = false }

        do {
            let usage: [BurnbadgeDailyUsage]
            if provider == .opencode || provider == .opencodego {
                usage = try await self.syncOpenCodeProject(provider: provider)
            } else {
                let snapshot = try await CostUsageFetcher().loadTokenSnapshot(
                    provider: provider,
                    forceRefresh: true,
                    historyDays: self.days,
                    refreshPricingInBackground: false)
                usage = BurnbadgeUsageAdapter.dailyUsage(from: snapshot)
            }
            guard !usage.isEmpty else {
                self.errorMessage = "No daily cost data found for \(Self.displayName(for: provider))."
                return
            }

            let client = BurnbadgeClient(baseURL: self.config.baseURL)
            _ = try await client.publishUsage(
                usageToken: project.usageToken,
                provider: project.burnbadgeProvider,
                usage: usage)
            self.config = try self.configStore.update { config in
                config.projects[BurnbarConfigStore.key(for: provider)]?.lastPublishedAt = Date()
            }
            let total = usage.reduce(0) { $0 + $1.cost }
            self.statusMessage = "Published \(usage.count) days: \(UsageFormatter.usdString(total))."
        } catch {
            self.errorMessage = "Sync failed: \(error.localizedDescription)"
        }
    }

    /// Derives cost from OpenCode subscription percentage × Go plan dollar limits.
    /// Publishes today's cost as a single daily entry (accumulates over time with repeated syncs).
    private func syncOpenCodeProject(provider: UsageProvider) async throws -> [BurnbadgeDailyUsage] {
        let dateFormatter = ISO8601DateFormatter()
        dateFormatter.formatOptions = [.withFullDate]
        let today = dateFormatter.string(from: Date())

        let cost: Double
        if provider == .opencodego {
            let cookieHeader = try self.resolveOpenCodeCookie(provider: provider)
            let usageSnapshot = try await OpenCodeGoUsageFetcher.fetchUsage(
                cookieHeader: cookieHeader,
                timeout: 30)
            cost = usageSnapshot.rollingCostUSD
        } else {
            let cookieHeader = try self.resolveOpenCodeCookie(provider: provider)
            let workspaceOverride = self.settings.opencodeWorkspaceID
            let usageSnapshot = try await OpenCodeUsageFetcher.fetchUsage(
                cookieHeader: cookieHeader,
                timeout: 30,
                workspaceIDOverride: workspaceOverride)
            cost = usageSnapshot.rollingCostUSD
        }

        guard cost > 0 else { return [] }
        return [BurnbadgeDailyUsage(date: today, cost: cost)]
    }

    private func resolveOpenCodeCookie(provider: UsageProvider) throws -> String {
        let cookieSource = provider == .opencodego
            ? self.settings.opencodegoCookieSource
            : self.settings.opencodeCookieSource
        if cookieSource == .manual {
            let header = provider == .opencodego
                ? self.settings.opencodegoCookieHeader
                : self.settings.opencodeCookieHeader
            guard !header.isEmpty else {
                throw OpenCodeUsageError.invalidCredentials
            }
            return header
        }
        guard let entry = CookieHeaderCache.load(provider: provider) else {
            throw OpenCodeUsageError.invalidCredentials
        }
        return entry.cookieHeader
    }

    private func markdown(for project: BurnbarProjectConfig) -> String {
        BurnbadgeClient(baseURL: self.config.baseURL).markdown(
            badgeToken: project.badgeToken,
            provider: project.burnbadgeProvider,
            days: self.days)
    }

    private func copyMarkdown(_ project: BurnbarProjectConfig) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(self.markdown(for: project), forType: .string)
        self.statusMessage = "Copied README markdown."
    }

    private func lastPublishedText(_ date: Date?) -> String {
        guard let date else { return "Never" }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private static func displayName(for provider: UsageProvider) -> String {
        ProviderDescriptorRegistry.descriptor(for: provider).metadata.displayName
    }
}
