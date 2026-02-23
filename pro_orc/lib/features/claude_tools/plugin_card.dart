import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shared/claude_tool_detail_panel.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Mini GlassCard for a single Claude plugin.
///
/// Accent color: emerald. Shows name, version, enabled status,
/// description, and optional Marketplace link button. Width fixed at 240px.
class PluginCard extends StatelessWidget {
  const PluginCard({super.key, required this.plugin});

  final PluginData plugin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;

    return GestureDetector(
      onTap: () => showPluginDetail(context, plugin),
      child: SizedBox(
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
                plugin.name,
                style: TextStyle(
                  color: colors.emerald,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Version + enabled status row
              Row(
                children: [
                  if (plugin.version != null) ...[
                    Text(
                      plugin.version!,
                      style: TextStyle(color: colors.textDim, fontSize: 11),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: plugin.enabled
                          ? colors.emeraldLo.withValues(alpha: 0.2)
                          : colors.textDim.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      plugin.enabled ? 'Aktiv' : 'Inaktiv',
                      style: TextStyle(
                        color: plugin.enabled ? colors.emeraldLo : colors.textDim,
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),

              // Description (if available)
              if (plugin.description != null) ...[
                const SizedBox(height: 4),
                Text(
                  plugin.description!,
                  style: TextStyle(color: colors.textSec, fontSize: 12),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              const SizedBox(height: 8),

              // Action buttons
              Row(
                children: [
                  if (plugin.marketplaceUrl != null)
                    _PluginActionButton(
                      icon: LucideIcons.store100,
                      tooltip: 'Marketplace',
                      color: colors.emeraldLo,
                      onPressed: () =>
                          launchUrl(Uri.parse(plugin.marketplaceUrl!)),
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

class _PluginActionButton extends StatelessWidget {
  const _PluginActionButton({
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
