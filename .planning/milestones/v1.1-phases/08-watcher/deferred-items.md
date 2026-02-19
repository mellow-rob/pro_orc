# Deferred Items — Phase 08-watcher

## Out of scope pre-existing warnings

These `info` diagnostics exist in files not modified during 08-02. They are pre-existing and out of scope.

- `features/shell/glow_border_shell.dart:15,19,24` — `withOpacity` deprecated, use `.withValues()`
- `features/shell/launch_dialog.dart:12` — `withOpacity` deprecated, use `.withValues()`

**Recommended fix:** Replace `Colors.white.withOpacity(x)` with `Colors.white.withValues(alpha: x)` in both files.
