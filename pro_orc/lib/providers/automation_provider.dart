import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/automation_data.dart';
import 'package:pro_orc/data/services/automation_reader.dart';
import 'package:pro_orc/providers/harness_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';

/// Read-only discovered automations (launchd agents + crontab + harness hooks)
/// that reference Claude. Best-effort per AD-3 — an empty result is an honest
/// "keine gefunden", not an error.
///
/// Hooks are read from the global [harnessProvider] so they are not parsed
/// twice. Rescans on `~/.claude` changes via [watcherProvider].
final automationProvider = FutureProvider<AutomationData>((ref) async {
  ref.listen(watcherProvider, (previous, next) {
    if (next.hasValue) ref.invalidateSelf();
  });

  final harness = await ref.watch(harnessProvider('').future);
  final reader = AutomationReader();
  return reader.read(hooks: harness.hooks);
});
