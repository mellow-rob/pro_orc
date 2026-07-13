import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shared/claude_tool_detail/detail_shell.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Detail content for a [SkillData] item.
class SkillDetailContent extends StatelessWidget {
  const SkillDetailContent({super.key, required this.skill});
  final SkillData skill;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = colors.amber;

    return DetailShell(
      accent: accent,
      icon: Icons.auto_fix_high,
      name: skill.name,
      children: [
        // Beschreibung
        if (skill.description != null)
          DetailSection(
            colors: colors,
            accent: accent,
            title: 'BESCHREIBUNG',
            child: Text(
              skill.description!,
              style: TextStyle(
                color: colors.textSec,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

        // Pfad
        DetailSection(
          colors: colors,
          accent: accent,
          title: 'PFAD',
          child: Text(
            skill.path,
            style: TextStyle(
              color: colors.textSec,
              fontSize: 12,
              fontFamily: 'monospace',
            ),
          ),
        ),

        // Homepage
        if (skill.homepage != null)
          DetailSection(
            colors: colors,
            accent: accent,
            title: 'HOMEPAGE',
            child: GestureDetector(
              onTap: () => launchUrl(Uri.parse(skill.homepage!)),
              child: Text(
                skill.homepage!,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: accent.withValues(alpha: 0.4),
                ),
              ),
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
              onTap: () => Process.run('open', [skill.path], runInShell: true),
            ),
            const SizedBox(width: 8),
            DetailActionChip(
              icon: Icons.edit_note,
              label: 'Im Editor öffnen',
              accent: accent,
              colors: colors,
              onTap: () => Process.run('open', [
                '${skill.path}/SKILL.md',
              ], runInShell: true),
            ),
            if (skill.homepage != null) ...[
              const SizedBox(width: 8),
              DetailActionChip(
                icon: Icons.open_in_browser,
                label: 'Homepage',
                accent: accent,
                colors: colors,
                onTap: () => launchUrl(Uri.parse(skill.homepage!)),
              ),
            ],
          ],
        ),
      ],
    );
  }
}
