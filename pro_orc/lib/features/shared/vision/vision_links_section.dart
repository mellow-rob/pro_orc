import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:pro_orc/theme/n3_typography.dart';

/// Renders `VisionData.links` (FR-004) as a compact clickable chip row at
/// the end of the Vision tab (FR-005). Web links (`isWeb == true`) open the
/// system default browser; local links open Finder at that path, showing a
/// graceful failure indicator (not a crash, not a silent no-op) if the path
/// no longer exists on disk. Renders nothing at all — no header chrome —
/// when [links] is empty.
class VisionLinksSection extends StatelessWidget {
  const VisionLinksSection({
    super.key,
    required this.links,
    required this.colors,
    required this.qa,
  });

  final List<VisionLink> links;
  final AppColors colors;
  final QuickActionsService qa;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LINKS', style: N3Typography.eyebrow(colors: colors)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final link in links)
              _VisionLinkChip(link: link, colors: colors, qa: qa),
          ],
        ),
      ],
    );
  }
}

class _VisionLinkChip extends StatelessWidget {
  const _VisionLinkChip({
    required this.link,
    required this.colors,
    required this.qa,
  });

  final VisionLink link;
  final AppColors colors;
  final QuickActionsService qa;

  Future<void> _handleTap(BuildContext context) async {
    if (link.isWeb) {
      await qa.openUrl(link.target);
      return;
    }

    final opened = await qa.openLocalPathInFinder(link.target);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pfad nicht gefunden: ${link.target}'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: () => _handleTap(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: colors.cyan.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: colors.cyan.withValues(alpha: 0.15),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                link.isWeb
                    ? LucideIcons.externalLink100
                    : LucideIcons.folder100,
                color: colors.cyan,
                size: 13,
              ),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  link.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors.cyan,
                    fontSize: 12,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
