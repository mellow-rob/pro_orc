import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/data/models/harness_data.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/harness_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Harness tab — read-only view of the Claude Code harness that governs every
/// session: hooks, rules, permissions and MCP servers. Shows each entry with
/// an origin badge (Global / Projekt / Local); nothing is merged (AD-2).
///
/// Accent color: violet. The app never writes any of this config.
class HarnessTab extends ConsumerWidget {
  const HarnessTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    // Global-only view (empty project path). Project overlays are surfaced in
    // the per-project detail panel, not this global tab.
    final async = ref.watch(harnessProvider(''));

    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: colors.violet)),
      error: (_, _) => Center(
        child: Text(
          'Harness-Konfiguration nicht lesbar',
          style: TextStyle(color: colors.textSec),
        ),
      ),
      data: (data) => _buildContent(colors, data),
    );
  }

  Widget _buildContent(AppColors colors, HarnessData data) {
    if (data.isEmpty) {
      return Center(
        child: Text(
          'Keine Harness-Konfiguration gefunden.\n'
          'Erwartet unter ~/.claude/settings.json und ~/.claude/rules/.',
          textAlign: TextAlign.center,
          style: TextStyle(color: colors.textSec, fontSize: 14),
        ),
      );
    }

    final accent = colors.violet;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HarnessSection(
            colors: colors,
            accent: accent,
            icon: LucideIcons.webhook100,
            title: 'Hooks',
            count: data.hooks.length,
            emptyText: 'Keine Hooks konfiguriert',
            revealPath: data.sources.globalSettingsPath,
            children: [
              for (final h in data.hooks)
                _HarnessRow(
                  colors: colors,
                  level: h.level,
                  primary: h.matcher.isEmpty
                      ? h.event
                      : '${h.event} · ${h.matcher}',
                  secondary: h.command,
                ),
            ],
          ),
          const SizedBox(height: 24),
          _HarnessSection(
            colors: colors,
            accent: accent,
            icon: LucideIcons.fileText100,
            title: 'Rules',
            count: data.rules.length,
            emptyText: 'Keine Rules-Dateien gefunden',
            revealPath: data.sources.rulesRootPath,
            children: [
              for (final r in data.rules)
                _HarnessRow(
                  colors: colors,
                  primary: r.title,
                  secondary: r.relativePath,
                  onReveal: () => _revealInFinder(r.absolutePath),
                ),
            ],
          ),
          const SizedBox(height: 24),
          _HarnessSection(
            colors: colors,
            accent: accent,
            icon: LucideIcons.shield100,
            title: 'Permissions',
            count: data.permissions.length,
            emptyText: 'Keine Permission-Regeln',
            revealPath: data.sources.globalSettingsPath,
            children: [
              for (final perm in data.permissions)
                _HarnessRow(
                  colors: colors,
                  level: perm.level,
                  primary: perm.rule,
                  secondary: perm.kind,
                ),
            ],
          ),
          const SizedBox(height: 24),
          _HarnessSection(
            colors: colors,
            accent: accent,
            icon: LucideIcons.plug100,
            title: 'MCP-Server',
            count: data.mcpServers.length,
            emptyText: 'Keine MCP-Server',
            revealPath: data.sources.globalSettingsPath,
            children: [
              for (final m in data.mcpServers)
                _HarnessRow(
                  colors: colors,
                  level: m.level,
                  primary: m.name,
                  secondary: m.detail,
                ),
            ],
          ),
        ],
      ),
    );
  }

  static void _revealInFinder(String path) {
    // `open -R` reveals a file in Finder. runInShell per project convention.
    Process.run('open', ['-R', path], runInShell: true);
  }
}

class _HarnessSection extends StatelessWidget {
  const _HarnessSection({
    required this.colors,
    required this.accent,
    required this.icon,
    required this.title,
    required this.count,
    required this.emptyText,
    required this.children,
    this.revealPath,
  });

  final AppColors colors;
  final Color accent;
  final IconData icon;
  final String title;
  final int count;
  final String emptyText;
  final List<Widget> children;
  final String? revealPath;

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: accent, size: 18),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  '($count)',
                  style: TextStyle(color: colors.textSec, fontSize: 13),
                ),
                const Spacer(),
                if (revealPath != null)
                  _RevealButton(
                    colors: colors,
                    accent: accent,
                    onTap: () => HarnessTab._revealInFinder(revealPath!),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (children.isEmpty)
              Text(
                emptyText,
                style: TextStyle(color: colors.textDim, fontSize: 13),
              )
            else
              for (int i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1)
                  Divider(
                    height: 1,
                    color: colors.bgElev.withValues(alpha: 0.8),
                  ),
              ],
          ],
        ),
      ),
    );
  }
}

/// A single harness entry: optional level badge, primary text, secondary
/// (mono) detail, and an optional per-row "Im Finder zeigen".
class _HarnessRow extends StatelessWidget {
  const _HarnessRow({
    required this.colors,
    required this.primary,
    required this.secondary,
    this.level,
    this.onReveal,
  });

  final AppColors colors;
  final String primary;
  final String secondary;
  final HarnessLevel? level;
  final VoidCallback? onReveal;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (level != null) ...[
            _LevelBadge(colors: colors, level: level!),
            const SizedBox(width: 10),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  primary,
                  style: TextStyle(color: colors.textPri, fontSize: 13),
                ),
                if (secondary.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    secondary,
                    style: TextStyle(
                      color: colors.textDim,
                      fontSize: 11,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onReveal != null)
            _RevealButton(
              colors: colors,
              accent: colors.violet,
              onTap: onReveal!,
            ),
        ],
      ),
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.colors, required this.level});

  final AppColors colors;
  final HarnessLevel level;

  @override
  Widget build(BuildContext context) {
    // Distinct hue per level for quick scanning; readable in both themes.
    final color = switch (level) {
      HarnessLevel.global => colors.cyan,
      HarnessLevel.project => colors.violet,
      HarnessLevel.local => colors.amber,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        level.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RevealButton extends StatelessWidget {
  const _RevealButton({
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final AppColors colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: 'Im Finder zeigen',
          child: Icon(
            LucideIcons.folderOpen100,
            color: colors.textDim,
            size: 15,
          ),
        ),
      ),
    );
  }
}
