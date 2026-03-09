import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/data/services/claude_tools_scanner.dart';
import 'package:pro_orc/providers/claude_tools_watcher_provider.dart';

/// Currently selected project path for per-project tool filtering.
/// `null` = global view (default), `String` = project path.
class SelectedProjectPathNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? path) => state = path;
}

final selectedProjectPathProvider =
    NotifierProvider<SelectedProjectPathNotifier, String?>(
  SelectedProjectPathNotifier.new,
);

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

/// Per-project tools — scans project-specific skills and MCP servers.
/// Returns `null` when no project is selected (global view).
final projectToolsProvider = FutureProvider<ClaudeToolsData?>((ref) async {
  final projectPath = ref.watch(selectedProjectPathProvider);
  if (projectPath == null) return null;
  return ClaudeToolsScanner().scanProjectTools(projectPath);
});
