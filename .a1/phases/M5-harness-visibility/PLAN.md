# M5 — Session-Deep-Dive + Harness-Ansicht + Skill-Launcher

> Geplant 2026-07-05 (Fable 5). Ausführung: Opus-Subagents. Basis: main @ 8f10843 (205 Tests grün).

## Ziel

Pro Orc zeigt nicht nur *dass* Sessions laufen, sondern *was* sie tun; macht den Harness
(Hooks, Rules, Permissions, MCP, Settings-Ebenen) sichtbar; und kann Sessions mit Skill
starten. Read-only-Grundsatz: App liest Konfiguration, schreibt sie nie.

## Architektur-Entscheidungen (verbindlich)

- **AD-1**: Session-Deep-Dive nur lazy (beim Aufklappen), nie im Kern-Scan. `SessionDetail`
  wird per Streaming-Parse gefüllt; unbekannte JSONL-Typen werden ignoriert, Parser wirft nie.
- **AD-2**: Settings-Anzeige pro Ebene (User / Projekt / Local) mit Herkunfts-Badge —
  KEINE nachgebaute Merge-Logik (Drift-Risiko gegenüber Claude-Code-Verhalten).
- **AD-3**: Alle neuen Reader sind pure-Dart-Services in `lib/data/services/`, mtime-Caching
  nach dem `_ScanResultCache`-Muster aus M1, Tests mit echten Temp-Dirs.
- **AD-4**: Launcher nutzt das bestehende osascript-Terminal-Muster (`runInShell: true`),
  Kommando: `claude "/<skill>"` im Projektverzeichnis. Kein Schreiben von Config.

## Wave 1 — Session-Deep-Dive

- [x] `session_reader.readSessionDetail()` erweitern: aus JSONL zusätzlich extrahieren —
      verwendetes Model (falls im Log), erkannte Skill-Invocations, gespawnte Subagents
      (Agent-Tool-Calls mit subagent_type/name), Zeitpunkt + Kurztext der letzten Aktivität.
      Neues Modell `SessionDetail` erweitern (immutable, additive Felder, alle nullable).
- [x] UI: Session-Eintrag im ProjectDetailPanel aufklappbar → zeigt Model, Skills,
      Subagents (als Chips), letzte Aktivität. Ladezustand + Fehlerzustand („Nicht lesbar").
- [x] Tests: Fixture-JSONL mit gemischten/kaputten Zeilen, Subagent-Spawns, Skill-Calls.

## Wave 2 — Harness-Tab

- [ ] Service `harness_reader.dart`: liest read-only
      (a) `~/.claude/settings.json`, `<projekt>/.claude/settings.json`, `.claude/settings.local.json`
          — Hooks-Einträge, Permissions-Listen, env (Ebene wird mitgeführt, AD-2),
      (b) `~/.claude/rules/**/*.md` — Titel (H1) + Dateiname,
      (c) globale MCP-Server (`~/.claude.json` mcpServers bzw. settings) + projekt `.mcp.json` (existiert schon im Scanner — wiederverwenden).
      Defensiv: fehlende Dateien/kaputtes JSON → leere Ergebnisse + Log.
- [ ] Neuer „Harness"-Tab in der NavigationRail (Icon: Schaltkreis/Tune): Sektionen
      Hooks, Rules, Permissions, MCP-Server, jeweils mit Ebenen-Badge (Global/Projekt/Local)
      und „Im Finder zeigen". GlassCard-Muster, beide Themes, UI Deutsch.
- [ ] Tests: harness_reader mit Temp-Dir-Fixtures (3 Ebenen, kaputtes JSON, fehlende Dateien).

## Wave 3 — Skill-Launcher (Quick-Win)

- [ ] Quick-Action auf Projekt-Karte/Detail-Panel: „Mit Skill starten…" → GlassDialog mit
      Skill-Liste (aus bestehendem Skills-Provider, Suchfeld) → startet Terminal im
      Projektpfad mit `claude "/<skill>"` (osascript-Muster, AD-4).
- [ ] Tests: Kommando-Bau (Escaping von Pfaden/Skill-Namen) als pure Funktion getestet.

## Verifikation (jede Wave)

`flutter analyze` 0 Issues · `flutter test` grün · nach Wave 3: `flutter build macos`.
Branch: `feature/v3-m5-harness-visibility`, kleine thematische Commits, keine Co-Authored-By-Zeile.

## Nicht in M5

Learning-Loop-Ansicht + Workflows/Cron (→ M6), voller Netzwerk-Tab, Plugin-Skills,
Kosten-Tracking.
