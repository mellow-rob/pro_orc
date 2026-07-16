---
schema_version: 1
type: roadmap
project: pro-orc
title: "Pro Orc"
status: active
updated: 2026-07-16
source: "scaffolded by a1-tools product init"
milestones:
  - id: m1-stabilization
    title: "Stabilization and window fix (v2.2)"
    status: done
    target: null
  - id: m2-design-refresh
    title: "Light theme design refresh"
    status: done
    target: null
  - id: m3-agentic-os-views
    title: "AgenticOS views"
    status: done
    target: null
  - id: m4-sessions-graph
    title: "Session monitoring and collaboration graph"
    status: done
    target: null
  - id: m5-harness-visibility
    title: "Harness visibility"
    status: done
    target: null
  - id: m6-learning-loop
    title: "Self-learning OS"
    status: done
    target: null
  - id: m7-network-costs
    title: "Rounding out v3"
    status: done
    target: null
  - id: m8-project-organization
    title: "Project organization"
    status: in-progress
    target: null
  - id: m9-detail-roadmap-redesign
    title: "Detail view and roadmap redesign"
    status: done
    target: null
  - id: m10-detail-ui-refinement
    title: "Detail UI refinement (compact, high-level)"
    status: done
    target: null
features:
  - id: 002-project-organization
    milestone: m8-project-organization
    title: "Project Hub: list/grid toggle, custom groups, archive, a1-badge"
    status: done
    stage: done
    depends_on: []
    started: 2026-07-12
    finished: 2026-07-15
    spec_path: projects/pro-orc/spec/002-project-organization.md
    plan_path: projects/pro-orc/plans/002-project-organization-wave-plan.md
  - id: 003-detail-roadmap-redesign
    milestone: m9-detail-roadmap-redesign
    title: "Detail view cleanup + tier-0 product-store roadmap (hero, lanes, cards, structured spec renderer, timeline)"
    status: done
    stage: null
    depends_on: []
    started: null
    finished: null
    spec_path: null
    plan_path: null
  - id: 004-magazine-detail-ui
    milestone: m9-detail-roadmap-redesign
    title: "Magazine-style detail UI: Vision/Roadmap/Zeitstrahl tabs per approved mockup"
    status: done
    stage: done
    depends_on: []
    started: 2026-07-16
    finished: 2026-07-16
    spec_path: null
    plan_path: null
  - id: 005-compact-detail-ui
    milestone: m10-detail-ui-refinement
    title: "Compact detail UI: sans fonts, milestone accordion, vision teaser (mockup v2)"
    status: done
    stage: done
    depends_on: []
    started: 2026-07-16
    finished: 2026-07-16
    spec_path: null
    plan_path: null
  - id: 006-vision-first-tab-consolidation
    milestone: m10-detail-ui-refinement
    title: "Vision-first tab consolidation: merge Übersicht into Vision, product version, links section"
    status: done
    stage: done
    depends_on: []
    started: 2026-07-16
    finished: 2026-07-16
    spec_path: null
    plan_path: null
  - id: 007-links-own-tab
    milestone: m10-detail-ui-refinement
    title: "Links section becomes its own tab (Vision|Roadmap|Zeitstrahl|Links)"
    status: in-flight
    stage: verify
    depends_on: []
    started: 2026-07-16
    finished: null
    spec_path: null
    plan_path: null
next: null
---

# Pro Orc

## Milestones

(none yet — use `product add-milestone`)

## In-flight features

None.

## Changelog

