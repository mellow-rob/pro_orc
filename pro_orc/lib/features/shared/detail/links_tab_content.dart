import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/theme/n3_colors.dart';
import 'package:pro_orc/theme/n3_typography.dart';

/// Merges auto-detected [ExternalResource]s (GitHub, Vercel, Figma,
/// Firebase, Claude Memory — from `detectExternalResources()`) with
/// hand-authored [VisionLink]s (`docs/product/VISION.md` `## Links`
/// bullets) into a single deduplicated, uniformly-styled chip list for the
/// Links tab.
///
/// Dedup key: the auto-detected resource's `uri` vs. the manual link's
/// `target`, compared verbatim (both are already-normalized absolute
/// strings — a URL or filesystem path). When both sources produce the same
/// target, the auto-detected entry wins (it carries a `hint`/type the
/// manual entry lacks) and the manual duplicate is dropped.
class LinksTabContent extends StatelessWidget {
  const LinksTabContent({
    super.key,
    required this.resources,
    required this.manualLinks,
    required this.colors,
    required this.qa,
  });

  final List<ExternalResource> resources;
  final List<VisionLink> manualLinks;
  final AppColors colors;
  final QuickActionsService qa;

  /// True when both sources are empty — the caller uses this to decide
  /// whether to show the empty state instead of this widget.
  bool get isEmpty => resources.isEmpty && manualLinks.isEmpty;

  @override
  Widget build(BuildContext context) {
    final seen = resources.map((r) => r.uri).toSet();
    final dedupedManualLinks = manualLinks
        .where((link) => !seen.contains(link.target))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('LINKS', style: N3Typography.eyebrow(colors: colors)),
        const SizedBox(height: 14),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final resource in resources)
              _ResourceChip(resource: resource, colors: colors, qa: qa),
            for (final link in dedupedManualLinks)
              _ManualLinkChip(link: link, colors: colors, qa: qa),
          ],
        ),
      ],
    );
  }
}

IconData _iconFor(ExternalResourceType type) {
  return switch (type) {
    ExternalResourceType.github => LucideIcons.github100,
    ExternalResourceType.vercel => LucideIcons.triangle100,
    ExternalResourceType.figma => LucideIcons.figma100,
    ExternalResourceType.claudeMemory => LucideIcons.brain100,
    ExternalResourceType.other => LucideIcons.externalLink100,
  };
}

class _ResourceChip extends StatelessWidget {
  const _ResourceChip({
    required this.resource,
    required this.colors,
    required this.qa,
  });

  final ExternalResource resource;
  final AppColors colors;
  final QuickActionsService qa;

  bool get _isWebUri =>
      resource.uri.startsWith('http://') || resource.uri.startsWith('https://');

  Future<void> _handleTap(BuildContext context) async {
    if (_isWebUri) {
      await qa.openUrl(resource.uri);
      return;
    }

    final opened = await qa.openLocalPathInFinder(resource.uri);
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Pfad nicht gefunden: ${resource.uri}'),
          duration: const Duration(seconds: 4),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return _LinkChip(
      icon: _iconFor(resource.type),
      label: resource.label,
      colors: colors,
      onTap: () => _handleTap(context),
    );
  }
}

class _ManualLinkChip extends StatelessWidget {
  const _ManualLinkChip({
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
    return _LinkChip(
      icon: link.isWeb ? LucideIcons.externalLink100 : LucideIcons.folder100,
      label: link.title,
      colors: colors,
      onTap: () => _handleTap(context),
    );
  }
}

/// Shared chip visual — same styling `VisionLinksSection`'s `_VisionLinkChip`
/// used, now the single rendering path for both resource kinds.
class _LinkChip extends StatelessWidget {
  const _LinkChip({
    required this.icon,
    required this.label,
    required this.colors,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final AppColors colors;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
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
              Icon(icon, color: colors.cyan, size: 13),
              const SizedBox(width: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 220),
                child: Text(
                  label,
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
