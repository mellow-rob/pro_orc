# Phase 11: Claude Tools Panel - Context

**Gathered:** 2026-02-23
**Status:** Ready for planning

<domain>
## Phase Boundary

Der Claude-Tools-Tab zeigt automatisch erkannte Skills, MCP-Server und Plugins aus `~/.claude/` an — mit Name, Typ und Beschreibung. Reine Anzeige und Discovery, kein Management oder Installation von Tools.

</domain>

<decisions>
## Implementation Decisions

### Card-Layout & Gruppierung
- Drei Sektionen untereinander (nicht Tabs): Skills, Plugins, MCP-Server — vertikal scrollbar
- Kleinere Mini-Cards (GlassCard-Stil aber kompakter als Projekt-Cards) — mehr Tools pro Zeile
- Eigene Akzentfarbe pro Typ (Skills, Plugins, MCP jeweils unterschiedlich — aus n3urala1-System)
- Sektions-Überschriften: Icon + Text + Anzahl (z.B. "🔧 Skills (7)")
- Sektionen immer offen, kein Accordion
- Alphabetische Sortierung innerhalb jeder Sektion
- Suchfeld oben im Tab — filtert alle drei Sektionen live, nur nach Name

### Erkennung & Metadaten
- **Skills**: Name + Beschreibung + Homepage-URL aus `~/.claude/skills/*/SKILL.md` YAML-Frontmatter
- **Plugins**: Name + Marketplace + Version + Enabled-Status aus `installed_plugins.json` + `settings.json` enabledPlugins; Beschreibung aus Cache-Dateien lesen wenn verfügbar
- **MCP-Server**: Name + Command/URL aus `~/.claude/settings.json` mcpServers — nur globale, keine projekt-spezifischen
- Skills ohne SKILL.md oder Frontmatter: Claude's Discretion (Fallback-Logik)

### Interaktion & Aktionen
- **Skill-Cards**: Finder öffnen (Skill-Verzeichnis) + Homepage im Browser öffnen
- **Plugin-Cards**: Marketplace-Link öffnen (URL aus Marketplace-Info ableiten)
- **MCP-Server-Cards**: Config-Datei (settings.json) im Editor öffnen
- Kein Detail-Panel bei Card-Klick — alles Wichtige direkt auf der Card sichtbar
- Suchfeld filtert nur nach Name (nicht Beschreibung)

### Leer- & Sonderfälle
- Komplett leerer Tab: Hilfetext mit Anleitung (was Skills, Plugins, MCP-Server sind + wie installieren)
- Pro Sektion eigener Empty State (z.B. "Keine Skills installiert") — leere Sektionen bleiben sichtbar
- Live-Aktualisierung via File-Watcher auf `~/.claude/` — konsistent mit Code/Research-Tabs
- Fehler (z.B. nicht lesbare Dateien): dezenter Hinweis am Ende der betroffenen Sektion

### Claude's Discretion
- Reihenfolge der drei Sektionen (Skills/Plugins/MCP)
- Fallback für Skills ohne SKILL.md (Ordnername vs. überspringen)
- Exakte Farben pro Typ aus dem n3urala1-System
- Mini-Card Dimensionen und Grid-Konfiguration
- Empty-State Text und Anleitungsinhalt
- Marketplace-URL Ableitung aus Plugin-Metadaten

</decisions>

<specifics>
## Specific Ideas

- Discovery-Quellen sind klar definiert:
  - Skills: `~/.claude/skills/*/SKILL.md` — YAML-Frontmatter (name, description, homepage)
  - Plugins: `~/.claude/plugins/installed_plugins.json` — JSON mit installPath, version, marketplace
  - Plugins Enabled: `~/.claude/settings.json` → enabledPlugins Map
  - MCP-Server: `~/.claude/settings.json` → mcpServers Map
- Plugin-Beschreibungen aus dem Cache versuchen zu lesen (z.B. aus installPath)
- File-Watcher Konsistenz: gleicher Mechanismus wie WatcherService für Projekte

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 11-claude-tools-panel*
*Context gathered: 2026-02-23*
