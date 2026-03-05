---
phase: 20
slug: folder-import
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-05
---

# Phase 20 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | `package:test` (Dart) |
| **Config file** | None (standard `flutter test`) |
| **Quick run command** | `cd pro_orc && flutter test test/data/` |
| **Full suite command** | `cd pro_orc && flutter test` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `cd pro_orc && flutter test test/data/`
- **After every plan wave:** Run `cd pro_orc && flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 20-01-xx | 01 | 1 | IMP-02 | unit | `flutter test test/data/project_importer_test.dart` | ❌ W0 | ⬜ pending |
| 20-01-xx | 01 | 1 | IMP-03 | unit | `flutter test test/data/project_importer_test.dart` | ❌ W0 | ⬜ pending |
| 20-01-xx | 01 | 1 | IMP-04 | unit | `flutter test test/data/project_importer_test.dart` | ❌ W0 | ⬜ pending |
| 20-01-xx | 01 | 1 | IMP-05 | unit | `flutter test test/data/project_importer_test.dart` | ❌ W0 | ⬜ pending |
| 20-xx-xx | xx | x | IMP-01 | manual-only | N/A | N/A | ⬜ pending |
| 20-xx-xx | xx | x | IMP-06 | manual-only | N/A | N/A | ⬜ pending |
| 20-xx-xx | xx | x | IMP-07 | manual-only | N/A | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/data/project_importer_test.dart` — unit tests for scaffoldProject(), inferProjectType(), scan-dir containment, duplicate detection
- [ ] Extract `inferProjectType()` to be testable outside `ProjectScanner`

*Existing test infrastructure covers framework setup — no new dependencies needed.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Folder picker opens from Add+ menu | IMP-01 | Requires macOS UI interaction | Click Add+ card → "Ordner importieren" → verify native picker opens |
| Import preview dialog shows correct state | IMP-06 | Widget requires full dialog context | Select folder → verify dialog shows type, files, scaffold options |
| Project appears in correct tab after import | IMP-07 | Requires full provider + watcher stack | Complete import → verify project card appears without restart |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
