# Phase 1: Foundation - Context

**Gathered:** 2026-02-17
**Status:** Ready for planning

<domain>
## Phase Boundary

Korrekt konfiguriertes Next.js Projekt mit Tailwind v4, shadcn/ui, Dark Mode CSS Variablen, shared TypeScript Types, und `serverExternalPackages`. Kein Feature-Code — nur die Basis die alle folgenden Phasen trägt.

</domain>

<decisions>
## Implementation Decisions

### Dark Mode Styling
- Design-Referenz: n3urala1.com — ultra-dark Background, semi-transparente Karten, Cyan/Fuchsia Akzente
- Farbpalette: Dark Navy Background, `rgba(255,255,255,0.02-0.05)` für Karten, `border-white/5` für Borders
- Akzentfarben: Cyan (#06b6d4) + Fuchsia (#d946ef) — Einsatz nach Claude's Discretion
- Kartenkontrast: Nach Claude's Discretion — was für ein info-dichtes Dashboard lesbar ist
- Typography: Inter Font mit antialiasing, monospace für Timestamps
- Effekte: Subtle Glow-Shadows auf interaktiven Elementen, smooth Hover-Transitions
- UI/UX Pro Max Skill soll für Design-Implementierung genutzt werden

### TypeScript Types
- Projekt-Varianten: Union Type — `CodeProject | ResearchProject` mit shared Base Interface
- GSD Status: Dynamisch aus STATE.md ableiten (kein festes Enum)
- Fehlende .planning/: Optional Fields (`gsdStatus?: GsdStatus`) — undefined wenn kein .planning/
- Git-Daten: Flach im Projekt-Interface (`lastCommitMessage`, `lastCommitTimestamp` direkt auf Project)

### Projekt-Struktur
- Route-Struktur: Erweiterbar — `/` (Dashboard) + `/tools` + `/api/*` — vorbereitet für spätere Pages
- Dateinamen: camelCase Convention (projectCard.tsx, gitReader.ts)

### shadcn/ui Setup
- Komponenten: Alle benötigten Komponenten komplett installieren (Card, Badge, Button, Progress, Tooltip, Separator etc.)
- Theme: CSS Variablen auf n3urala1 Cyan/Fuchsia/Dark Navy Palette setzen
- Icons: lucide-react in Phase 1 installieren und bereit für spätere Phasen

### Claude's Discretion
- Backend-Module Ordnerstruktur (lib/ vs lib/services/)
- React-Komponenten Organisation (flach vs feature-basiert)
- Cyan/Fuchsia Farb-Zuordnung (Code vs Research, Status vs Highlight)
- Karten-Transparenz Level für optimale Lesbarkeit

</decisions>

<specifics>
## Specific Ideas

- n3urala1.com als visuelle Referenz: ultra-dark mit `bg-white/[0.02]` Glaseffekt-Karten, colored Glow-Borders auf Hover, monospace Timestamps
- "Tracking-tighter" auf großen Headings, `slate-400` für Body Copy, `leading-relaxed` für Lesbarkeit
- Blur-Effekte für atmosphärische Tiefe (`blur-[100px]`) im Hintergrund

</specifics>

<deferred>
## Deferred Ideas

None — Discussion blieb innerhalb des Phase-Scopes

</deferred>

---

*Phase: 01-foundation*
*Context gathered: 2026-02-17*
