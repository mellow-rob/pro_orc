import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/harness_data.dart';
import 'package:pro_orc/data/services/harness_reader.dart';
import 'package:pro_orc/providers/watcher_provider.dart';

/// Shared [HarnessReader] instance — stateless, single entry point.
final _harnessReaderProvider = Provider<HarnessReader>((ref) => HarnessReader());

/// Read-only harness configuration (hooks, permissions, env, rules, MCP) for
/// the global level plus an optional project overlay, keyed by project path.
/// Pass an empty string for the global-only view.
///
/// Rescans on `~/.claude` changes (via [watcherProvider], which already
/// watches that tree). Follows the same stateless FutureProvider +
/// ref.listen-invalidation pattern as [projectSessionsProvider].
final harnessProvider =
    FutureProvider.family<HarnessData, String>((ref, projectPath) async {
  ref.listen(watcherProvider, (previous, next) {
    if (next.hasValue) ref.invalidateSelf();
  });

  final reader = ref.watch(_harnessReaderProvider);
  return reader.read(projectPath.isEmpty ? null : projectPath);
});
