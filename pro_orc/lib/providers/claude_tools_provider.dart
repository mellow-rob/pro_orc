import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/data/services/claude_tools_scanner.dart';
import 'package:pro_orc/providers/claude_tools_watcher_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';
import 'package:pro_orc/providers/watcher_provider.dart';

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

/// Per-project tools keyed directly by project path — a `family`, independent
/// of the [selectedProjectPathProvider] global-selector state used by the
/// Claude Tools tab's dropdown. Used by the collaboration mini-graph in
/// `ProjectDetailPanel` to show a project's local agents/skills without
/// disturbing the tools-tab's own selection.
final projectToolsByPathProvider =
    FutureProvider.family<ClaudeToolsData, String>((ref, projectPath) async {
      final scanner = ref.watch(_sharedClaudeToolsScannerProvider);
      return scanner.scanProjectTools(projectPath);
    });

/// Reuses a single [ClaudeToolsScanner] instance across [allAgentsProvider]
/// rebuilds so its internal per-project mtime cache (M3 rescan-cost fix)
/// survives watcher-triggered re-scans instead of starting cold every time.
final _sharedClaudeToolsScannerProvider = Provider<ClaudeToolsScanner>((ref) {
  ref.keepAlive();
  return ClaudeToolsScanner();
});

/// Scans every project's local `.claude/` tools (agents + skills + MCP) in
/// one pass, shared by [allAgentsProvider] and [allSkillsProvider] so both
/// tabs don't independently re-scan the same set of projects.
///
/// Rescans on either a `~/.claude/` change or a project-list change (new
/// project imported/removed, or an existing project's files changed).
/// Individual project scans are cached by [ClaudeToolsScanner] itself (M3
/// rescan-cost fix), so a change affecting only one project does not force
/// re-reading every other project's `.claude/`.
final _allProjectToolsProvider = FutureProvider<List<ClaudeToolsData>>((
  ref,
) async {
  ref.listen(claudeToolsWatcherProvider, (previous, next) {
    if (next.hasValue) ref.invalidateSelf();
  });
  ref.listen(watcherProvider, (previous, next) {
    if (next.hasValue) ref.invalidateSelf();
  });

  final scanner = ref.watch(_sharedClaudeToolsScannerProvider);
  final projects = await ref.watch(projectsProvider.future);

  return Future.wait(
    projects.map(
      (p) => scanner.scanProjectTools(p.path, projectName: p.displayName),
    ),
  );
});

/// Combined view of global agents (`~/.claude/agents/`) and project-local
/// agents (`<project>/.claude/agents/` for every scanned project).
final allAgentsProvider = FutureProvider<List<AgentData>>((ref) async {
  final scanner = ref.watch(_sharedClaudeToolsScannerProvider);
  final globalData = await scanner.scanAll();
  final projectData = await ref.watch(_allProjectToolsProvider.future);

  final allAgents = [
    ...globalData.agents,
    for (final data in projectData) ...data.agents,
  ];
  allAgents.sort((a, b) => a.name.compareTo(b.name));
  return allAgents;
});

/// Combined view of global skills (`~/.claude/skills/`) and project-local
/// skills (`<project>/.claude/skills/` for every scanned project).
final allSkillsProvider = FutureProvider<List<SkillData>>((ref) async {
  final scanner = ref.watch(_sharedClaudeToolsScannerProvider);
  final globalData = await scanner.scanAll();
  final projectData = await ref.watch(_allProjectToolsProvider.future);

  final allSkills = [
    ...globalData.skills,
    for (final data in projectData) ...data.skills,
  ];
  allSkills.sort((a, b) => a.name.compareTo(b.name));
  return allSkills;
});
