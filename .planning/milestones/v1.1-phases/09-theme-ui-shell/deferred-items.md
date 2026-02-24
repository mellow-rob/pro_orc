# Deferred Items — Phase 09: Theme + UI Shell

## Out-of-scope discoveries during 09-01 execution

### launch_dialog.dart: withOpacity deprecation
- **File:** `pro_orc/lib/features/shell/launch_dialog.dart:12`
- **Issue:** `Color(0xFF00E5FF).withOpacity(0.2)` — deprecated, should be `withValues(alpha: 0.2)`
- **Severity:** info (not an error, does not block build)
- **Discovered during:** Task 2 (full lib/ analyze)
- **Reason deferred:** Pre-existing in a file not touched by plan 09-01; out of scope per deviation rules
- **Recommended fix:** Replace with `const Color(0xFF00E5FF).withValues(alpha: 0.2)` in plan 09-02 or 09-03 when launch_dialog.dart is touched
