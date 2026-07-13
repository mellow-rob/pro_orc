import 'dart:io';

import 'package:flutter/material.dart';

import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shared/claude_tool_detail/detail_shell.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Detail content for a [McpServerData] item.
class McpServerDetailContent extends StatelessWidget {
  const McpServerDetailContent({super.key, required this.server});
  final McpServerData server;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = colors.violet;

    return DetailShell(
      accent: accent,
      icon: Icons.dns_outlined,
      name: server.name,
      badge: DetailStatusBadge(
        enabled: server.enabled,
        activeColor: colors.violetLo,
        colors: colors,
      ),
      children: [
        // Info
        DetailSection(
          colors: colors,
          accent: accent,
          title: 'INFO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DetailInfoRow(
                label: 'Typ',
                value: server.type.name.toUpperCase(),
                colors: colors,
              ),
              DetailInfoRow(
                label: 'Quelle',
                value: server.source ?? 'Global',
                colors: colors,
              ),
            ],
          ),
        ),

        // Command / URL
        DetailSection(
          colors: colors,
          accent: accent,
          title: server.type == McpServerType.stdio ? 'COMMAND' : 'URL',
          child: Text(
            server.command,
            style: TextStyle(
              color: colors.textSec,
              fontSize: 12,
              fontFamily: 'monospace',
              height: 1.5,
            ),
          ),
        ),

        // Args (if stdio with separate args)
        if (server.args != null && server.args!.isNotEmpty)
          DetailSection(
            colors: colors,
            accent: accent,
            title: 'ARGUMENTE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: server.args!
                  .map(
                    (a) => Padding(
                      padding: const EdgeInsets.only(bottom: 2),
                      child: Text(
                        a,
                        style: TextStyle(
                          color: colors.textSec,
                          fontSize: 12,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          ),

        // Aktionen
        const SizedBox(height: 8),
        Row(
          children: [
            DetailActionChip(
              icon: Icons.settings,
              label: 'settings.json öffnen',
              accent: accent,
              colors: colors,
              onTap: () {
                final home = Platform.environment['HOME']!;
                Process.run('open', [
                  '$home/.claude/settings.json',
                ], runInShell: true);
              },
            ),
            const SizedBox(width: 8),
            DetailActionChip(
              icon: Icons.edit_note,
              label: 'Im Editor öffnen',
              accent: accent,
              colors: colors,
              onTap: () {
                final home = Platform.environment['HOME']!;
                Process.run('open', [
                  '$home/.claude/settings.json',
                ], runInShell: true);
              },
            ),
          ],
        ),
      ],
    );
  }
}
