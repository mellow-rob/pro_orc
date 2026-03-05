import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:pro_orc/data/models/agent_category.dart';
import 'package:pro_orc/data/models/claude_tool_model.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

// ---------------------------------------------------------------------------
// Public show functions
// ---------------------------------------------------------------------------

/// Opens a detail panel for a [SkillData] item.
Future<void> showSkillDetail(BuildContext context, SkillData skill) =>
    _showClaudeToolDetail(context, _SkillDetailContent(skill: skill));

/// Opens a detail panel for a [PluginData] item.
Future<void> showPluginDetail(BuildContext context, PluginData plugin) =>
    _showClaudeToolDetail(context, _PluginDetailContent(plugin: plugin));

/// Opens a detail panel for a [McpServerData] item.
Future<void> showMcpServerDetail(BuildContext context, McpServerData server) =>
    _showClaudeToolDetail(context, _McpServerDetailContent(server: server));

/// Opens a detail panel for an [AgentData] item.
Future<void> showAgentDetail(BuildContext context, AgentData agent) =>
    _showClaudeToolDetail(context, _AgentDetailContent(agent: agent));

// ---------------------------------------------------------------------------
// Shared dialog launcher
// ---------------------------------------------------------------------------

Future<void> _showClaudeToolDetail(BuildContext context, Widget content) async {
  await showGeneralDialog(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Close',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.05),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
        )),
        child: FadeTransition(opacity: animation, child: child),
      );
    },
    pageBuilder: (context, animation, secondaryAnimation) => content,
  );
}

// ---------------------------------------------------------------------------
// Skill detail
// ---------------------------------------------------------------------------

class _SkillDetailContent extends StatelessWidget {
  const _SkillDetailContent({required this.skill});
  final SkillData skill;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = colors.amber;

