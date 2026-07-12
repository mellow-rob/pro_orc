import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shared/claude_tool_detail_panel.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Maps an agent's `color` string to the matching [AppColors] accent.
Color agentAccentColor(String colorName, AppColors colors) {
  return switch (colorName) {
    'green' => colors.emerald,
    'cyan' => colors.cyan,
    'orange' => colors.amber,
    'yellow' => colors.amber,
    'purple' => colors.violet,
    'blue' => colors.cyan,
    _ => colors.cyan,
  };
}

/// Mini GlassCard for a single Claude agent.
///
/// Shows name in agent color, optional model badge, description, and tool chips.
/// Width fixed at 240px to match other card types.
class AgentCard extends StatelessWidget {
  const AgentCard({super.key, required this.agent});

  final AgentData agent;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = agentAccentColor(agent.color, colors);

    return GestureDetector(
      onTap: () => showAgentDetail(context, agent),
      child: SizedBox(
        width: 240,
        child: GlassCard(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Name + model badge
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        agent.name,
                        style: TextStyle(
                          color: accent,
                          fontWeight: FontWeight.w500,
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (agent.model != null)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          agent.model!.toUpperCase(),
                          style: TextStyle(
                            color: accent,
                            fontSize: 9,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),

                // Scope badge (Global / project name)
                _ScopeBadge(agent: agent, colors: colors),
                const SizedBox(height: 4),

                // Description
                if (agent.description != null)
                  Text(
                    agent.description!,
                    style: TextStyle(color: colors.textSec, fontSize: 12),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  )
                else
                  Text(
                    'Keine Beschreibung',
                    style: TextStyle(
                      color: colors.textDim,
                      fontSize: 12,
                      fontStyle: FontStyle.italic,
                    ),
                  ),

                const SizedBox(height: 8),

                // Tool chips (first 4)
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: [
                    for (final tool in agent.tools.take(4))
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.bgElev,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          tool,
                          style: TextStyle(color: colors.textDim, fontSize: 10),
                        ),
                      ),
                    if (agent.tools.length > 4)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: colors.bgElev,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          '+${agent.tools.length - 4}',
                          style: TextStyle(color: colors.textDim, fontSize: 10),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Small pill showing "Global" or the owning project's display name.
class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.agent, required this.colors});

  final AgentData agent;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final isProject = agent.scope == 'project';
    final label = isProject ? (agent.projectName ?? 'Projekt') : 'Global';
    final color = isProject ? colors.violet : colors.textDim;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
