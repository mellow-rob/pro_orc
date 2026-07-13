import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/git_data.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/features/shared/detail/section_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Renders the "LINKS" section for [ProjectDetailPanel] — last commit hash
/// plus external link chips (e.g. GitHub).
class LinksSection extends StatelessWidget {
  const LinksSection({
    super.key,
    required this.git,
    required this.colors,
    required this.accent,
    required this.qa,
  });

  final GitData git;
  final AppColors colors;
  final Color accent;
  final QuickActionsService qa;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      colors: colors,
      accent: accent,
      title: 'LINKS',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (git.lastCommitHash != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.gitCommitHorizontal100,
                    color: colors.textDim,
                    size: 14,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    git.lastCommitHash!,
                    style: TextStyle(
                      color: colors.textSec,
                      fontSize: 13,
                      fontFamily: 'monospace',
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _formatDate(git.lastCommitDate),
                    style: TextStyle(color: colors.textDim, fontSize: 12),
                  ),
                ],
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (git.githubUrl != null)
                _LinkChip(
                  icon: LucideIcons.externalLink100,
                  label: 'GitHub',
                  accent: accent,
                  colors: colors,
                  onTap: () => qa.openUrl(git.githubUrl!),
                ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Styled link chip with icon.
class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.icon,
    required this.label,
    required this.accent,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 13),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
