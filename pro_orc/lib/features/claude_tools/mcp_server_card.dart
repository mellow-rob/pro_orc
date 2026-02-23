import 'dart:io';

import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Mini GlassCard for a single MCP server entry.
///
/// Accent color: violet. Shows name, transport type badge, command/URL,
/// and a Config button that opens ~/.claude/settings.json. Width fixed at 240px.
class McpServerCard extends StatelessWidget {
  const McpServerCard({super.key, required this.server});

  final McpServerData server;

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
                server.name,
                style: TextStyle(
                  color: colors.violet,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),

              // Type badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.violetLo.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  server.type.name.toUpperCase(),
                  style: TextStyle(
                    color: colors.violetLo,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                    letterSpacing: 0.5,
                  ),
                ),
              ),
              const SizedBox(height: 4),

              // Command / URL
              Text(
                server.command,
                style: TextStyle(
                  color: colors.textSec,
                  fontSize: 11,
                  fontFamily: 'monospace',
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),

              const SizedBox(height: 8),

              // Action buttons
              Row(
                children: [
                  _McpActionButton(
                    icon: Icons.settings,
                    tooltip: 'settings.json öffnen',
                    color: colors.violetLo,
                    onPressed: () {
                      final home =
                          Platform.environment['HOME'] ?? '/Users/rob';
                      Process.run(
                        'open',
                        ['$home/.claude/settings.json'],
                        runInShell: true,
                      );
                    },
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

class _McpActionButton extends StatelessWidget {
  const _McpActionButton({
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
