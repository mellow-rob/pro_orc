# Domain Pitfalls — v2.0 Open Source Public Release

**Domain:** Adding Claude-Button, Settings GUI for external JSON config, Skill/Plugin Browser upgrade, Onboarding wizard, and Open Source polish to existing Flutter macOS dashboard (Pro Orc)
**Researched:** 2026-03-06
**Confidence:** HIGH for Claude Code integration pitfalls (verified against actual ~/.claude/ structure and codebase). MEDIUM for open source release concerns (WebSearch + community patterns). HIGH for JSON config race conditions (confirmed by multiple claude-code GitHub issues).

---

## Critical Pitfalls

Mistakes that cause data loss, broken user-facing features, or block the open source release.

---

### Pitfall 1: Settings GUI Writes Corrupt settings.json — Race Condition With Running Claude Code Sessions

**What goes wrong:** Pro Orc reads `~/.claude/settings.json`, presents it in a GUI, and writes it back when the user saves. But Claude Code also reads and writes this file during active sessions (e.g., when user accepts tool permissions, changes model, or when hooks update). If Pro Orc writes while Claude Code is mid-write, the file gets truncated or contains partial JSON. This is a documented, repeatedly-reported issue in the Claude Code repo (issues #18998, #28847, #28922) — JSON corruption from concurrent access causes "truncated/invalid JSON errors multiple times per day" in multi-session setups.

**Why it happens:** JSON files are rewritten in their entirety on every update — no file locking, no atomic writes. Two processes reading the old state and writing their version means the last writer wins and the first writer's changes are lost. Worse, if writes overlap at the OS level, the file can be left in a partially-written state.

**Consequences:** User's Claude Code permissions, MCP server configs, enabled plugins, and hooks get silently corrupted or lost. Claude Code shows cryptic JSON parse errors. User blames Pro Orc.

**How to avoid:**
- Use atomic writes: write to a temp file in the same directory, `fsync`, then `rename` over the original. This is atomic on macOS (APFS/HFS+). Never write directly to `settings.json`.
- Read-modify-write: always re-read the file immediately before writing, apply only the fields Pro Orc manages, and write back. Never cache the file content and write it later.
- Consider a merge strategy: Pro Orc should only touch specific top-level keys it manages (e.g., `permissions.allow`, `mcpServers`, `model`). Read the current file, parse it, update only the relevant keys, serialize the entire object back. This preserves keys Claude Code added that Pro Orc doesn't know about.
- Display a warning if Claude Code is currently running: `pgrep -f "claude"` or check for lock files.

**Warning signs:** User reports "Claude Code forgot my settings" or "JSON parse error" after using Pro Orc's Settings GUI.

**Phase to address:** Settings GUI phase. This is the most critical architectural decision for the entire phase.

---

### Pitfall 2: Claude-Button Fails Silently — `claude` Binary Not on GUI App PATH

**What goes wrong:** The Claude-Button launches `claude` in Terminal.app via osascript. But `claude` is installed at `~/.local/bin/claude` (a symlink to `~/.local/share/claude/versions/X.Y.Z`). macOS GUI apps launched from Finder/Dock/menubar do NOT inherit the user's shell PATH — they get a minimal PATH from `launchd` that does not include `~/.local/bin/`. The existing `runInShell: true` pattern on `Process.run` helps for git (which is in `/usr/bin/` or Homebrew paths sourced by the shell), but `claude` requires the user's full PATH from `.zshrc`/`.zprofile`.

**Why it happens:** This is the same root cause as the existing `runInShell: true` gotcha, but worse. `runInShell: true` makes `Process.run` invoke `/bin/zsh -c "command"` which sources `.zshrc`, getting the full PATH. However, the Claude-Button uses `osascript` to tell Terminal.app to run a command — Terminal.app sources its own login shell PATH, so the command works in Terminal. The pitfall is if anyone tries to use `Process.run('claude', ...)` directly instead of going through Terminal.app.

**How to avoid:**
- For the Claude-Button: use `osascript -e 'tell application "Terminal" to do script "cd /path/to/project && claude"'` — Terminal.app will source the user's login shell, so `claude` will be on PATH. This pattern already works for `rem-sleep` in v1.2.
- For Claude Code detection (onboarding/settings): use `Process.run('which', ['claude'], runInShell: true)` to find the binary. The `runInShell: true` ensures `.zshrc` is sourced and `~/.local/bin` is on PATH.
- Never hardcode the claude binary path — it's a symlink that changes with every version update.
- Store the resolved claude path (from `which claude`) in app config, but re-resolve it periodically since the symlink target changes on updates.

**Warning signs:** Claude-Button does nothing when clicked. No Terminal window opens, or Terminal opens but shows "command not found: claude".

**Phase to address:** Claude-Button phase. Test on a fresh macOS account that has Claude Code installed but hasn't modified the default PATH setup.

---

### Pitfall 3: Hardcoded Personal Paths Leak Into Open Source Release

**What goes wrong:** The codebase contains `/Users/rob` in multiple places:
- `ClaudeToolsScanner` has a fallback: `Platform.environment['HOME'] ?? '/Users/rob'`
- Memory reader path encoding may reference specific directories
- Test files may contain hardcoded paths
- Git history contains personal project paths, Notion URLs, API references

A contributor clones the repo, builds the app, and it tries to read `/Users/rob/.claude/` on their machine. Worse, the git history exposes personal configuration.

**Why it happens:** Natural accumulation during single-developer development. The hardcoded fallback in ClaudeToolsScanner was a reasonable default during development but is a bug in an open source release.

**How to avoid:**
- Search the entire codebase for `/Users/rob` and replace with `Platform.environment['HOME']` or `Platform.environment['USER']`
- Search for hardcoded Notion URLs, GitHub repo URLs, and any personal identifiers
- The `ClaudeToolsScanner` fallback should throw an exception rather than fallback to a hardcoded path: `Platform.environment['HOME'] ?? (throw StateError('HOME not set'))`
- Run `git log --all -p | grep -i "api.key\|secret\|password\|token"` to check git history for secrets
- If secrets are found in history, use `git filter-branch` or BFG Repo Cleaner before making public
- Add a pre-release script that scans for personal paths

**Warning signs:** Build succeeds on your machine but fails or behaves incorrectly on any other developer's machine.

**Phase to address:** Open Source Polish phase. Run the full scan as the first task.

---

### Pitfall 4: settings.json Schema Changes Between Claude Code Versions Break the Settings GUI

**What goes wrong:** The Settings GUI presents fields for `permissions.allow`, `mcpServers`, `model`, `enabledPlugins`, `hooks`, etc. Claude Code updates frequently (version 2.1.70 as of today, with updates every few days). New top-level keys get added regularly (recent additions include `sandbox`, `statusLine`, `effortLevel`, `attribution`, `teammateMode`). If the Settings GUI serializes a fixed schema, it will:
1. Drop unknown keys on write (losing user's custom settings)
2. Show stale field lists (missing new options)
3. Potentially conflict with renamed/deprecated keys (`includeCoAuthoredBy` was deprecated in favor of `attribution`)

**Why it happens:** Claude Code is actively developed with no stability guarantees for settings.json schema. The official JSON schema at `json.schemastore.org/claude-code-settings.json` is updated but Pro Orc would need to track it.

**How to avoid:**
- Never serialize from a Dart model back to JSON. Instead, treat the file as a `Map<String, dynamic>` — read the full JSON, modify only the keys the GUI controls, write the full map back. Unknown keys pass through untouched.
- The GUI should only manage a curated subset of settings: `permissions.allow`/`permissions.deny`, `mcpServers`, `model`, `enabledPlugins`. Do NOT try to expose every possible setting.
- For the `model` field: fetch available model names from a known list but allow freeform input (users may use custom API endpoints with different model names).
- Display a "raw JSON" view as a fallback for advanced users — let them edit the full file if the GUI doesn't cover their need.
- Version-check: if `settings.json` contains keys the GUI doesn't recognize, show a subtle info banner: "Einige Einstellungen werden nur in der JSON-Datei angezeigt"

**Warning signs:** User updates Claude Code and their MCP servers or permissions disappear from the Settings GUI.

**Phase to address:** Settings GUI phase. The pass-through architecture must be the foundation, not an afterthought.

---

### Pitfall 5: ~/.claude/ Directory Structure Changes Break the Skill/Plugin Browser

**What goes wrong:** The `ClaudeToolsScanner` reads specific paths:
- `~/.claude/skills/` for skills (also `~/.agents/skills/`)
- `~/.claude/plugins/installed_plugins.json` for plugin inventory
- `~/.claude/plugins/known_marketplaces.json` for marketplace URLs
- `~/.claude/settings.json` for `enabledPlugins` and `mcpServers`
- `~/.claude/agents/` for agent definitions

Claude Code reorganizes these paths between major versions. The `~/.agents/skills/` directory already shows this — skills moved from one location to another. If Claude Code moves `installed_plugins.json` or changes its schema, the browser shows "Keine Plugins installiert" with no error.

**Why it happens:** The scanner uses empty catch blocks (`catch (_) {}`) everywhere — any read failure is silently swallowed and returns empty results. This is intentional for graceful degradation but makes it impossible to distinguish "no plugins installed" from "plugins directory moved."

**How to avoid:**
- Add version detection: check `claude --version` output at startup and log it. If the version jumps significantly, show a warning.
- Add a health check: if `~/.claude/` exists but `installed_plugins.json` does not, AND `enabledPlugins` in settings.json is non-empty, that's a signal the file moved — show a diagnostic message instead of empty state.
- Keep the graceful degradation for truly missing directories (fresh install), but distinguish it from unexpected missing files (broken/changed layout).
- Watch the Claude Code changelog for directory structure changes. Pin the scanner to known-working versions and update when structure changes are detected.

**Warning signs:** After a Claude Code update, the Tools tab suddenly shows zero plugins despite having many installed.

**Phase to address:** Skill/Plugin Browser phase. Add health diagnostics alongside the scanner upgrade.

---

## Moderate Pitfalls

---

### Pitfall 6: Onboarding Wizard Assumes Claude Code Is Installed via npm — Misses Other Install Methods

**What goes wrong:** The onboarding flow needs to detect if Claude Code is installed. Checking `which claude` works for the standard npm global install. But Claude Code can also be installed via:
- Homebrew: `brew install claude-code` (may use different binary location)
- Direct download from Anthropic
- VS Code / Cursor extension (no CLI binary at all)
- Enterprise managed deployment (custom paths)

If detection only checks `which claude`, users with non-standard installs will see "Claude Code nicht gefunden" even though they use it daily.

**How to avoid:**
- Check multiple detection signals in order:
  1. `which claude` (standard install)
  2. `~/.claude/` directory exists (Claude Code has been used, even if binary not on PATH)
  3. `~/.local/share/claude/` exists (npm global install artifacts)
  4. `ls ~/.claude/settings.json` exists (active user)
- If `~/.claude/` exists but `which claude` fails, the user has Claude Code but it's not on PATH — show a different message: "Claude Code ist installiert, aber nicht im PATH. Fuege ~/.local/bin zu deinem PATH hinzu."
- Do NOT require Claude Code for Pro Orc to work — it should be useful as a project dashboard even without Claude Code. The onboarding should guide but not gate.

**Warning signs:** User who actively uses Claude Code gets the "install Claude Code first" screen.

**Phase to address:** Onboarding phase.

---

### Pitfall 7: Settings GUI Shows settings.json But User Expects settings.local.json Behavior

**What goes wrong:** Claude Code has a settings hierarchy with 5 levels of precedence:
1. Managed settings (highest)
2. CLI arguments
3. `.claude/settings.local.json` (per-project, git-ignored)
4. `.claude/settings.json` (per-project, shared)
5. `~/.claude/settings.json` (global, lowest)

The Settings GUI edits `~/.claude/settings.json` (global). But a user's project may override these settings via `.claude/settings.json` in the project root. The user changes a permission in Pro Orc's GUI, but it has no effect because a project-level settings file takes precedence. The user thinks the GUI is broken.

**How to avoid:**
- Clearly label the GUI as "Globale Einstellungen" — make it obvious these are defaults that projects can override.
- When showing a project's detail panel, consider reading the project-level `.claude/settings.json` and `.claude/settings.local.json` to show the effective (merged) settings for that project.
- Do NOT attempt to edit project-level settings from the global Settings GUI — that's a project-specific action that should live in the project detail panel if anywhere.
- Show a note: "Projekt-spezifische Einstellungen in .claude/settings.json ueberschreiben globale Werte"

**Warning signs:** User changes model in Settings GUI but Claude Code still uses a different model in a specific project.

**Phase to address:** Settings GUI phase. Add scope labels to the UI from the start.

---

### Pitfall 8: Open Source Release Missing Critical Files — LICENSE, CONTRIBUTING, and Code of Conduct

**What goes wrong:** Personal tools open-sourced without standard community files get ignored or rejected by potential contributors:
- No `LICENSE` file = legally ambiguous. GitHub shows "No license" warning. Users can't legally use or modify the code.
- No `CONTRIBUTING.md` = contributors don't know the process. PRs arrive in random formats, with no testing, breaking the build.
- No `CODE_OF_CONDUCT.md` = no community standards. May be required by some organizations before they allow employees to contribute.
- No issue templates = bug reports lack reproduction steps, feature requests lack context.

**Why it happens:** Solo developers don't need these files for themselves. They're easy to forget because the app works fine without them.

**How to avoid:**
- Choose MIT license (most permissive, standard for dev tools)
- Create `CONTRIBUTING.md` with: build instructions, test requirements, PR format, German UI string conventions
- Add `.github/ISSUE_TEMPLATE/` with bug report and feature request templates
- Add `CODE_OF_CONDUCT.md` (use Contributor Covenant as template)
- Create a comprehensive `README.md` with: screenshots, install instructions, feature overview, architecture overview, development setup

**Warning signs:** Repository exists publicly but has zero stars, forks, or contributors after weeks.

**Phase to address:** Open Source Polish phase. These files must exist before the first public commit.

---

### Pitfall 9: Onboarding Wizard Has No "Skip" — Power Users Trapped in Tutorial

**What goes wrong:** The onboarding wizard detects first run (no scan dirs configured, or a flag in Drift DB) and shows a multi-step setup flow. But the target audience includes developers who already have Claude Code set up and just want the dashboard. If the wizard forces them through "Step 1: Install Claude Code" / "Step 2: Choose scan directories" / "Step 3: Learn the UI", they'll quit the app.

**Why it happens:** Onboarding is designed for the least experienced user. Developers building for non-developers over-compensate and create mandatory tutorials.

**How to avoid:**
- Every step must have a "Ueberspringen" (skip) button, prominently visible (not a tiny text link)
- Detect existing setup: if `~/.claude/` exists AND scan dirs are configured in DB, skip onboarding entirely
- If `~/.claude/` exists but no scan dirs: go directly to "Scan-Ordner waehlen" step, skip Claude Code detection
- Offer "Alles ueberspringen — ich kenne mich aus" on the first screen
- Store onboarding completion in Drift DB, not SharedPreferences (already using Drift for all config)
- Never show onboarding again after completion or skip

**Warning signs:** Experienced users close the app during onboarding and never return.

**Phase to address:** Onboarding phase.

---

### Pitfall 10: Claude-Button Opens Multiple Terminal Windows — No Deduplication

**What goes wrong:** User clicks Claude-Button on a project card. osascript tells Terminal.app to open a new tab/window and run `cd /path && claude`. User clicks again (maybe they forgot they already opened it). Now two Terminal windows are running `claude` in the same project directory. Claude Code sessions may conflict or produce confusing output.

**Why it happens:** The osascript `do script` command always creates a new Terminal tab/window. There's no built-in way to check if a Terminal tab is already running `claude` in that directory.

**How to avoid:**
- Accept this as a minor UX issue — Terminal.app deduplication is not worth the complexity
- Show visual feedback on the button after clicking: disable for 2-3 seconds, show a checkmark or "Geoeffnet" text to indicate the action was taken
- Do NOT try to detect running Terminal sessions — that requires accessibility permissions or fragile AppleScript queries
- Alternative: use `open -a Terminal /path/to/project` which reuses the existing Terminal window, then the user types `claude` themselves. Less convenient but no duplication.
- Best compromise: on click, show a brief toast/snackbar "Claude-Session in Terminal geoeffnet" to confirm the action happened, reducing accidental double-clicks

**Warning signs:** Users report "clicking Claude opens two terminals" — mostly a confusion issue, not a data loss issue.

**Phase to address:** Claude-Button phase.

---

### Pitfall 11: README Screenshots Become Stale After UI Changes

**What goes wrong:** The README includes screenshots of the dashboard, project cards, settings, and tools tab. Any UI change (new tab, color adjustment, card layout tweak) makes the screenshots outdated. Stale screenshots make the project look unmaintained and confuse new users who see a different UI than documented.

**Why it happens:** Screenshots are binary assets that can't be auto-generated. No process exists to update them.

**How to avoid:**
- Create a `scripts/take-screenshots.sh` that uses `screencapture` or Flutter's golden test infrastructure to generate screenshots
- Store screenshots in a dedicated `docs/screenshots/` directory with version-prefixed names (e.g., `v2.0-dashboard.png`)
- Add a checklist item to the release process: "Update README screenshots"
- Keep the number of screenshots small (3-5 max) to minimize maintenance burden
- Use annotated screenshots (with callout labels) rather than raw captures — they're more informative and slight UI changes don't require immediate updates

**Warning signs:** GitHub README shows an old version of the UI.

**Phase to address:** Open Source Polish phase.

---

## Technical Debt Patterns

Shortcuts that seem reasonable but create long-term problems.

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Writing full settings.json from Dart model | Simple serialization | Drops unknown keys, breaks on schema changes | Never — always use map-based read-modify-write |
| Hardcoding `~/.claude/` paths | Quick development | Breaks for non-standard installs, XDG compliance | Only as default fallback with environment variable override |
| Empty catch blocks in scanner | Graceful degradation | Can't distinguish "not installed" from "broken" | Only for truly optional features, never for primary functionality |
| Storing onboarding state in SharedPreferences | Simple boolean flag | Already using Drift for all other config, creates two sources of truth | Never — use Drift consistently |
| Skipping file locking for settings.json writes | Simpler code | Data corruption from concurrent Claude Code access | Never — atomic writes are mandatory |

## Integration Gotchas

Common mistakes when connecting Pro Orc to Claude Code's ecosystem.

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| settings.json read/write | Deserializing to typed model, serializing back | Read as `Map<String, dynamic>`, modify specific keys, write back as map |
| settings.json concurrent access | Direct file write (overwrite) | Atomic write: temp file + fsync + rename |
| Claude binary detection | `which claude` only | Multi-signal: `which claude` + `~/.claude/` exists + `~/.local/share/claude/` exists |
| Settings precedence | Editing global and expecting project-level effect | Label as "Globale Einstellungen", show effective per-project settings separately |
| Plugin inventory | Reading `installed_plugins.json` schema as stable | Treat schema as unstable, validate structure before parsing, graceful fallback |
| MCP server config | Assuming one format for server definitions | Handle both `{ mcpServers: {} }` wrapper and flat format (already done in scanner) |
| Skill directory location | Only checking `~/.claude/skills/` | Also check `~/.agents/skills/` (already done), watch for future moves |

## Performance Traps

Patterns that work at small scale but fail as usage grows.

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| Re-reading settings.json on every GUI interaction | Slight lag when toggling permissions | Cache with file-watcher invalidation, debounce writes | >20 permission rules |
| Scanning entire ~/.claude/ for health diagnostics | Startup delay | Only scan on first load + manual refresh, cache results | Large plugin caches (>100 plugins) |
| Parsing all plugin.json files for descriptions | Tools tab takes seconds to load | Cache plugin descriptions in Drift DB, invalidate on mtime change | >50 installed plugins |

## Security Mistakes

Domain-specific security issues for a tool that reads/writes Claude Code config.

| Mistake | Risk | Prevention |
|---------|------|------------|
| Committing settings.json contents to Pro Orc's own git history | Exposes user's permission rules, API endpoints, MCP server configs | Never write Claude settings into Pro Orc's data layer; read-only display + direct file writes |
| Displaying MCP server environment variables in the GUI | Env vars may contain API keys or tokens | Mask env var values by default, show only on explicit click |
| Including personal paths in error messages/crash reports | Privacy violation when open-sourced | Sanitize all paths in logs: replace `/Users/X/` with `~/` |
| Storing resolved claude binary path without re-validating | Stale path after Claude Code update (symlink changes) | Re-resolve `which claude` on each app launch, not just first run |

## UX Pitfalls

Common user experience mistakes in this domain.

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Settings GUI with too many options exposed | Overwhelming for non-developers (target audience) | Show 4-5 essential settings (model, permissions, MCP servers) with "Erweitert" expandable section |
| Onboarding that requires Claude Code to proceed | User can't try the dashboard without full setup | Make Claude Code optional — dashboard works for project overview even without it |
| Claude-Button with no feedback after click | User clicks repeatedly, gets multiple terminals | Show brief "Geoeffnet" state on button for 2-3 seconds |
| Showing raw JSON paths in error messages | Non-developer target audience doesn't understand `~/.claude/settings.json` | Use friendly labels: "Claude Einstellungen" with "Datei anzeigen" link for advanced users |
| README in English only | German-speaking target users feel excluded from their own tool | README in English (open source standard) but with German UI screenshots and bilingual section headers |

## "Looks Done But Isn't" Checklist

Things that appear complete but are missing critical pieces.

- [ ] **Settings GUI:** Write settings.json, then open a Claude Code session — verify settings were not lost or corrupted
- [ ] **Settings GUI:** Add a permission rule in Pro Orc, then add a different one via `claude /permissions`, then open Pro Orc again — verify both rules present
- [ ] **Settings GUI:** Edit settings while Claude Code is actively running — verify no file corruption
- [ ] **Claude-Button:** Click on a project card when Terminal.app is not running — verify Terminal launches and claude starts
- [ ] **Claude-Button:** Click when `claude` is not on PATH (renamed binary) — verify helpful error message, not silent failure
- [ ] **Onboarding:** Delete Drift DB and relaunch — verify onboarding appears. Complete it — verify it never appears again.
- [ ] **Onboarding:** Click "Ueberspringen" on every step — verify app is fully functional without completing any onboarding step
- [ ] **Skill Browser:** Update Claude Code to latest version, relaunch Pro Orc — verify tools tab still shows all skills/plugins
- [ ] **Open Source:** Clone repo on a fresh macOS machine (different username) — verify build succeeds and app launches
- [ ] **Open Source:** Run `grep -r "Users/rob" pro_orc/lib/` — verify zero results
- [ ] **Open Source:** Check LICENSE file exists and is valid
- [ ] **Open Source:** README install instructions work from scratch on a machine with only Flutter and Claude Code installed

## Recovery Strategies

When pitfalls occur despite prevention, how to recover.

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| settings.json corruption (1) | MEDIUM | Claude Code keeps no backups. Add a "backup before write" step: copy settings.json to settings.json.bak before every Pro Orc write. Recovery = copy .bak over .json |
| Claude binary not found (2) | LOW | Add manual path entry in Pro Orc settings. User pastes result of `which claude` from Terminal |
| Hardcoded paths in source (3) | LOW | Global find-and-replace. No architectural change needed |
| Schema drift (4) | LOW | Map-based architecture means unknown keys pass through. Only affects GUI display, not data integrity |
| Directory structure change (5) | MEDIUM | Add diagnostic mode to scanner that logs what it finds vs. expects. Update path constants when new Claude Code version ships |
| Wrong install detection (6) | LOW | Add "manuell konfigurieren" option in onboarding to bypass auto-detection |
| Settings precedence confusion (7) | LOW | Add UI labels. No code architecture change |
| Missing open source files (8) | LOW | Create files from templates. One-time effort |
| Forced onboarding (9) | LOW | Add skip button. Minimal code change |
| Duplicate Terminal windows (10) | LOW | Add button cooldown. Cosmetic fix |

## Pitfall-to-Phase Mapping

How roadmap phases should address these pitfalls.

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| settings.json race condition (1) | Settings GUI | Write settings while Claude Code is running — no corruption |
| Claude binary PATH (2) | Claude-Button | Click button on fresh macOS account — Terminal opens with claude |
| Hardcoded personal paths (3) | Open Source Polish | `grep -r "Users/rob" pro_orc/lib/` returns zero matches |
| Schema drift / unknown keys (4) | Settings GUI | Add unknown key to settings.json manually, open Settings GUI, save — key preserved |
| ~/.claude/ structure changes (5) | Skill/Plugin Browser | Rename a ~/.claude/ subdirectory, verify browser shows diagnostic, not empty state |
| Install detection false negative (6) | Onboarding | Test on machine with Claude Code installed via non-standard method |
| Settings precedence confusion (7) | Settings GUI | "Globale Einstellungen" label visible in UI |
| Missing open source files (8) | Open Source Polish | LICENSE, CONTRIBUTING.md, README.md exist with correct content |
| No skip in onboarding (9) | Onboarding | Skip all steps — app fully functional |
| Terminal deduplication (10) | Claude-Button | Visual feedback after click, button briefly disabled |
| Stale screenshots (11) | Open Source Polish | Screenshots match current UI at release time |

## Sources

- [Claude Code settings.json corruption — Issue #18998](https://github.com/anthropics/claude-code/issues/18998)
- [Claude Code .claude.json race condition — Issue #28847](https://github.com/anthropics/claude-code/issues/28847)
- [Claude Code .claude.json race condition — Issue #28922](https://github.com/anthropics/claude-code/issues/28922)
- [Claude Code official settings documentation](https://code.claude.com/docs/en/settings)
- [Apple Race Conditions and Secure File Operations](https://developer.apple.com/library/archive/documentation/Security/Conceptual/SecureCodingGuide/Articles/RaceConditions.html)
- [Dart:io Process.run PATH issue on macOS — dart-lang/sdk#38364](https://github.com/dart-lang/sdk/issues/38364)
- [Flutter Process.run crashes built macOS app — flutter#89837](https://github.com/flutter/flutter/issues/89837)
- [Open Source Project Checklist — afonsopacifer](https://github.com/afonsopacifer/open-source-checklist)
- [Open Source Project Checklist — libresource](https://github.com/libresource/open-source-checklist)
- [CFPB Open Source Checklist](https://github.com/cfpb/open-source-project-template/blob/main/opensource-checklist.md)
- [Flutter secrets management — Medium](https://medium.com/flutter-community/managing-secrets-in-an-open-sourced-flutter-web-app-8c2219ed72b9)
- [Claude Code Changelog](https://github.com/anthropics/claude-code/blob/main/CHANGELOG.md)
- Codebase analysis: `claude_tools_scanner.dart`, `settings_tab.dart`, `shell_screen.dart`, `~/.claude/settings.json`, `~/.claude/settings.local.json`

---
*Pitfalls research for: Pro Orc v2.0 — Claude-Button, Settings GUI, Skill/Plugin Browser, Onboarding, Open Source Polish*
*Researched: 2026-03-06*