    return _DetailShell(
      accent: accent,
      icon: Icons.auto_fix_high,
      name: skill.name,
      children: [
        // Beschreibung
        if (skill.description != null)
          _Section(
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
        _Section(
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
          _Section(
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
            _ActionChip(
              icon: Icons.folder_open,
              label: 'In Finder öffnen',
              accent: accent,
              colors: colors,
              onTap: () => Process.run('open', [skill.path], runInShell: true),
            ),
            if (skill.homepage != null) ...[
              const SizedBox(width: 8),
              _ActionChip(
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

// ---------------------------------------------------------------------------
// Plugin detail
// ---------------------------------------------------------------------------

class _PluginDetailContent extends StatelessWidget {
  const _PluginDetailContent({required this.plugin});
  final PluginData plugin;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = colors.emerald;

    return _DetailShell(
      accent: accent,
      icon: Icons.extension,
      name: plugin.name,
      badge: _StatusBadge(
        enabled: plugin.enabled,
        activeColor: colors.emeraldLo,
        colors: colors,
      ),
      children: [
        // Version + Marketplace
        _Section(
          colors: colors,
          accent: accent,
          title: 'INFO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (plugin.version != null)
                _InfoRow(label: 'Version', value: plugin.version!, colors: colors),
              _InfoRow(label: 'Marketplace', value: plugin.marketplace, colors: colors),
            ],
          ),
        ),

        // Beschreibung
        if (plugin.description != null)
          _Section(
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
              _ActionChip(
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

// ---------------------------------------------------------------------------
// MCP Server detail
// ---------------------------------------------------------------------------

class _McpServerDetailContent extends StatelessWidget {
  const _McpServerDetailContent({required this.server});
  final McpServerData server;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = colors.violet;

    return _DetailShell(
      accent: accent,
      icon: Icons.dns_outlined,
      name: server.name,
      badge: _StatusBadge(
        enabled: server.enabled,
        activeColor: colors.violetLo,
        colors: colors,
      ),
      children: [
        // Info
        _Section(
          colors: colors,
          accent: accent,
          title: 'INFO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Typ',
                value: server.type.name.toUpperCase(),
                colors: colors,
              ),
              _InfoRow(
                label: 'Quelle',
                value: server.source ?? 'Global',
                colors: colors,
              ),
            ],
          ),
        ),

        // Command / URL
        _Section(
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
          _Section(
            colors: colors,
            accent: accent,
            title: 'ARGUMENTE',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: server.args!
                  .map((a) => Padding(
                        padding: const EdgeInsets.only(bottom: 2),
                        child: Text(
                          a,
                          style: TextStyle(
                            color: colors.textSec,
                            fontSize: 12,
                            fontFamily: 'monospace',
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

        // Aktionen
        const SizedBox(height: 8),
        Row(
          children: [
            _ActionChip(
              icon: Icons.settings,
              label: 'settings.json öffnen',
              accent: accent,
              colors: colors,
              onTap: () {
                final home = Platform.environment['HOME'] ?? '/Users/rob';
                Process.run('open', ['$home/.claude/settings.json'],
                    runInShell: true);
              },
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Agent detail
// ---------------------------------------------------------------------------

class _AgentDetailContent extends StatelessWidget {
  const _AgentDetailContent({required this.agent});
  final AgentData agent;

  Color _accentColor(AppColors colors) {
    return switch (agent.color) {
      'green' => colors.emerald,
      'cyan' => colors.cyan,
      'orange' => colors.amber,
      'yellow' => colors.amber,
      'purple' => colors.violet,
      'blue' => colors.cyan,
      _ => colors.cyan,
    };
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final accent = _accentColor(colors);

    return _DetailShell(
      accent: accent,
      icon: Icons.psychology,
      name: agent.name,
      badge: agent.model != null
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: accent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                agent.model!.toUpperCase(),
                style: TextStyle(
                  color: accent,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : null,
      children: [
        // Beschreibung
        if (agent.description != null)
          _Section(
            colors: colors,
            accent: accent,
            title: 'BESCHREIBUNG',
            child: Text(
              agent.description!,
              style: TextStyle(
                color: colors.textSec,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ),

        // Tools
        if (agent.tools.isNotEmpty)
          _Section(
            colors: colors,
            accent: accent,
            title: 'TOOLS',
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: agent.tools
                  .map((t) => Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: accent.withValues(alpha: 0.2),
                          ),
                        ),
                        child: Text(
                          t,
                          style: TextStyle(
                            color: colors.textPri,
                            fontSize: 12,
                          ),
                        ),
                      ))
                  .toList(),
            ),
          ),

        // Info
        _Section(
          colors: colors,
          accent: accent,
          title: 'INFO',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _InfoRow(
                label: 'Kategorie',
                value: agent.category == AgentCategory.gsd ? 'GSD' : 'Allgemein',
                colors: colors,
              ),
              if (agent.model != null)
                _InfoRow(
                  label: 'Modell',
                  value: agent.model!,
                  colors: colors,
                ),
              _InfoRow(label: 'Pfad', value: agent.path, colors: colors),
            ],
          ),
        ),

        // Aktionen
        const SizedBox(height: 8),
        Row(
          children: [
            _ActionChip(
              icon: Icons.folder_open,
              label: 'Datei öffnen',
              accent: accent,
              colors: colors,
              onTap: () =>
                  Process.run('open', [agent.path], runInShell: true),
            ),
          ],
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Shared shell (header + scrollable body)
// ---------------------------------------------------------------------------

class _DetailShell extends StatelessWidget {
  const _DetailShell({
    required this.accent,
    required this.icon,
    required this.name,
    this.badge,
    required this.children,
  });

  final Color accent;
  final IconData icon;
  final String name;
  final Widget? badge;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final screenSize = MediaQuery.of(context).size;

    return Center(
      child: Material(
        type: MaterialType.transparency,
        child: DefaultTextStyle(
          style: TextStyle(
            color: colors.textPri,
            fontSize: 14,
            decoration: TextDecoration.none,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: 560,
              maxHeight: screenSize.height * 0.8,
            ),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(context, colors),
                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: children,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColors colors) {
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 12, 16),
      child: Row(
        children: [
          // Accent left border strip
          Container(
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          // Icon in accent circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: accent, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    name,
                    style: TextStyle(
                      color: colors.textPri,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (badge != null) ...[
                  const SizedBox(width: 10),
                  badge!,
                ],
              ],
            ),
          ),
          SizedBox(
            width: 36,
            height: 36,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 18,
              icon: Icon(Icons.close, color: colors.textDim),
              tooltip: 'Schliessen',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reusable section container
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({
    required this.colors,
    required this.accent,
    required this.title,
    required this.child,
  });

  final AppColors colors;
  final Color accent;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: colors.bgSurf.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            top: BorderSide(color: accent.withValues(alpha: 0.3), width: 1),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Status badge (Aktiv / Inaktiv)
// ---------------------------------------------------------------------------

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.enabled,
    required this.activeColor,
    required this.colors,
  });

  final bool enabled;
  final Color activeColor;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: enabled
            ? activeColor.withValues(alpha: 0.2)
            : colors.textDim.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: enabled ? activeColor : colors.textDim,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            enabled ? 'Aktiv' : 'Inaktiv',
            style: TextStyle(
              color: enabled ? activeColor : colors.textDim,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info row (Label: Value)
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.colors,
  });

  final String label;
  final String value;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(
                color: colors.textDim,
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: colors.textPri,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Action chip (link-style button)
// ---------------------------------------------------------------------------

class _ActionChip extends StatelessWidget {
  const _ActionChip({
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
          color: accent.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 14),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
