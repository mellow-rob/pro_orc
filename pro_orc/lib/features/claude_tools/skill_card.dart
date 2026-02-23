import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
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

    return SizedBox(
      width: 240,
      child: GlassCard(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Name
              Text(
                skill.name,
                style: TextStyle(
                  color: colors.amber,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
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
                    icon: Icons.folder_open,
                    tooltip: 'In Finder öffnen',
                    color: colors.amberLo,
                    onPressed: () => Process.run(
                      'open',
                      [skill.path],
                      runInShell: true,
                    ),
                  ),

                  // Homepage (only if available)
                  if (skill.homepage != null)
                    _ActionButton(
                      icon: Icons.open_in_browser,
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
