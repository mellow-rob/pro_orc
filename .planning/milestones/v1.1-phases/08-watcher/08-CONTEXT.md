# Phase 8: Reactive State - Context

**Gathered:** 2026-02-19
**Status:** Ready for planning

<domain>
## Phase Boundary

Riverpod providers + file watcher wired end-to-end. Editing any `.planning/` file causes in-memory project data to update within one second without restarting the app. The full watcher-to-provider-to-UI invalidation chain works.

</domain>

<decisions>
## Implementation Decisions

### Watcher-Verhalten
- Neue Projektverzeichnisse unter ~/project_orchestration/ werden live erkannt — neues Verzeichnis = neues Projekt erscheint automatisch
- Alle Event-Typen werden verarbeitet: modify, create, delete — nicht nur modify
- Watch-Scope und Start-Timing: Claude's Discretion (basierend auf Requirements und Ressourcen-Trade-offs)

### Debounce & Batching
- Debounce-Wert und Konfigurierbarkeit: Claude's Discretion
- Pro-Projekt vs. globaler Batch: Claude's Discretion
- Leading vs. trailing edge: Claude's Discretion
- Visuelles Update-Signal: Ja — subtile Animation oder Highlight wenn eine Card sich aktualisiert (kein stilles Update)

### Fehler & Edge Cases
- Ungültige/korrupte STATE.md: Fehlerstatus in der Card anzeigen (nicht alte Daten still behalten)
- Gelöschtes Projektverzeichnis: Card sofort aus der Ansicht entfernen
- Watcher-Fehler (Berechtigungen, unerreichbare Verzeichnisse): Dezentes UI-Signal, z.B. kleines Icon in der Statusleiste
- dart-lang/watcher#79 (isDirectory assertion crash): Explizit absichern mit defensivem Code, egal ob in aktueller Version gefixt oder nicht

### Claude's Discretion
- Watch-Scope (nur .planning/ vs. breiter) — basierend auf Requirements LIVE-01, LIVE-02, LIVE-03
- Watcher Start-Timing (sofort vs. bei Fenster-Öffnung) — basierend auf Ressourcen-Trade-offs
- Debounce-Wert fest vs. konfigurierbar
- Pro-Projekt-Debounce vs. globaler Batch
- Leading/trailing edge Trigger-Strategie
- Provider-Architektur (keepAlive-Strategie, Invalidierungs-Granularität)

</decisions>

<specifics>
## Specific Ideas

- Update-Animation soll subtil sein — kein Flackern, eher kurzes Highlight/Glow passend zum n3urala1 Theme
- Bereits entschieden (STATE.md): `watcherProvider` uses `ref.keepAlive()` — never disposed; `projectsProvider` invalidates on watcher events

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-watcher*
*Context gathered: 2026-02-19*
