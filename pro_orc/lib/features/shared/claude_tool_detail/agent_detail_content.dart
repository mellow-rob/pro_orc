import 'dart:io';

import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shared/claude_tool_detail/detail_shell.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Detail content for an [AgentData] item.
class AgentDetailContent extends StatelessWidget {
  const AgentDetailContent({super.key, required this.agent});
  final AgentData agent;

  Color _accentColor(AppColors colors) {
    return switch (agent.color) {
      'green' => colors.emerald,
      'cyan' => colors.cyan,
      'orange' => colors.amber,
      'yellow' => colors.amber,
      'purple' => colors.violet,
      'blue' => colors.cyan,
      _ => colors.cyan,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = _accentColor(colors);

    return DetailShell(
      accent: accent,
      icon: Icons.psychology,
      name: agent.name,
      badge: agent.model != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                agent.model!.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : null,
      children: [
        // Beschreibung
        if (agent.description != null)
          DetailSection(
            colors: colors,
            accent: accent,
            title: 'BESCHREIBUNG',
            child: Text(
              agent.description!,
              style: TextStyle(
                color: colors.textSec,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

        // Tools
        if (agent.tools.isNotEmpty)
          DetailSection(
            colors: colors,
            accent: accent,
            title: 'TOOLS',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: agent.tools
                  .map(
                    (t) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        t,
                        style: TextStyle(color: colors.textPri, fontSize: 12),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

        // Info
        DetailSection(
          colors: colors,
          accent: accent,
          title: 'INFO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailInfoRow(
                label: 'Geltungsbereich',
                value: agent.scope == 'project'
                    ? 'Projekt: ${agent.projectName ?? '-'}'
                    : 'Global',
                colors: colors,
              ),
              if (agent.model != null)
                DetailInfoRow(
                  label: 'Modell',
                  value: agent.model!,
                  colors: colors,
                ),
              DetailInfoRow(label: 'Pfad', value: agent.path, colors: colors),
            ],
          ),
        ),

        // Aktionen
        const SizedBox(height: 8),
        Row(
          children: [
            DetailActionChip(
              icon: Icons.folder_open,
              label: 'Im Finder zeigen',
              accent: accent,
              colors: colors,
              onTap: () =>
                  Process.run('open', ['-R', agent.path], runInShell: true),
            ),
            const SizedBox(width: 8),
            DetailActionChip(
              icon: Icons.edit_note,
              label: 'Datei öffnen',
              accent: accent,
              colors: colors,
              onTap: () => Process.run('open', [agent.path], runInShell: true),
            ),
          ],
        ),
      ],
    );
  }
}
