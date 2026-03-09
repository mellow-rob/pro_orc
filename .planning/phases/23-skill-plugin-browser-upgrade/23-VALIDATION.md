---
phase: 23
slug: skill-plugin-browser-upgrade
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-09
---

# Phase 23 — Validation Strategy

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
| 23-01-01 | 01 | 1 | SPB-03 | unit | `flutter test test/data/claude_tools_scanner_test.dart` | ❌ W0 | ⬜ pending |
| 23-01-02 | 01 | 1 | SPB-01 | unit | `flutter test test/data/` | ❌ W0 | ⬜ pending |
| 23-02-01 | 02 | 2 | SPB-01 | manual | Visual inspection — per-project filter in Claude Tools tab | N/A | ⬜ pending |
| 23-02-02 | 02 | 2 | SPB-02 | manual | Click "open in editor" action, verify file opens | N/A | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/data/claude_tools_scanner_test.dart` — test for metadata parsing (author, dates)
- Existing infrastructure covers remaining requirements (UI is manual verification)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Per-project skill/plugin display | SPB-01 | UI layout verification | Open Claude Tools tab, select project, verify tools shown |
| Open skill/plugin in editor | SPB-02 | External app launch | Click "open" action, verify editor opens with correct file |
| Metadata display (author, dates) | SPB-03 | Visual correctness | Inspect card, verify author name and dates are formatted |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
