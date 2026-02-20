# Phase 10: Card Widgets + Quick Actions - Context

**Gathered:** 2026-02-20
**Status:** Ready for planning

<domain>
## Phase Boundary

Live-Projekt-Karten mit allen v1.0-Datenfeldern im Code- und Research-Tab, Quick-Action-Buttons, Private/Visible-Toggle, Detail-Ansicht bei Klick, und Live-Update-Verifikation end-to-end. Kein Stale-Indikator. Kein Drag & Drop.

</domain>

<decisions>
## Implementation Decisions

### Karten-Layout & Grid
- Responsive Grid, passt sich der Fensterbreite an (2-4 Spalten)
- Großzügige Dichte: alle Felder mit Abstand dargestellt, Next-Step-Text mehrzeilig sichtbar
- Sortierung nach letzter Aktivität (zuletzt geändertes Projekt zuerst)
- Kein Stale-Indikator — bewusst weggelassen
- Kein Drag & Drop — Sortierung ist automatisch

### Code-Karten vs. Research-Karten
- Visuell unterschiedlich: andere Akzentfarbe + andere Icons
- Research-Karten nutzen Fuchsia-Akzent (statt Cyan), eigenes Research-Icon
- Code-Karten nutzen Cyan-Akzent, eigenes Code-Icon
- Gleiche GlassCard-Basis, aber Farb-/Icon-Differenzierung macht Typ sofort erkennbar

### Karten-Inhalte (Code-Tab)
- Projektname + Versionsnummer in der Titelzeile (z.B. "Pro Orc v1.1")
- Farbiger Badge-Chip für GSD-Status
- 4 Status-Zustände: In Progress (Cyan), Planned (Gelb/Orange), Complete (Grün), Not Started (Grau)
- Horizontale Progress-Bar in Cyan mit Prozent-Anzeige
- Next Step prominent dargestellt (eigener Bereich, gut lesbar)
- Projekt-Beschreibung aus PROJECT.md gekürzt (1-2 Zeilen, Ellipsis)
- Keine Commit-Message, stattdessen Versionsnummer neben dem Projektnamen

### Karten-Inhalte (Research-Tab)
- Projektname + Beschreibung (gekürzt)
- Keine Git-Metriken
- Fuchsia-Akzent, Research-Icon

### Empty-State
- Freundlicher Hinweis-Text wenn keine Projekte gefunden werden
- Anleitung/Erklärung wie man Projekte anlegt
- macOS nativer Ordner-Picker (NSOpenPanel) zum Ändern des Scan-Ordners
- Scan-Pfad wird in Drift-DB als scanDir gespeichert

### Quick-Action-Buttons
- Vier Actions: Terminal (System-Standard), Finder, GitHub, Notion
- Immer sichtbar auf der Karte (nicht nur bei Hover)
- Nur vorhandene Links anzeigen (kein GitHub-Button wenn kein Remote)
- Darstellungsart und Position: Claude's Discretion (passend zum Karten-Design und Platz)
- Erweiterbar designen — später kommen weitere Actions hinzu
- Terminal.app öffnen (user approved — kein System-Standard, hardcoded Terminal.app)

### Karten-Interaktionen
- Klick auf Karte öffnet Detail-Ansicht mit allen GSD-Daten (volle Beschreibung, alle Phasen, Roadmap-Übersicht, Decisions)
- Detail-Ansicht Typ (expandiert/Panel/Modal): Claude's Discretion — konsistentes Verhalten für ähnliche Aktionen
- Private/Visible Toggle: Auge-Icon auf der Karte + Rechtsklick-Kontextmenü
- Persistent in Drift-DB gespeichert (überlebt App-Neustarts)
- Hinweis-Banner am Ende des Grids: "X Projekte ausgeblendet — Alle zeigen"
- Banner-Klick klappt ausgeblendete Projekte auf (wie in der v1.0 Web-Version, falls UX passt)

### Claude's Discretion
- Hover-Effekt auf Karten (Glow, Anheben, oder beides)
- Quick-Action-Button Darstellung (Icons only vs. Icons+Tooltip vs. Icons+Labels)
- Quick-Action-Button Position auf der Karte
- Quick-Action-Button Feedback (Hover-Highlight, Click-Animation)
- Detail-Ansicht Typ und Animation
- Update-Animationen bei Live-Datenänderung (Flash, smooth Transition, oder keine)

</decisions>

<specifics>
## Specific Ideas

- Versionsnummer aus GSD Milestone-Info extrahieren (z.B. "v1.1")
- Research-Karten sollen sich auf den ersten Blick von Code-Karten unterscheiden — Farbe + Icon als doppeltes Signal
- Banner für ausgeblendete Projekte soll sich aufklappen lassen ähnlich zur v1.0 Next.js Web-Version
- Quick-Actions sollen erweiterbar sein — weitere Buttons (Claude Code, VS Code, etc.) werden in späteren Phasen hinzukommen
- Detail-Ansicht soll alle GSD-Daten zeigen: volle Beschreibung, alle Phasen mit Status, Roadmap-Übersicht, Decisions

</specifics>

<deferred>
## Deferred Ideas

- Claude Code Quick-Action-Button — spätere Phase
- VS Code/Cursor Quick-Action-Button — spätere Phase
- Stale-Indikator — bewusst nicht gewünscht
- Drag & Drop Sortierung — nicht gewünscht
- Konfigurierbares Terminal (iTerm, Warp) — System-Standard reicht vorerst

</deferred>

---

*Phase: 10-card-widgets-quick-actions*
*Context gathered: 2026-02-20*
