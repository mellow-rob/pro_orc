import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/collaboration_graph.dart';
import 'package:pro_orc/features/shared/collaboration_mini_graph.dart';
import 'package:pro_orc/features/shared/detail/section_card.dart';
import 'package:pro_orc/providers/claude_tools_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Renders the "ZUSAMMENARBEIT" section for [ProjectDetailPanel] — a mini
/// collaboration graph of the project plus its local agents/skills. Renders
/// nothing while loading, on error, or when the resulting graph is empty.
class CollaborationGraphSection extends ConsumerWidget {
  const CollaborationGraphSection({
    super.key,
    required this.projectFolderId,
    required this.projectDisplayName,
    required this.projectPath,
    required this.usedAgents,
    required this.colors,
    required this.accent,
  });

  final String projectFolderId;
  final String projectDisplayName;
  final String projectPath;
  final List<String> usedAgents;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final toolsAsync = ref.watch(projectToolsByPathProvider(projectPath));

    return toolsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (tools) {
        final graphData = CollaborationGraphData.build(
          projectId: projectFolderId,
          projectName: projectDisplayName,
          localAgentNames: tools.agents.map((a) => a.name).toList(),
          localSkillNames: tools.skills.map((s) => s.name).toList(),
          usedAgentNames: usedAgents,
        );

        if (graphData.isEmpty) return const SizedBox.shrink();

        return SectionCard(
          colors: colors,
          accent: accent,
          title: 'ZUSAMMENARBEIT',
          child: CollaborationMiniGraph(data: graphData, colors: colors),
        );
      },
    );
  }
}
