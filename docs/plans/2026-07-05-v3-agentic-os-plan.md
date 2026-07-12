# Pro Orc v3 — „agenticOS" Plan & Anleitung

> Erstellt 2026-07-05. Quellen: Research-Briefing (Vault: `reference/agentic-os-research.md`),
> Code-Review-Findings (Reinhard, 2026-07-05).

## Vision

Pro Orc wird vom Projekt-Dashboard zum **sichtbaren Agentic OS**: Es zeigt nicht nur
Projekte, sondern das gesamte Claude-Code-Harness — Agents, Skills, deren Zusammenspiel
und laufende Sessions. Read-only bleibt Grundsatz („Dashboard + Launcher, kein
Terminal-Ersatz"). Differenzierung: native macOS-Flutter-App (alle Vergleichsprojekte
sind Electron/Web).

## Konzept „Agentic OS" (Kurzanleitung)

Ein Agent-Harness verhält sich wie ein Betriebssystem: es kuratiert Context (Memory),
bootet über Hooks, stellt Tools bereit — das LLM ist die Anwendung darauf. Ein
Agentic-OS-Setup ergänzt Claude Code um: persistenten Memory, selbst-verbessernde
Skills, geplante Workflows, geteilten Business-Context. Roberts a1-Framework + Obsidian
Vault erfüllt das bereits — Pro Orc v3 macht es **sichtbar**.

### Datenquellen (alle read-only, lokal)

| Quelle | Inhalt | Praktikabilität |
|---|---|---|
| `~/.claude/agents/*.md` + `<projekt>/.claude/agents/` | Agents (YAML-Frontmatter) | Hoch |
| `~/.claude/skills/<name>/SKILL.md` + Plugin-Skills | Skills, Trigger | Hoch (Plugins: Versions-Drift) |
| `~/.claude/projects/<enc>/<session>.jsonl` | Live-Sessions | Mittel — Pfad-Encoding-Fuzzy-Match aus memory_reader wiederverwenden! |
| `.mcp.json`, `settings.json` (3 Ebenen) | Tool-Integrationen, Config | Hoch / Merge-Logik nötig |

## Roadmap

### M1 — Stabilisierung & Fenster-Fix (v2.2)
- **MAJOR-1**: GitHub-URL-Regex um userinfo erweitern (`git_reader.dart:108`) — behebt auch 5 umgebungsabhängige Test-Failures
- **MAJOR-2**: Rescan-Kosten: Git/Memory/Agent-Ergebnisse mtime-cachen bzw. inkrementell nur betroffenes Projekt scannen
- **MAJOR-3**: `memory_reader.dart` auf async I/O umstellen (kein UI-Ruckeln)
- **MINOR-1/2**: catch-Blöcke loggen; `.planning/`-Doppel-I/O in resource_detector eliminieren
- **Security**: `deleteProject` → macOS-Papierkorb statt `rm -rf`
- **Fenster (Option A)**: dynamisches ActivationPolicy-Switching per Swift-MethodChannel —
  Fenster sichtbar → `NSApp.setActivationPolicy(.regular)` (Dock-Icon, Cmd+Tab, Minimieren),
  Fenster versteckt → `.accessory` (menubar-only). LSUIElement bleibt Start-Default.
- Nits: Tray-Tooltip dynamisch, `print`→`debugPrint`, Off-Screen-Guard gegen Display-Bounds

### M2 — Design-Refresh „heller"
- Neues helleres Theme: Light-Variante des Glassmorphism (helle Flächen, weiche Schatten,
  bestehende Akzentfarben Cyan/Fuchsia beibehalten)
- Theme-Umschalter in Settings (Hell/Dunkel/System), Drift-persistiert
- OrbBackground + GlassCard theme-fähig machen (AppColors ThemeExtension erweitern)

### M3 — agenticOS Views (P0)
- **Agents-Tab**: parst globale + projekt-lokale Agents (Frontmatter: name, description,
  model, tools), Karten-Grid analog CodeTab, Detail-Panel mit Markdown-Vorschau
- **Skills-Tab**: parst SKILL.md-Frontmatter (Trigger, Beschreibung), inkl. Plugin-Skills
- Projekt-Karten zeigen zugeordnete lokale Agents/Skills

### M4 — Session-Monitoring & Zusammenarbeits-Graph (P1)
- Live-Ansicht laufender Claude-Sessions (JSONL-Tail über bestehenden FileWatcher)
- Graph-View: Agents ↔ Skills ↔ Projekte (Nodes/Edges, CustomPainter oder graphview-Package)

### M5 — Optional (P2)
- Token-/Kosten-Tracking pro Session/Modell
- settings.json-Anzeige mit korrekter 3-Ebenen-Merge-Logik

## Nicht-Ziele
- Kein bidirektionaler Editor für Agents/Skills (read-only-Grundsatz)
- Kein Terminal-Ersatz, kein Session-Steuern

## Risiken
- Session-JSONL-Format ist inoffiziell → defensiv parsen, Zeile-für-Zeile, Fehler tolerieren
- Pfad-Encoding-Inkonsistenz (`/`, `_`, ` `, `.` → `-`) → bestehende Fuzzy-Match-Strategie wiederverwenden
- Watcher auf `~/.claude/projects` + Sessions = hohe Event-Frequenz → M1-Caching ist Voraussetzung für M4
