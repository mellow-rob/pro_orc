import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:watcher/watcher.dart';

import 'package:pro_orc/data/services/watcher_service.dart';

/// File watcher stream for ~/.claude/ — emits debounced WatchEvents.
///
/// keepAlive: never disposed (mirrors watcherProvider locked decision).
/// Watching a single directory, not multi — only ~/.claude/ is relevant.
final claudeToolsWatcherProvider = StreamProvider<WatchEvent>((ref) async* {
  ref.keepAlive();

  final home = Platform.environment['HOME'] ?? '/Users/rob';
  final claudeDir = '$home/.claude';

  final service = WatcherService(claudeDir);
  ref.onDispose(service.dispose);

  // Forward debounced events from the service
  yield* service.events;
});
