# M6 — Learning-Loop-Ansicht + a1-Phasen-Status + Workflows

> Geplant 2026-07-05 (Fable 5). Ausführung: Opus-Subagent. Basis: main @ 8369413 (230 Tests grün).

## Ziel

Der selbstlernende Teil des Agentic OS wird sichtbar: Learnings/Retros pro Skill,
Synthese-Fälligkeit (a1-evolve), Plan-/Phasen-Fortschritt der a1-Projekte und geplante
Automatisierungen. Read-only.

## Architektur-Entscheidungen (verbindlich)

- **AD-1**: Vault-Pfad ist konfigurierbar (Settings, Drift-persistiert, Default `~/N3URAL-Vault`).
  Fehlt die Vault → Sektion zeigt Leerzustand mit Hinweis, kein Fehler.
- **AD-2**: Alle Zähl-/Parse-Logik in pure-Dart-Services mit mtime-Caching (Muster M1),
  Markdown/JSONL defensiv (kaputte Zeilen überspringen, nie werfen).
- **AD-3**: Workflows/Cron: Es gibt KEIN stabil dokumentiertes Speicherformat für Claude-Code-
  Routinen. Best-effort-Discovery (siehe Wave 3) mit ehrlichem Leerzustand
  („Keine geplanten Workflows gefunden") — NICHT raten, keine fragilen Heuristiken verkaufen.
- **AD-4**: Keine neuen NavigationRail-Tabs mehr (Rail wird voll) — M6 wird eine neue
  Destination „Learning" UND ersetzt nichts; ab jetzt Rail-Icons ohne Labels prüfen
  (NavigationRailLabelType), damit 7 Destinations passen.

## Wave 1 — Learning-Loop-Ansicht

- [x] Service `learning_reader.dart`: liest (a) Vault `pattern/a1-learnings/*.md` — pro Datei
      Retro-Einträge zählen (Muster `✅ Was gut war` bzw. H2/H3-Datumsblöcke, tolerant),
      letzte Änderung; `patterns.md` — Pattern-Cluster-Titel; (b) pro Projekt
      `.a1/phases/*/observations.jsonl` — Zeilen zählen, letzte Beobachtung.
- [x] Modell `LearningData` (immutable): retrosPerSkill, totalSinceLastSynthesis (Heuristik:
      Einträge neuer als letzte patterns.md-Änderung), evolveDue (>=5), observationCounts.
- [x] UI: neuer „Learning"-Tab (Icon: psychology/school): Karten pro Skill (Retro-Anzahl,
      letzter Eintrag), Hinweis-Banner „a1-evolve fällig" wenn evolveDue, Observations pro
      Projekt. „Im Finder zeigen"/„In Obsidian öffnen" (obsidian:// URI) Quick-Actions.
- [x] Settings: Feld „Vault-Pfad" (AD-1).
- [x] Tests: learning_reader mit Temp-Vault-Fixtures (Retro-Zählung, fehlende Vault, kaputte JSONL).

## Wave 2 — a1-Phasen-Status im Projekt-Detail

- [x] Service-Erweiterung (gsd_parser oder neuer `a1_reader.dart`): liest `.a1/roadmap.md`
      (Milestone-Tabelle: Name + Status-Spalte) und `.a1/phases/*/PLAN.md` (Checkbox-Fortschritt
      `- [x]`/`- [ ]`), analog zum bestehenden GSD-Parsing — a1 ist das Nachfolge-Format von GSD.
- [x] UI: ProjectDetailPanel-Sektion „a1 Roadmap": Milestones mit Status-Badge, pro aktiver
      Phase ein Fortschrittsbalken (abgehakte/gesamt Checkboxen). Auf der CodeProjectCard:
      a1-Fortschritt als Fallback, wenn kein GSD-`.planning/` existiert.
- [x] Tests: Temp-Dirs mit .a1-Fixtures (Roadmap-Tabelle, PLAN-Checkboxen, fehlende Dateien).

## Wave 3 — Workflows/Automatisierungen (best-effort, AD-3)

- [x] Service `automation_reader.dart`: sammelt read-only, was auffindbar ist:
      (a) launchd-Agents des Users (`~/Library/LaunchAgents/*.plist`), die `claude` im
      ProgramArguments enthalten; (b) crontab des Users (`crontab -l`, runInShell) gefiltert
      auf `claude`; (c) Stop-/Cron-Hooks aus HarnessData wiederverwenden (Sektion „Automatisch
      bei Events" — Hooks SIND Workflows).
- [x] UI: Sektion „Automatisierungen" im Learning-Tab (Entscheidung: Learning-Tab statt
      Harness-Tab — der a1-Lern-Loop und seine Automatisierungen wie Stop-Hooks für Retros
      oder cron für a1-evolve gehören konzeptionell zusammen): Quelle-Badge
      (launchd/cron/Hook), Kommando maskiert via bestehendem `maskSecrets`.
- [x] Tests: Plist-/Crontab-Parsing als pure Funktionen mit String-Fixtures.

## Verifikation

Pro Wave: `flutter analyze` 0 · `flutter test` grün. Nach Wave 3: `flutter build macos`.
Branch `feature/v3-m6-learning-loop`, kleine Commits, keine Co-Authored-By-Zeile.

## Nicht in M6

Kosten-Tracking, voller Netzwerk-Tab, Plugin-Skills (→ M7). Schreiben in die Vault. Starten/
Stoppen von Automatisierungen.
