# Pro Orc — Project Orchestration Dashboard

Native macOS menubar app that auto-discovers your projects, displays GSD planning status, git activity, and Claude Code tools inventory — all in a glassmorphism dark UI.

![Pro Orc Screenshot](img/watermarked-99246c46-ae22-4b23-81a3-303ddab54c43.jpg)

## Features

- **Auto-scan** configurable directories for projects (code and research)
- **GSD status** at a glance — phase progress, completion percentage, next steps
- **Git integration** — last commit, branch, dirty state, GitHub links
- **Claude Tools inventory** — discovers installed Skills, Plugins, and MCP servers from `~/.claude/`
- **Quick actions** — open in Terminal, Finder, GitHub; right-click context menus
- **Menubar-only** — lives in the macOS menubar, no Dock icon
- **Reactive** — file watcher auto-refreshes when projects change on disk
- **Private projects** — hide projects from the main view, toggle visibility

## Installation

### Homebrew (recommended)

```bash
brew tap mellow-rob/tap
brew install --cask pro-orc
```

### GitHub Release

Download the latest DMG from [Releases](https://github.com/mellow-rob/pro_orc/releases), open it, and drag **pro_orc.app** to Applications.

> **Note:** Pro Orc is ad-hoc signed (no Apple Developer certificate). On first launch, right-click the app and select "Open", or run `xattr -cr /Applications/pro_orc.app` in Terminal.

### From Source

```bash
git clone https://github.com/mellow-rob/pro_orc.git
cd pro_orc/pro_orc
flutter build macos --release
# App bundle at build/macos/Build/Products/Release/pro_orc.app
```

## Getting Started

1. Launch Pro Orc — a menubar icon appears
2. Open **Settings** (gear icon in the navigation rail)
3. Add your project directories (e.g. `~/code`, `~/research`)
4. Projects appear automatically in the **Code** and **Research** tabs
5. Browse installed Claude tools in the **Claude Tools** tab

## Stack

- **Flutter** (macOS native) with **Dart**
- **Riverpod 3.x** for reactive state management
- **Drift** (SQLite) for app configuration and per-project settings
- **tray_manager** + **window_manager** for menubar integration
- Glassmorphism dark theme with animated gradient background

## Development

```bash
cd pro_orc
flutter run -d macos          # Debug run
flutter build macos            # Release build
flutter test                   # Run tests
flutter analyze                # Static analysis
```

### Building a DMG

```bash
brew install create-dmg
./scripts/build-dmg.sh
# Output: dist/ProOrc-<version>-macOS.dmg
```

## Project Structure

```
pro_orc/                    # Flutter macOS app
  lib/
    features/               # UI: code/, research/, claude_tools/, settings/, shell/
    providers/              # Riverpod providers (projects, watcher, database)
    data/models/            # ProjectModel, GsdData, GitData, ClaudeToolModel
    data/services/          # ProjectScanner, GsdParser, GitReader, WatcherService
    data/db/                # Drift database (SQLite v2)
    theme/                  # N3 color system
  test/                     # Unit tests (real temp dirs, no mocks)
.planning/                  # GSD planning docs
```

## GSD Workflow

This project uses the GSD (Get Shit Done) framework for structured planning and execution. Phase artifacts live in `.planning/` — see `ROADMAP.md` for the full phase breakdown.

## License

Private project — not licensed for distribution.
