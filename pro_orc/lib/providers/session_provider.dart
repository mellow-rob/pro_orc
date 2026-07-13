import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/session_data.dart';
import 'package:pro_orc/data/services/session_reader.dart';
import 'package:pro_orc/providers/watcher_provider.dart';

/// Shared [SessionReader] instance — stateless, but kept as a single
/// provider so all session lookups go through one place.
final _sessionReaderProvider = Provider<SessionReader>(
  (ref) => const SessionReader(),
);

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
final sessionDetailProvider = FutureProvider.family<SessionInfo, SessionInfo>((
  ref,
  session,
) async {
  final reader = ref.watch(_sessionReaderProvider);
  return reader.readSessionDetail(session);
});

/// Estimated total token usage (AD-4) summed across the recent sessions shown
/// for a project. Detail-parses only the displayed `recentFive` sessions (not
/// the whole history), matching AD-4's "lazy per detail + per-project sum"
/// rule. Returns null when none of those sessions carry a usage estimate, so
/// the UI can hide the summary rather than show a misleading 0.
///
/// Keyed by project path; reuses [projectSessionsProvider] for the cheap list
/// and [sessionDetailProvider]'s reader for the per-session parse.
final projectTokenEstimateProvider = FutureProvider.family<int?, String>((
  ref,
  projectPath,
) async {
  final sessionData = await ref.watch(
    projectSessionsProvider(projectPath).future,
  );
  final recent = sessionData.recentFive;
  if (recent.isEmpty) return null;

  final reader = ref.watch(_sessionReaderProvider);
  final details = await Future.wait(recent.map(reader.readSessionDetail));

  final withEstimate = details.where((s) => s.hasTokenEstimate);
  if (withEstimate.isEmpty) return null;
  return withEstimate.fold<int>(0, (sum, s) => sum + s.totalTokens);
});
