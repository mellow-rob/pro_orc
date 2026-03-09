---
phase: 22
slug: claude-button
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 22 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | flutter_test (built-in) |
| **Config file** | pro_orc/pubspec.yaml (dev_dependencies) |
| **Quick run command** | `flutter test test/data/` |
| **Full suite command** | `flutter test` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `flutter test test/data/`
- **After every plan wave:** Run `flutter test`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 22-01-01 | 01 | 1 | CLB-01 | unit | `flutter test test/data/quick_actions_test.dart` | ❌ W0 | ⬜ pending |
| 22-01-02 | 01 | 1 | CLB-02 | manual | Visual inspection | N/A | ⬜ pending |
| 22-01-03 | 01 | 1 | CLB-03 | manual | Context menu inspection | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/data/quick_actions_test.dart` — test for openClaude() method
- Existing infrastructure covers remaining phase requirements (UI is manual verification)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Claude-Button visually prominent (Cyan, left position) | CLB-02 | Visual design verification | Run app, inspect card layout |
| Terminal access via context menu | CLB-03 | UI interaction verification | Right-click card, verify Terminal option in menu |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
