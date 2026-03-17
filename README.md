```

 ██████╗ ██████╗  ██████╗      ██████╗ ██████╗  ██████╗
 ██╔══██╗██╔══██╗██╔═══██╗    ██╔═══██╗██╔══██╗██╔════╝
 ██████╔╝██████╔╝██║   ██║    ██║   ██║██████╔╝██║
 ██╔═══╝ ██╔══██╗██║   ██║    ██║   ██║██╔══██╗██║
 ██║     ██║  ██║╚██████╔╝    ╚██████╔╝██║  ██║╚██████╗
 ╚═╝     ╚═╝  ╚═╝ ╚═════╝     ╚═════╝ ╚═╝  ╚═╝ ╚═════╝

         Project Orchestration Dashboard
```

**Your projects. Your AI tools. One glance.**

A native macOS menubar app that auto-discovers your projects, shows planning progress, git activity, and Claude Code tools — all in a glassmorphism dark UI.

[![License: MIT](https://img.shields.io/badge/License-MIT-cyan.svg)](LICENSE)
[![Platform: macOS](https://img.shields.io/badge/Platform-macOS-blue.svg)](https://github.com/mellow-rob/pro_orc/releases)
[![Built with Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B.svg)](https://flutter.dev)
[![Tests: 134 passing](https://img.shields.io/badge/Tests-134%20passing-brightgreen.svg)](pro_orc/test)

---

## Why Pro Orc?

If you juggle multiple projects with Claude Code, you know the pain: scattered terminals, forgotten planning docs, "which project was I working on?", and no quick way to see what's in progress.

**Pro Orc fixes that.** It sits in your menubar, watches your project directories, and gives you a live dashboard of everything — planning status, git state, Claude tools, and one-click access to jump into any project.

### Built for people who ship with AI

Pro Orc is designed for founders, consultants, and developers who use Claude Code as their daily driver. Not a terminal replacement — a command center.

---

## Features

| Feature | Description |
|---------|-------------|
| **Auto-Scan** | Watches configurable directories, discovers projects automatically |
| **GSD Status** | Phase progress, completion %, next steps — at a glance |
| **Git Integration** | Last commit, branch, dirty state, GitHub links |
| **Claude Tools** | Discovers Skills, Plugins, and MCP servers from `~/.claude/` |
| **Claude-Button** | Start Claude Code sessions directly from project cards |
| **Skill/Plugin Browser** | View per-project skills, plugins, MCP servers with metadata |
| **Onboarding Wizard** | First-run setup with Claude Code detection and directory config |
| **Quick Actions** | Terminal, Finder, GitHub, Editor — one click away |
| **Menubar-Only** | Lives in macOS menubar, no Dock icon, always accessible |
| **Reactive** | File watcher auto-refreshes when projects change on disk |
| **Private Projects** | Hide projects from the main view, toggle visibility |

---

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

---

## Getting Started

1. **Launch** — a menubar icon appears (no Dock icon)
2. **Setup wizard** guides you through Claude Code detection and directory configuration
3. **Projects appear** automatically in the **Code** and **Research** tabs
4. **Browse Claude tools** in the **Claude Tools** tab
5. **Click any project card** to open it in Claude Code, Terminal, Finder, or your editor

---

## Stack

- **Flutter** (macOS native) with **Dart**
- **Riverpod 3.x** — reactive state management
- **Drift** (SQLite v2) — app configuration and per-project settings
- **tray_manager** + **window_manager** — native menubar integration
- Glassmorphism dark theme with animated gradient background

---

## Development

```bash
cd pro_orc
flutter run -d macos          # Debug run
flutter test                   # Run 134 tests
flutter analyze                # Static analysis (0 issues)
```

### Building a DMG

```bash
brew install create-dmg
./scripts/build-dmg.sh
# Output: dist/ProOrc-<version>-macOS.dmg
```

---

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

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

[MIT](LICENSE) — Copyright 2026 mellow-rob
