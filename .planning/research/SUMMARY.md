# Project Research Summary

**Project:** Pro Orc v2.0 — Open Source Public Release
**Domain:** macOS Flutter dashboard enhancement + Claude Code integration + open source readiness
**Researched:** 2026-03-06
**Confidence:** HIGH

## Executive Summary

Pro Orc v2.0 transforms the dashboard from a passive project viewer into an active Claude Code launcher and configuration manager, then ships it as an open source product. The five features (Claude-Button, Settings GUI, Skill/Plugin Browser upgrade, Onboarding, Open Source Polish) require zero new dependencies — everything builds on existing `dart:io`, `dart:convert`, and proven osascript/Process.run patterns already shipping in production. This is an integration project, not a greenfield build.

The recommended approach is dependency-driven phasing: Claude-Button first (15 LOC, highest impact, validates the core "dashboard as launcher" vision), then Settings GUI (provides the `ClaudeSettingsService` needed by downstream features), then Browser upgrade (depends on Settings service for toggle writes), then Onboarding (benefits from all features being complete), and finally Open Source Polish (requires final UI for screenshots/docs). The total estimated scope is approximately 900 LOC new code across 7 new files, plus approximately 160 LOC modifications across 10 existing files.

The dominant risk is settings.json corruption from concurrent access with running Claude Code sessions. This is a documented, repeatedly-reported issue (GitHub issues #18998, #28847, #28922). The mitigation is non-negotiable: atomic writes (temp file + fsync + rename), read-modify-write on every save, and map-based JSON preservation that never drops unknown keys. Secondary risks include hardcoded personal paths leaking into the open source release and Claude Code schema drift breaking the Settings GUI — both addressable with straightforward prevention strategies.

## Key Findings

### Recommended Stack

No new Flutter/Dart dependencies are needed for v2.0. All five features build on existing packages plus `dart:io` and `dart:convert`, both already used throughout the codebase. The existing stack (Flutter 3.41.1, Riverpod 3.x, Drift v2, file_selector, watcher, lucide_icons) covers every requirement.

**Core technologies (all existing):**
- `dart:io Process.run` + osascript: Claude-Button launch, CLI detection — proven pattern from v1.2 `openRemSleep()`
- `dart:convert jsonDecode/jsonEncode`: Settings GUI read/write of `~/.claude/settings.json` — same approach as `ClaudeToolsScanner`
- `Drift SQLite`: Onboarding state persistence via schema migration v2 to v3 — single column addition
- `claudeToolsWatcherProvider`: Reactive invalidation for all new features — no new filesystem watchers needed

**Claude Code configuration files fully mapped:**
- Settings hierarchy: global `~/.claude/settings.json` < project `.claude/settings.json` < project `.claude/settings.local.json`
- Plugin system: `installed_plugins.json` (v2 schema), `known_marketplaces.json`, plugin metadata in `.claude-plugin/plugin.json`
- Skills/agents: `~/.claude/agents/*.md` with YAML frontmatter (22 files on disk), `~/.claude/commands/` (34+ commands)
- All schemas verified against actual files on disk — HIGH confidence

### Expected Features

Note: FEATURES.md contains v1.5 research (shipped). v2.0 feature scope comes from brainstorming.

**Must have (table stakes):**
- Claude-Button on every project card as primary quick action (leftmost position)
- Settings GUI for `~/.claude/settings.json` — effort level, model, enabled plugins, MCP servers (read-only)
- Plugin enable/disable toggles in the Skill/Plugin Browser
- First-run onboarding wizard with Claude CLI detection and scan-dir setup
- LICENSE, README.md, CONTRIBUTING.md for open source release

**Should have (differentiators):**
- Per-project tool filtering in the Browser tab
- Settings precedence indicator ("Globale Einstellungen" label, project override visibility)
- Smart onboarding that skips steps when setup is already detected
- Health diagnostics when `~/.claude/` structure changes unexpectedly

**Defer (v2+ / post-launch):**
- Raw JSON editor fallback for advanced settings
- MCP server write operations (read-only display sufficient for v2.0)
- Drag-and-drop project import
- Cross-memory search

### Architecture Approach

The existing 3-layer architecture (Presentation, Riverpod Providers, Pure Dart Services) remains unchanged. All v2.0 features integrate as new components within existing layers — no structural changes, no new tabs, no new watchers. Seven new files (~900 LOC) and ten modified files (~160 LOC). Two new providers (`claudeSettingsProvider`, `onboardingProvider`) join the existing six. Drift migrates from v2 to v3 with a single column addition.

**Major components:**
1. `ClaudeSettingsService` — read/write `~/.claude/settings.json` with raw JSON preservation; never drops unknown keys
2. `ClaudeDetectorService` — multi-signal Claude CLI detection (`which claude` + directory existence + config health)
3. `ClaudeSettingsModel` — typed overlay on raw `Map<String, dynamic>`; known fields extracted, unknown fields pass through
4. `OnboardingWizard` — modal GlassDialog with internal step state; replaces existing `_checkFirstLaunch()`
5. `ClaudeSettingsSection` — new section in SettingsTab using existing `_buildSection()` helper

### Critical Pitfalls

1. **settings.json race condition with Claude Code** — concurrent writes corrupt JSON. Use atomic writes (temp + fsync + rename), always re-read before write, modify only managed keys. This is the single most important architectural decision for the Settings GUI.

2. **Hardcoded personal paths in source code** — `/Users/rob` exists in fallback paths and potentially tests. Must scan entire codebase and replace with `Platform.environment['HOME']` before open source release. Also scan git history for secrets.

3. **Claude Code schema drift** — settings.json gains new top-level keys with every Claude Code release. Never serialize from a Dart model back to JSON. Use map-based read-modify-write: read full JSON, update only managed keys, write back complete map. Unknown keys pass through untouched.

4. **Claude binary not on GUI app PATH** — `~/.local/bin/claude` is not in macOS GUI app PATH. Claude-Button must go through Terminal.app via osascript (which sources login shell). Direct `Process.run('claude', ...)` would fail. CLI detection must use `runInShell: true`.

5. **Onboarding trapping power users** — mandatory multi-step wizard frustrates experienced users. Every step needs "Ueberspringen", and a global "Alles ueberspringen" on the first screen. Auto-skip entirely if `~/.claude/` exists AND scan dirs are already configured.

## Implications for Roadmap

Based on research, suggested phase structure:

### Phase 1: Claude-Button
**Rationale:** Smallest change (approximately 15 LOC, 2 files modified), highest impact. Validates the core v2.0 vision: "dashboard as Claude launcher." Zero dependencies on other phases. Can ship as a point release immediately.
**Delivers:** Claude quick action as primary (leftmost) button on all project cards. Opens Terminal.app with `cd /project && claude`.
**Addresses:** Core product vision — one-click Claude Code session launch
**Avoids:** Pitfall 2 (PATH issues) by using osascript + Terminal.app pattern, not direct Process.run; Pitfall 10 (duplicate terminals) with brief button feedback/cooldown

### Phase 2: Claude Settings Service + GUI
**Rationale:** `ClaudeSettingsService` is the foundation for Phase 3 (plugin toggle writes) and Phase 4 (onboarding config health check). Building it second unblocks both downstream features. Fully testable with temp dirs.
**Delivers:** New service (read/write settings.json with raw JSON preservation), new model, new provider, new Settings tab section with effort level dropdown, plugin toggles, read-only MCP/hooks display
**Addresses:** Settings management, plugin enable/disable
**Avoids:** Pitfall 1 (race condition) with atomic writes; Pitfall 4 (schema drift) with map-based pass-through; Pitfall 7 (precedence confusion) with "Globale Einstellungen" label
**Estimated scope:** approximately 470 LOC (4 new files, 2 modified)

### Phase 3: Skill/Plugin Browser Upgrade
**Rationale:** Toggle writes require `ClaudeSettingsService` from Phase 2. Per-project filtering is independent but logically groups here. Transforms Claude Tools tab from read-only inventory to full management interface.
**Delivers:** Enable/disable toggles on plugin cards, per-project tool filter dropdown, "Oeffnen" action on skills/plugins, health diagnostics for unexpected `~/.claude/` changes
**Addresses:** Plugin management, per-project tool visibility
**Avoids:** Pitfall 5 (directory structure changes) with health check diagnostics
**Estimated scope:** approximately 110 LOC (3-4 files modified)

### Phase 4: Onboarding and First Run
**Rationale:** Benefits from all other features being complete — onboarding can reference real UI. Needs Drift migration v3, which should be the last schema change. Replaces existing `_checkFirstLaunch` cleanly.
**Delivers:** Multi-step GlassDialog wizard: Claude CLI detection, scan-dir setup, optional first import, autostart config. Smart skip logic for existing setups.
**Addresses:** First-run experience for new users, Claude Code installation guidance
**Avoids:** Pitfall 6 (install detection) with multi-signal detection; Pitfall 9 (forced onboarding) with skip at every step
**Estimated scope:** approximately 460 LOC (3 new files, 3 modified)

### Phase 5: Open Source Polish
**Rationale:** Must come last — screenshots, README, and guides need the final UI. Zero code changes, documentation only.
**Delivers:** MIT LICENSE, README.md with screenshots and install instructions, CONTRIBUTING.md with build/test/PR conventions, GitHub issue templates, Homebrew formula update, hardcoded path scrub
**Addresses:** Open source readiness, community onboarding
**Avoids:** Pitfall 3 (personal path leakage) with full codebase scan; Pitfall 8 (missing OSS files) with complete file set; Pitfall 11 (stale screenshots) by running last

### Phase Ordering Rationale

- **Dependency chain drives order:** Phase 2 (Settings Service) must precede Phase 3 (Browser toggle writes) and Phase 4 (Onboarding config checks). Phase 1 has no dependencies and delivers the highest-impact feature first.
- **Schema migration isolation:** Drift v3 migration lives in Phase 4 (last code phase), avoiding migration churn during active development of Phases 1-3.
- **Documentation last:** Phase 5 requires final UI state for screenshots and accurate README content. Shipping it earlier would create rework.

```
Phase 1 (Claude-Button) ──┐
                           ├──> Phase 3 (Browser Upgrade)
Phase 2 (Settings GUI) ───┤
                           ├──> Phase 4 (Onboarding)
                           │
                           └──> Phase 5 (Open Source Polish)
```

### Research Flags

Phases likely needing deeper research during planning:
- **Phase 2 (Settings GUI):** Atomic write implementation in Dart, exact GUI layout for settings section, debounce strategy for toggle writes vs text fields. The race condition mitigation is well-understood but implementation details need validation.
- **Phase 4 (Onboarding):** Wizard step content/copy, smart skip logic edge cases, Drift migration v3 exact schema.

Phases with standard patterns (skip research-phase):
- **Phase 1 (Claude-Button):** Identical to existing osascript patterns. Copy-paste level implementation.
- **Phase 3 (Browser Upgrade):** Extends existing ClaudeToolsTab with straightforward widget additions. All data sources already parsed.
- **Phase 5 (Open Source Polish):** Standard OSS files from templates. No technical research needed.

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | Zero new dependencies. All patterns verified against production code and actual files on disk. |
| Features | MEDIUM | v2.0 feature scope from brainstorming, not formal research. Scope is clear but prioritization within features needs validation. |
| Architecture | HIGH | All component boundaries, data flows, and integration points verified against existing codebase. LOC estimates based on comparable existing code. |
| Pitfalls | HIGH | Critical pitfalls verified with Claude Code GitHub issues and Apple documentation. Race condition is a known, documented problem with concrete mitigation. |

**Overall confidence:** HIGH

### Gaps to Address

- **Settings GUI scope finalization:** Which settings keys to expose as editable vs read-only is a MEDIUM confidence recommendation. May need adjustment based on user testing.
- **Onboarding copy/content:** Step text, descriptions, and guidance messages not yet written. Needs German copy matching existing UI language conventions.
- **MCP server env var masking:** Security recommendation to mask env vars containing potential API keys needs UX design.
- **Per-project settings display:** Architecture supports showing effective (merged) settings per project, but the exact UI is undefined. Could be deferred to post-v2.0.

## Sources

### Primary (HIGH confidence)
- [Claude Code Settings Documentation](https://code.claude.com/docs/en/settings) — full settings.json schema
- Actual `~/.claude/settings.json`, `settings.local.json` on disk — key structure verified
- Actual `~/.claude/plugins/installed_plugins.json` (14 plugins, v2 schema) — plugin system mapped
- Actual `~/.claude/agents/` (22 agent files) and `~/.claude/commands/` (34+ commands) — skills/commands verified
- Claude CLI binary `~/.local/bin/claude` v2.1.70 — installation path confirmed
- Pro Orc codebase: `claude_tools_scanner.dart`, `quick_actions_service.dart`, `settings_tab.dart`, `shell_screen.dart`

### Secondary (MEDIUM confidence)
- Claude Code GitHub issues [#18998](https://github.com/anthropics/claude-code/issues/18998), [#28847](https://github.com/anthropics/claude-code/issues/28847), [#28922](https://github.com/anthropics/claude-code/issues/28922) — JSON corruption from concurrent access
- [Apple Secure File Operations](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Articles/RaceConditions.html) — atomic write patterns
- Open source checklists: [afonsopacifer](https://github.com/afonsopacifer/open-source-checklist), [CFPB](https://github.com/cfpb/open-source-project-template)

---
*Research completed: 2026-03-06*
*Ready for roadmap: yes*
