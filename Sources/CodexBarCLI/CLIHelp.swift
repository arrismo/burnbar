import CodexBarCore
import Foundation

extension CodexBarCLI {
    static func usageHelp(version: String) -> String {
        """
        CodexBar \(version)

        Usage:
          burnbar usage [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)]
                       [--account <label>] [--account-index <index>] [--all-accounts]
                       [--no-credits] [--no-color] [--pretty] [--status] [--source <auto|web|cli|oauth|api>]
                       [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug] [--augment-debug]

        Description:
          Print usage from enabled providers as text (default) or JSON. Honors your in-app toggles.
          Output format: use --json (or --format json) for JSON on stdout; use --json-output for JSON logs on stderr.
          Source behavior is provider-specific:
          - Codex: OpenAI web dashboard (usage limits, credits remaining, code review remaining, usage breakdown).
            Auto falls back to Codex CLI only when cookies are missing.
          - Claude: claude.ai API.
            Auto falls back to Claude CLI only when cookies are missing.
          - Kilo: app.kilo.ai API.
            Auto falls back to Kilo CLI when API credentials are missing or unauthorized.
          Token accounts are loaded from ~/.burnbar/config.json.
          Use --account or --account-index to select a specific token account.
          Use --all-accounts to fetch every token account, or every visible Codex account for Codex.
          Account selection requires a single provider.

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          burnbar usage
          burnbar usage --provider claude
          burnbar usage --provider gemini
          burnbar usage --format json --provider all --pretty
          burnbar usage --provider all --json
          burnbar usage --status
          burnbar usage --provider codex --source web --format json --pretty
        """
    }

    static func costHelp(version: String) -> String {
        """
        CodexBar \(version)

        Usage:
          burnbar cost [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)]
                       [--no-color] [--pretty] [--refresh]

        Description:
          Print local token cost usage from Claude/Codex native logs plus supported pi sessions.
          This does not require web or CLI access and uses cached scan results unless --refresh is provided.

        Examples:
          burnbar cost
          burnbar cost --provider claude --format json --pretty
        """
    }

    static func serveHelp(version: String) -> String {
        """
        CodexBar \(version)

        Usage:
          burnbar serve [--port <port>] [--refresh-interval <seconds>]
                         [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                         [-v|--verbose]

        Description:
          Start a foreground localhost-only HTTP server that exposes existing CLI JSON payloads.
          The server binds to 127.0.0.1 only in this initial version.

        Endpoints:
          GET /health
          GET /usage
          GET /usage?provider=claude
          GET /usage?provider=all
          GET /cost
          GET /cost?provider=codex

        Examples:
          burnbar serve
          burnbar serve --port 8080 --refresh-interval 60
          curl http://127.0.0.1:8080/usage?provider=all
        """
    }

    static func burnbadgeHelp(version: String) -> String {
        """
        Burnbar \(version)

        Usage:
          burnbar burnbadge create --provider <codex|claude>
                                    [--base-url <url>] [--name <name>] [--days <days>]
          burnbar burnbadge sync --provider <codex|claude>
                                  [--base-url <url>] [--days <days>] [--refresh]
          burnbar burnbadge markdown --provider <codex|claude> [--base-url <url>] [--days <days>]
          burnbar burnbadge status --provider <codex|claude>
                                    [--base-url <url>] [--days <days>] [--format text|json]

        Description:
          Create and publish Burnbadge README badges from local Codex/Claude cost scans.
          Tokens are stored locally in ~/.burnbar/config.json with restrictive permissions.
          Provider credentials are not sent to Burnbadge; only normalized daily spend totals are uploaded.

        Examples:
          burnbar burnbadge create --provider codex --name "Codex README badge"
          burnbar burnbadge sync --provider codex --days 30
          burnbar burnbadge markdown --provider claude --days 30
          burnbar burnbadge status --provider codex --format json --pretty
        """
    }

