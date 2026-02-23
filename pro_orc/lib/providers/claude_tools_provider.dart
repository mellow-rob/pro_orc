import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/data/services/claude_tools_scanner.dart';
import 'package:pro_orc/providers/claude_tools_watcher_provider.dart';

/// Live Claude Tools data — rescans on every watcher event.
///
/// Mirrors the projectsProvider pattern exactly:
///   ref.listen watcher → invalidateSelf → ClaudeToolsScanner().scanAll()
final claudeToolsProvider = FutureProvider<ClaudeToolsData>((ref) async {
  // Listen to watcher events — any change in ~/.claude/ invalidates this provider
  ref.listen(claudeToolsWatcherProvider, (previous, next) {
    if (next.hasValue) {
      ref.invalidateSelf();
    }
  });

  return ClaudeToolsScanner().scanAll();
});
