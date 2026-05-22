---
summary: "Homebrew Cask release steps for Burnbar."
read_when:
  - Publishing a Burnbar release via Homebrew
  - Updating the Homebrew tap cask definition
---

# Burnbar Homebrew Release Playbook

Homebrew is for the UI app via Cask. When installed via Homebrew, Burnbar disables Sparkle and should be updated via `brew`.

## Prereqs
- Homebrew installed.
- Access to the Burnbar tap repo, e.g. `arrismo/homebrew-tap`.

## 1) Release Burnbar normally
Follow `docs/RELEASING.md` to publish `Burnbar-macos-universal-<version>.zip` to GitHub Releases.

## 2) Update the tap
Update the cask at `Casks/burnbar.rb`:
- `url` points at the GitHub release asset: `.../releases/download/v<version>/Burnbar-macos-universal-<version>.zip`
- Update `sha256` to match that zip.
- Install `Burnbar.app`.

If a standalone CLI formula is published, update `Formula/burnbar.rb`:
- macOS: `.../releases/download/v<version>/BurnbarCLI-v<version>-macos-arm64.tar.gz`
- macOS: `.../releases/download/v<version>/BurnbarCLI-v<version>-macos-x86_64.tar.gz`
- Linux: `.../releases/download/v<version>/BurnbarCLI-v<version>-linux-aarch64.tar.gz`
- Linux: `.../releases/download/v<version>/BurnbarCLI-v<version>-linux-x86_64.tar.gz`

## 3) Verify install
```sh
brew uninstall --cask burnbar || true
brew untap arrismo/tap || true
brew tap arrismo/tap
brew install --cask arrismo/tap/burnbar
open -a Burnbar
```

## 4) Push tap changes
Commit + push in the tap repo.
