# Phase 25: Open Source Polish - Context

**Gathered:** 2026-03-09
**Status:** Ready for planning

<domain>
## Phase Boundary

Pro Orc als Open Source Projekt veroeffentlichen: MIT-Lizenz, Contributing Guidelines, GitHub-Templates, Repo-Audit (keine Secrets, keine hardcoded Pfade), und README-Update mit aktuellen Features und korrekter Lizenz.

</domain>

<decisions>
## Implementation Decisions

### Lizenz
- MIT License — einfachste Open Source Lizenz, passt fuer Dashboard-Tool
- Copyright: 2026 mellow-rob

### CONTRIBUTING.md
- Sprache: Englisch (internationale Community)
- Inhalt: Prerequisites (Flutter, macOS), Build/Test/Analyze Commands, PR Process, Code Style
- Verweist auf CLAUDE.md fuer Architektur-Details

### GitHub Templates
- Issue Templates: Bug Report + Feature Request (YAML-Format in .github/ISSUE_TEMPLATE/)
- PR Template: .github/pull_request_template.md mit Checklist (tests, analyze, description)
- Release workflow existiert bereits (.github/workflows/release.yml) — kein Aenderungsbedarf

### README Update
- Lizenz-Section: "MIT License" statt "Private project"
- Features-Liste: Claude-Button, Onboarding Wizard, Skill/Plugin Browser ergaenzen
- Screenshots: Platzhalter-Kommentare fuer spaetere interaktive Screenshots einfuegen
- Getting Started: Wizard-Step erwaehnen (statt manueller Settings-Konfiguration)

### Repo Audit
- Hardcoded /Users/rob: Nur noch in Comments (memory_reader.dart) — aufraeumen
- .gitignore: Bereits gut, .planning/ NICHT ignorieren (gehoert zum Projekt)
- pro_orc/README.md: Flutter-Boilerplate loeschen
- pubspec.yaml: publish_to bleibt 'none' (kein pub.dev Package, ist macOS App)

### Scope Exclusions
- Keine Screenshots in diesem Plan (interaktive Arbeit, separater Schritt)
- Keine Homebrew-Cask-Version-Updates (geschieht beim Release-Tag)
- Kein CHANGELOG.md (GitHub Release Notes reichen)

</decisions>

<code_context>
## Existing Code Insights

### Reusable Assets
- README.md: Bereits gute Struktur mit Features, Installation, Getting Started, Stack, Dev, Project Structure
- .github/workflows/release.yml: CI/CD Pipeline existiert und funktioniert
- .gitignore: Vollstaendig fuer Node/Flutter/macOS
- scripts/build-dmg.sh: Build-Script existiert
- homebrew-tap/: Cask-Formula existiert

### What Needs Work
- LICENSE: Fehlt komplett
- CONTRIBUTING.md: Fehlt komplett
- .github/ISSUE_TEMPLATE/: Fehlt komplett
- .github/pull_request_template.md: Fehlt
- README.md Zeile 96: "Private project" → MIT License
- README.md Features: Claude-Button, Onboarding, Plugin Browser fehlen
- pro_orc/README.md: Flutter-Boilerplate, nutzlos
- memory_reader.dart: /Users/rob in Kommentaren

</code_context>

<specifics>
## Specific Ideas

No specific requirements — standard open source patterns.

</specifics>

<deferred>
## Deferred Ideas

- Screenshots im README (interaktive Arbeit)
- CHANGELOG.md (GitHub Release Notes reichen vorerst)

</deferred>

---

*Phase: 25-open-source-polish*
*Context gathered: 2026-03-09*
