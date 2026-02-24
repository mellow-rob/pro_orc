# Phase 9: Theme + UI Shell - Context

**Gathered:** 2026-02-19
**Status:** Ready for planning

<domain>
## Phase Boundary

The app renders the n3urala1 dark theme with correct cyan/fuchsia colors, glassmorphism card backgrounds, atmospheric orbs, and a three-tab navigation bar (Code, Research, Claude Tools). No card content is wired — this phase delivers the visual foundation only.

</domain>

<decisions>
## Implementation Decisions

### Atmospheric orbs & background
- Orbs use **subtle drift animation** — slow, continuous movement across the background like colored fog
- Orb count, placement, size, blur intensity, and base background color are Claude's discretion
- Orb colors (exact cyan/fuchsia values and saturation) are Claude's discretion
- No vignette preference — Claude decides based on overall composition
- Orbs may span the entire window or only the content area — Claude's discretion

### Glassmorphism card style
- **No border/rand on cards** — cards are defined purely through backdrop blur, no 1px glow or outline
- Transparency level, blur amount, and rounded corner radius are Claude's discretion
- Hover effect is Claude's discretion (but the "no border" rule applies — hover should not introduce a border)
- Must avoid white halo artifacts on the dark background

### Tab navigation design
- Three tabs: Code, Research, Claude Tools
- Tab position (top/bottom/sidebar), icon/text style, active indicator, and transition animation are all Claude's discretion
- Claude should choose what works best with the glassmorphism aesthetic

### Color token mapping
- **Text color: leicht gedämpft (~#E0E0E8)** — not pure white, softer on dark background
- **OKLCH-to-sRGB conversion: Claude handles** — convert all n3urala1 OKLCH design tokens to sRGB hex during planning
- Primary vs secondary accent role (cyan/fuchsia hierarchy) is Claude's discretion
- Whether to include additional warn/error colors beyond cyan+fuchsia+grays is Claude's discretion

### Claude's Discretion
- Orb count, placement, size, blur, and color intensity
- Base background color (near-black shade)
- Vignette presence
- Orb scope (full window vs content area only)
- Card transparency, blur amount, corner radius, and hover effect
- Tab bar position, icon/text style, active indicator, and tab transition
- Accent color hierarchy (cyan vs fuchsia as primary)
- Additional semantic colors (warn/error)
- All OKLCH-to-sRGB hex conversions

</decisions>

<specifics>
## Specific Ideas

- n3urala1 is the design system reference — all tokens derive from it
- Pre-existing decision from STATE.md: "All OKLCH design tokens must be pre-converted to sRGB hex before Phase 9 begins (use oklch.com)"
- The user trusts Claude's design judgment heavily — only two firm decisions were made (subtle drift orbs, no card borders, gedämpft text color)

</specifics>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 09-theme-ui-shell*
*Context gathered: 2026-02-19*
