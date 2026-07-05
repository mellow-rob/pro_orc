import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/session_data.dart';
import 'package:pro_orc/data/services/session_reader.dart';
import 'package:pro_orc/providers/watcher_provider.dart';

/// Shared [SessionReader] instance — stateless, but kept as a single
/// provider so all session lookups go through one place.
final _sessionReaderProvider = Provider<SessionReader>((ref) => const SessionReader());

/// Cheap (stat-only, no JSONL parsing) session metadata for a single
/// project, keyed by project path.
///
/// Rescans on `~/.claude/projects` changes (via [watcherProvider], which
/// already watches that directory). Kept as its own family provider rather
/// than folded into [ProjectModel]/`ProjectScanner.scanAll` so that scanning
/// all projects does not pay the cost of a session lookup for every single
/// one on every watcher event — cards only request it for the project they
/// are actually displaying.
final projectSessionsProvider =
    FutureProvider.family<ProjectSessionData, String>((ref, projectPath) async {
  ref.listen(watcherProvider, (previous, next) {
    if (next.hasValue) ref.invalidateSelf();
  });

  final reader = ref.watch(_sessionReaderProvider);
  return reader.readProjectSessions(projectPath);
});

/// Lazily parsed detail (message count, start time) for a single session.
/// Only fetched when a session's detail is actually shown (e.g. an expanded
/// row in the project detail panel), keeping the cheap card-level indicator
/// free of JSONL parsing cost.
final sessionDetailProvider =
    FutureProvider.family<SessionInfo, SessionInfo>((ref, session) async {
  final reader = ref.watch(_sessionReaderProvider);
  return reader.readSessionDetail(session);
});
