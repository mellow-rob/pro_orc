import 'dart:io';

import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shared/claude_tool_detail_panel.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Mini GlassCard for a single Claude skill.
///
/// Accent color: amber. Shows name, description, and action buttons
/// (Finder, Homepage). Width fixed at 240px via SizedBox.
class SkillCard extends StatelessWidget {
  const SkillCard({super.key, required this.skill});

  final SkillData skill;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: () => showSkillDetail(context, skill),
      child: SizedBox(
      width: 240,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name + optional Plugin-Badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      skill.name,
                      style: TextStyle(
                        color: colors.amber,
                        fontWeight: FontWeight.w500,
                        fontSize: 13,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (skill.scope == 'plugin') ...[
                    const SizedBox(width: 6),
                    _ScopeBadge(
                      label: skill.pluginName ?? 'Plugin',
                      colors: colors,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),

              // Description
              if (skill.description != null)
                Text(
                  skill.description!,
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

              // Action buttons
              Row(
                children: [
                  // Finder
                  _ActionButton(
                    icon: LucideIcons.folder100,
                    tooltip: 'In Finder öffnen',
                    color: colors.amberLo,
                    onPressed: () => Process.run(
                      'open',
                      [skill.path],
                      runInShell: true,
                    ),
                  ),

                  // Im Editor oeffnen
                  _ActionButton(
                    icon: LucideIcons.filePenLine100,
                    tooltip: 'Im Editor öffnen',
                    color: colors.amberLo,
                    onPressed: () {
                      final skillMdPath = '${skill.path}/SKILL.md';
                      Process.run('open', [skillMdPath], runInShell: true);
                    },
                  ),

                  // Homepage (only if available)
                  if (skill.homepage != null)
                    _ActionButton(
                      icon: LucideIcons.globe100,
                      tooltip: 'Homepage',
                      color: colors.amberLo,
                      onPressed: () =>
                          launchUrl(Uri.parse(skill.homepage!)),
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

/// Small pill labelling a plugin-bundled skill with its owning plugin's name.
class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: colors.violet.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: colors.violet,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Reusable compact icon button for card action rows.
class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 28,
      height: 28,
      child: IconButton(
        padding: EdgeInsets.zero,
        iconSize: 16,
        icon: Icon(icon, color: color),
        tooltip: tooltip,
        onPressed: onPressed,
      ),
    );
  }
}
