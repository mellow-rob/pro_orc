import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shared/claude_tool_detail/detail_shell.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Detail content for a [PluginData] item.
class PluginDetailContent extends StatelessWidget {
  const PluginDetailContent({super.key, required this.plugin});
  final PluginData plugin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = colors.emerald;

    return DetailShell(
      accent: accent,
      icon: Icons.extension,
      name: plugin.name,
      badge: DetailStatusBadge(
        enabled: plugin.enabled,
        activeColor: colors.emeraldLo,
        colors: colors,
      ),
      children: [
        // Version + Marketplace
        DetailSection(
          colors: colors,
          accent: accent,
          title: 'INFO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plugin.version != null)
                DetailInfoRow(
                  label: 'Version',
                  value: plugin.version!,
                  colors: colors,
                ),
              DetailInfoRow(
                label: 'Marketplace',
                value: plugin.marketplace,
                colors: colors,
              ),
              if (plugin.author != null)
                DetailInfoRow(
                  label: 'Autor',
                  value: plugin.author!,
                  colors: colors,
                ),
              if (plugin.installedAt != null)
                DetailInfoRow(
                  label: 'Installiert',
                  value: formatClaudeToolDate(plugin.installedAt!),
                  colors: colors,
                ),
              if (plugin.lastUpdated != null)
                DetailInfoRow(
                  label: 'Aktualisiert',
                  value: formatClaudeToolDate(plugin.lastUpdated!),
                  colors: colors,
                ),
            ],
          ),
        ),

        // Beschreibung
        if (plugin.description != null)
          DetailSection(
            colors: colors,
            accent: accent,
            title: 'BESCHREIBUNG',
            child: Text(
              plugin.description!,
              style: TextStyle(
                color: colors.textSec,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

        // Aktionen
        const SizedBox(height: 8),
        Row(
          children: [
            if (plugin.marketplaceUrl != null)
              DetailActionChip(
                icon: Icons.store,
                label: 'Marketplace',
                accent: accent,
                colors: colors,
                onTap: () => launchUrl(Uri.parse(plugin.marketplaceUrl!)),
              ),
          ],
        ),
      ],
    );
  }
}
