# M7 — Netzwerk-Tab, Plugin-Skills, Kosten-Tracking

> Geplant 2026-07-05 (Fable 5). Ausführung: Opus-Subagent. Basis: main @ 695d189 (253 Tests grün).
> Letzter Milestone der v3-„agenticOS"-Roadmap.

## Architektur-Entscheidungen (verbindlich)

- **AD-1**: Netzwerk-Tab ersetzt KEINE Rail-Destination — er wird als Vollbild-Ansicht aus dem
  AgentsTab heraus geöffnet („Netzwerk anzeigen"-Button), um die Rail bei 7 Destinations zu halten.
- **AD-2**: Graph-Layout deterministisch und einfach (Spalten-Layout wie der Mini-Graph aus M4,
  skaliert auf alle Projekte; kein Force-Directed-Layout, keine neue Dependency). Wiederverwendung
  von `CollaborationGraphData` — auf Multi-Projekt erweitern, nicht duplizieren.
- **AD-3**: Plugin-Skills: NUR das dokumentiert-stabilste Layout lesen
  (`~/.claude/plugins/**/skills/*/SKILL.md`, rekursiv mit Tiefenlimit), Scope-Badge „Plugin";
  bei Nichtauffinden stiller Leerzustand. Kein Parsen von Plugin-Manifesten.
- **AD-4**: Kosten-/Token-Tracking ist eine SCHÄTZUNG aus Session-JSONL (usage-Felder der
  assistant-Messages, soweit vorhanden) — UI kennzeichnet Werte ausdrücklich als „ca.".
  Aggregation lazy pro Session-Detail + Tages-Summe pro Projekt; kein Vollscan aller JSONL
  im Kern-Scan (Muster AD-1 aus M5).

## Wave 1 — Voller Netzwerk-Tab

- [x] `CollaborationGraphData.buildAll(projects, agents, skills)`: Multi-Projekt-Graph
      (Projekte mittig, geteilte Agents/Skills verbinden mehrere Projekte).
      → als `MultiCollaborationGraphData.buildAll` umgesetzt (GraphNode/Edge-Typen
      wiederverwendet; eigener Rückgabetyp nötig, da `projectNodes` eine Liste ist).
- [x] Vollbild-Ansicht mit Zoom (InteractiveViewer), Hover-Highlight wie M4, Tap auf
      Projekt-Node → ProjectDetailPanel. Beide Themes. Öffnung via „Netzwerk anzeigen"
      im AgentsTab (AD-1).
- [x] Tests: buildAll (geteilte Nodes dedupliziert, Edges korrekt, leere Eingaben).

## Wave 2 — Plugin-Skills

- [ ] `ClaudeToolsScanner`: Plugin-Skills-Scan gemäß AD-3, `SkillData.scope = plugin`,
      Plugin-Name aus Pfad. SkillsTab: Sektion „Plugin-Skills" + Badge.
- [ ] Tests: Temp-Fixture mit Plugin-Verzeichnisstruktur, Tiefenlimit, fehlendes Verzeichnis.

## Wave 3 — Token-/Kosten-Schätzung

- [ ] `session_reader.readSessionDetail()`: usage-Felder aufsummieren (input/output/cache
      tokens, model), defensiv (Felder fehlen oft). `SessionDetail` additiv erweitern.
- [ ] UI: im aufgeklappten Session-Detail „~N Tokens (in/out)" + Modell; im ProjectDetailPanel
      Summe über die angezeigten Sessions. Kennzeichnung „ca." (AD-4). KEINE Euro-Beträge
      (Preise ändern sich — nur Tokens).
- [ ] Tests: Fixture-JSONL mit/ohne usage-Felder, gemischte Modelle.

## Verifikation

Pro Wave: analyze 0 · tests grün. Nach Wave 3: build macos. Branch `feature/v3-m7-network-costs`.

## Nicht in M7

Euro-Kosten, Live-Token-Ticker, Plugin-Manifest-Parsing, Graph-Physik.