    static func configHelp(version: String) -> String {
        """
        CodexBar \(version)

        Usage:
          burnbar config validate [--format text|json]
                                 [--json]
                                 [--json-only]
                                 [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                                 [-v|--verbose]
                                 [--pretty]
          burnbar config dump [--format text|json]
                             [--json]
                             [--json-only]
                             [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                             [-v|--verbose]
                             [--pretty]
          burnbar config providers [--format text|json] [--json] [--json-only] [--pretty]
          burnbar config enable --provider <name> [--format text|json] [--json] [--json-only] [--pretty]
          burnbar config disable --provider <name> [--format text|json] [--json] [--json-only] [--pretty]
          burnbar config set-api-key --provider <name> (--api-key <key>|--stdin)
                                    [--no-enable]
                                    [--format text|json] [--json] [--json-only] [--pretty]

        Description:
          Validate or print the Burnbar config file (default: validate).
          providers lists persistent provider enablement.
          enable/disable updates the same provider toggle used by Settings.
          set-api-key stores a provider API key in ~/.burnbar/config.json and enables that provider by default.

        Examples:
          burnbar config validate --format json --pretty
          burnbar config dump --pretty
          burnbar config providers
          burnbar config enable --provider grok
          burnbar config disable --provider cursor
          printf '%s' "$ELEVENLABS_API_KEY" | burnbar config set-api-key --provider elevenlabs --stdin
        """
    }

    static func cacheHelp(version: String) -> String {
        """
        CodexBar \(version)

        Usage:
          burnbar cache clear <--cookies|--cost|--all>
                              [--provider <name>]
                              [--format text|json]
                              [--json]
                              [--json-only]
                              [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                              [-v|--verbose]
                              [--pretty]

        Description:
          Clear cached data. Use --cookies to clear browser cookie caches (stored in Keychain),
          --cost to clear cost usage scan caches, or --all for both.
          Optionally specify --provider with --cookies to clear cookies for a single provider only.

        Examples:
          burnbar cache clear --cookies
          burnbar cache clear --cookies --provider claude
          burnbar cache clear --cost
          burnbar cache clear --all
          burnbar cache clear --all --format json --pretty
        """
    }

    static func rootHelp(version: String) -> String {
        """
        CodexBar \(version)

        Usage:
          burnbar [--format text|json]
                  [--json]
                  [--json-only]
                  [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                  [--provider \(ProviderHelp.list)]
                  [--account <label>] [--account-index <index>] [--all-accounts]
                  [--no-credits] [--no-color] [--pretty] [--status] [--source <auto|web|cli|oauth|api>]
                  [--web-timeout <seconds>] [--web-debug-dump-html] [--antigravity-plan-debug] [--augment-debug]
          burnbar cost [--format text|json]
                       [--json]
                       [--json-only]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
                       [--provider \(ProviderHelp.list)] [--no-color] [--pretty] [--refresh]
          burnbar serve [--port <port>] [--refresh-interval <seconds>]
                       [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>] [-v|--verbose]
          burnbar burnbadge <create|sync|markdown|status> --provider <codex|claude>
          burnbar config <validate|dump|providers> [--format text|json]
                                        [--json]
                                        [--json-only]
                                        [--json-output] [--log-level <trace|verbose|debug|info|warning|error|critical>]
                                        [-v|--verbose]
                                        [--pretty]
          burnbar config enable --provider <name>
          burnbar config disable --provider <name>
          burnbar config set-api-key --provider <name> (--api-key <key>|--stdin)
          burnbar cache clear <--cookies|--cost|--all> [--provider <name>]

        Global flags:
          -h, --help      Show help
          -V, --version   Show version
          -v, --verbose   Enable verbose logging
          --no-color      Disable ANSI colors in text output
          --log-level <trace|verbose|debug|info|warning|error|critical>
          --json-output   Emit machine-readable logs (JSONL) to stderr

        Examples:
          burnbar
          burnbar --format json --provider all --pretty
          burnbar --provider all --json
          burnbar --provider gemini
          burnbar cost --provider claude --format json --pretty
          burnbar serve --port 8080
          burnbar burnbadge create --provider codex --name "Codex README badge"
          burnbar burnbadge sync --provider codex --days 30
          burnbar config validate --format json --pretty
          burnbar config enable --provider grok
          burnbar config set-api-key --provider elevenlabs --stdin
          burnbar cache clear --cookies
        """
    }
}
