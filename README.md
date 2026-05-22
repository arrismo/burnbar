# Burnbar 🔥

> Turn local AI coding usage into public README badges.

Burnbar is a CodexBar-derived local companion for [Burnbadge](../burnbadge). It keeps provider credentials on your machine, normalizes local cost usage, and publishes only daily spend totals to Burnbadge.

## Burnbadge publishing MVP

The first implemented path is CLI publishing for local Codex/Claude cost scans:

```bash
# Create a Burnbadge project and save tokens to ~/.burnbar/config.json
swift run CodexBarCLI burnbadge create --provider codex --name "Codex README badge"

# Publish local daily cost totals to Burnbadge
swift run CodexBarCLI burnbadge sync --provider codex --days 30

# Print README badge markdown
swift run CodexBarCLI burnbadge markdown --provider codex --days 30

# Check public badge status
swift run CodexBarCLI burnbadge status --provider codex --days 30
```

Supported Burnbadge mappings for the MVP:

| Burnbar source | Burnbadge provider |
| --- | --- |
| `codex` | `openai` |
| `claude` | `anthropic` |

## Upstream base

Burnbar is based on [CodexBar](https://github.com/steipete/CodexBar), MIT licensed.
