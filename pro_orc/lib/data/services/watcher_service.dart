import 'dart:async';
import 'dart:developer' as developer;

import 'package:stream_transform/stream_transform.dart';
import 'package:watcher/watcher.dart';

/// A plain Dart service class that wraps [DirectoryWatcher] with a 350ms
/// trailing-edge debounce and defensive error handling.
///
/// Supports watching multiple directories simultaneously. Each directory
/// gets its own [DirectoryWatcher] and events are merged into a single stream.
class WatcherService {
  final List<String> _dirs;
  final List<DirectoryWatcher> _watchers = [];
  late final StreamController<WatchEvent> _controller;
  final List<StreamSubscription<WatchEvent>> _subs = [];

  WatcherService(String singleDir) : _dirs = [singleDir] {
    _init();
  }

  WatcherService.multi(this._dirs) {
    _init();
  }

  void _init() {
    _controller = StreamController<WatchEvent>.broadcast();

    for (final dir in _dirs) {
      final watcher = DirectoryWatcher(dir);
      _watchers.add(watcher);

      final sub = watcher.events.listen(
        (event) {
          if (!_controller.isClosed) {
            _controller.add(event);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          developer.log(
            'Suppressed watcher error: $error',
            name: 'watcher_service',
          );
        },
        onDone: () {
          // Individual watcher done — don't close controller
          // (other watchers may still be active)
        },
        cancelOnError: false,
      );
      _subs.add(sub);
    }
  }

  /// Returns a debounced stream of [WatchEvent]s from all watched directories.
  Stream<WatchEvent> get events {
    return _controller.stream.debounce(const Duration(milliseconds: 350));
  }

  /// Returns true once all underlying watchers are ready.
  bool get isReady => _watchers.every((w) => w.isReady);

  /// Returns a [Future] that completes when all watchers are ready.
  Future<void> get ready => Future.wait(_watchers.map((w) => w.ready));

  /// Disposes all watchers.
  Future<void> dispose() async {
    for (final sub in _subs) {
      await sub.cancel();
    }
    if (!_controller.isClosed) {
      await _controller.close();
    }
  }
}
