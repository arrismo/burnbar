import AppKit
import CodexBarCore
import SwiftUI

@MainActor
struct BurnbadgePane: View {
    private static let supportedProviders: [UsageProvider] = [.codex, .claude]

    @State private var selectedProvider: UsageProvider = .codex
    @State private var projectName = ""
    @State private var days = 30
    @State private var config = BurnbarConfig()
    @State private var isWorking = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    private let configStore = BurnbarConfigStore()

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
                            Text("Codex and Claude local cost scans are supported today.")
                                .font(.footnote)
                                .foregroundStyle(.tertiary)
                        }
                        Spacer()
                        Picker("Provider", selection: self.$selectedProvider) {
                            ForEach(Self.supportedProviders, id: \.self) { provider in
                                Text(Self.displayName(for: provider)).tag(provider)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        .frame(maxWidth: 180)
                    }

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
                    } else {
                        Text(
                            "No Burnbadge project has been created for " +
                                "\(Self.displayName(for: self.selectedProvider)) yet.")
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
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
        .onAppear { self.loadConfig() }
        .onChange(of: self.selectedProvider) { _, _ in
            self.projectName = ""
            self.statusMessage = nil
            self.errorMessage = nil
        }
    }

    private var project: BurnbarProjectConfig? {
        self.config.projects[BurnbarConfigStore.key(for: self.selectedProvider)]
    }

    private var burnbadgeProvider: BurnbadgeProvider {
        BurnbadgeProvider(usageProvider: self.selectedProvider) ?? .openai
    }

    private var defaultProjectName: String {
        "\(Self.displayName(for: self.selectedProvider)) README badge"
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
                config.projects[BurnbarConfigStore.key(for: self.selectedProvider)] = BurnbarProjectConfig(
                    provider: self.selectedProvider,
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
        guard let project = self.project else { return }
        self.isWorking = true
        self.statusMessage = "Scanning local usage and publishing totals…"
        self.errorMessage = nil
        defer { self.isWorking = false }

        do {
            let snapshot = try await CostUsageFetcher().loadTokenSnapshot(
                provider: self.selectedProvider,
                forceRefresh: true,
                historyDays: self.days,
                refreshPricingInBackground: false)
            let usage = BurnbadgeUsageAdapter.dailyUsage(from: snapshot)
            guard !usage.isEmpty else {
                self.errorMessage = "No daily cost usage found for \(Self.displayName(for: self.selectedProvider))."
                return
            }

            let client = BurnbadgeClient(baseURL: self.config.baseURL)
            _ = try await client.publishUsage(
                usageToken: project.usageToken,
                provider: project.burnbadgeProvider,
                usage: usage)
            self.config = try self.configStore.update { config in
                config.projects[BurnbarConfigStore.key(for: self.selectedProvider)]?.lastPublishedAt = Date()
            }
            let total = usage.reduce(0) { $0 + $1.cost }
            self.statusMessage = "Published \(usage.count) days: \(UsageFormatter.usdString(total))."
        } catch {
            self.errorMessage = "Sync failed: \(error.localizedDescription)"
        }
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
