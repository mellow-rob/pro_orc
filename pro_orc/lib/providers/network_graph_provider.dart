import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/collaboration_graph.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/providers/claude_tools_provider.dart';
import 'package:pro_orc/providers/projects_provider.dart';

/// Aggregated multi-project collaboration graph for the full network view.
///
/// For every scanned project it combines the project's local `.claude/`
/// agents/skills (via [projectToolsByPathProvider], which caches per-project
/// scans — M3) with the agent names it references (`usedAgents`), then
/// hands the per-project inputs to [MultiCollaborationGraphData.buildAll],
/// which deduplicates shared agents/skills into single bridging nodes (M7
/// AD-2).
///
/// Rebuilds whenever the project list changes; individual project tool scans
/// are cached by the shared scanner, so a change in one project does not force
/// re-reading every other project's `.claude/`.
final networkGraphProvider = FutureProvider<MultiCollaborationGraphData>((
  ref,
) async {
  final projects = await ref.watch(projectsProvider.future);

  final inputs = <ProjectGraphInput>[];
  for (final project in projects) {
    final tools = await ref.watch(
      projectToolsByPathProvider(project.path).future,
    );

    final agentNames = <String>{
      ...tools.agents.map((a) => a.name),
      ...?project.usedAgents,
    }.toList();
    final skillNames = tools.skills.map((s) => s.name).toList();

    inputs.add(
      ProjectGraphInput(
        projectId: project.folderId,
        projectName: project.displayName,
        agentNames: agentNames,
        skillNames: skillNames,
      ),
    );
  }

  return MultiCollaborationGraphData.buildAll(inputs);
});

/// Look-up of a [ProjectModel] by its `folderId`, used by the network view to
/// resolve a tapped project node back to the model so it can open the
/// [ProjectDetailPanel]. Returns null if no project matches.
final projectByFolderIdProvider = Provider.family<ProjectModel?, String>((
  ref,
  folderId,
) {
  final projects = ref.watch(projectsProvider).value ?? const [];
  for (final project in projects) {
    if (project.folderId == folderId) return project;
  }
  return null;
});
