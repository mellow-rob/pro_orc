import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/features/agents/agent_card.dart';
import 'package:pro_orc/features/shared/claude_tool_detail_panel.dart';
import 'package:pro_orc/features/shared/detail/section_card.dart';
import 'package:pro_orc/providers/claude_tools_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Renders the "AGENTS" section body for [ProjectDetailPanel] — a wrap of
/// clickable agent chips resolved against the global Claude tools inventory.
class AgentsSection extends StatelessWidget {
  const AgentsSection({
    super.key,
    required this.usedAgents,
    required this.colors,
    required this.accent,
  });

  final List<String> usedAgents;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final toolsAsync = ref.read(claudeToolsProvider);
        final allAgents = toolsAsync.value?.agents ?? [];

        return SectionCard(
          colors: colors,
          accent: accent,
          title: 'AGENTS',
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: usedAgents.map((name) {
              final agentData = allAgents
                  .where((a) => a.name == name)
                  .firstOrNull;
              final chipColor = agentData != null
                  ? agentAccentColor(agentData.color, colors)
                  : colors.textSec;

              return GestureDetector(
                onTap: agentData != null
                    ? () => showAgentDetail(context, agentData)
                    : null,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: chipColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: chipColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: chipColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        name,
                        style: TextStyle(
                          color: chipColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        );
      },
    );
  }
}