- **2026-07-12** — project initialized — scaffolded by `product init`
- **2026-07-12** — milestone 'm1-stabilization' added — Fix critical bugs and switch window activation policy dynamically.
- **2026-07-12** — milestone 'm2-design-refresh' added — Ship a light glassmorphism theme with a mode switcher.
- **2026-07-12** — milestone 'm3-agentic-os-views' added — Show agents and skills (global and project-local) as first-class tabs.
- **2026-07-12** — milestone 'm4-sessions-graph' added — Show live Claude Code sessions and a mini collaboration graph per project.
- **2026-07-12** — milestone 'm5-harness-visibility' added — Expose hooks, rules, permissions, MCP config, and a skill launcher.
- **2026-07-12** — milestone 'm6-learning-loop' added — Surface a1 retros, patterns, and observations as a Learning tab.
- **2026-07-12** — milestone 'm7-network-costs' added — Full network view, plugin skills, and token cost estimation.
- **2026-07-12** — milestone 'm8-project-organization' added — Grid/list toggle, custom groups, and a1-SpecForge badge for organizing many projects.
- **2026-07-12** — feature '002-project-organization' added — Merge Code/Research tabs into one Projects view, group projects by context, add archive group.
- **2026-07-12** — 002-project-organization -> started — stage transition via `product stage`
- **2026-07-12** — feature.md created for '002-project-organization' — formal spec/plan attached via `product feature-init`
- **2026-07-12** — adopt: migrated legacy .a1/roadmap.md (M1-M8) to docs/product/ROADMAP.md schema v1 — M1-M7 marked done from merged feature branches + merge commits on main (evidence ladder rung b: feature/v2.2-stabilization, feature/v3-m5-harness-visibility, feature/v3-m6-learning-loop, feature/v3-m7-network-costs) plus release tag v3.0.0; M8 carried over as in-progress (no completion evidence yet). Legacy .a1/roadmap.md kept as-is, not deleted.
- **2026-07-13** — 002-project-organization -> complete — stage transition via `product stage`
- **2026-07-13** — 002-project-organization -> merge — stage transition via `product stage`
- **2026-07-13** — 002-project-organization -> origin-cleanup — stage transition via `product stage`
- **2026-07-15** — 002-project-organization -> done — stage transition via `product stage`
- **2026-07-15** — milestone 'm9-detail-roadmap-redesign' added — Non-technical, visual project detail + drill-down roadmap view
- **2026-07-15** — feature '003-detail-roadmap-redesign' added — Non-technical, visual project detail + drill-down roadmap view
- **2026-07-15** — milestone m9-detail-roadmap-redesign status -> done — marker set via `product markers --set`
- **2026-07-15** — feature '004-magazine-detail-ui' added — Implement docs/design/roadmap-redesign-mockup.html 1:1 in Flutter
- **2026-07-15** — milestone m9-detail-roadmap-redesign status -> in-progress — marker set via `product markers --set`
- **2026-07-16** — 004-magazine-detail-ui -> verify — stage transition via `product stage`
- **2026-07-16** — 004-magazine-detail-ui -> done — stage transition via `product stage`
- **2026-07-16** — milestone m9-detail-roadmap-redesign status -> done — marker set via `product markers --set`
- **2026-07-16** — milestone 'm10-detail-ui-refinement' added — Live-feedback iteration on the magazine detail UI: sans typography, compact milestone accordion, vision teaser in overview
- **2026-07-16** — feature '005-compact-detail-ui' added — new feature via `product add-feature`
- **2026-07-16** — 005-compact-detail-ui -> started — stage transition via `product stage`
- **2026-07-16** — 005-compact-detail-ui -> complete — stage transition via `product stage`
- **2026-07-16** — 005-compact-detail-ui -> review — stage transition via `product stage`
- **2026-07-16** — 005-compact-detail-ui -> verify — stage transition via `product stage`
- **2026-07-16** — 005-compact-detail-ui -> merge — stage transition via `product stage`
- **2026-07-16** — 005-compact-detail-ui -> origin-cleanup — stage transition via `product stage`
- **2026-07-16** — 005-compact-detail-ui -> done — stage transition via `product stage`
- **2026-07-16** — milestone m10-detail-ui-refinement status -> done — marker set via `product markers --set`
- **2026-07-16** — feature '006-vision-first-tab-consolidation' added — new feature via `product add-feature`
- **2026-07-16** — 006-vision-first-tab-consolidation -> started — stage transition via `product stage`
- **2026-07-16** — 006-vision-first-tab-consolidation -> complete — stage transition via `product stage`
- **2026-07-16** — 006-vision-first-tab-consolidation -> review — stage transition via `product stage`
- **2026-07-16** — 006-vision-first-tab-consolidation -> verify — stage transition via `product stage`
- **2026-07-16** — 006-vision-first-tab-consolidation -> merge — stage transition via `product stage`
- **2026-07-16** — 006-vision-first-tab-consolidation -> origin-cleanup — stage transition via `product stage`
- **2026-07-16** — 006-vision-first-tab-consolidation -> done — stage transition via `product stage`
- **2026-07-16** — feature '007-links-own-tab' added — new feature via `product add-feature`
- **2026-07-16** — 007-links-own-tab -> started — stage transition via `product stage`
- **2026-07-16** — 007-links-own-tab -> complete — stage transition via `product stage`
- **2026-07-16** — 007-links-own-tab -> review — stage transition via `product stage`
- **2026-07-16** — 007-links-own-tab -> verify — stage transition via `product stage`

## Appendix — migrated details

(none)
