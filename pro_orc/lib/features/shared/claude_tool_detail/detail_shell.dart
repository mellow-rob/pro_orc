import 'package:flutter/material.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Date formatting helper (manual, no intl dependency), shared by every
/// claude-tool detail content widget.
String formatClaudeToolDate(DateTime dt) {
  final d = dt.day.toString().padLeft(2, '0');
  final m = dt.month.toString().padLeft(2, '0');
  return '$d.$m.${dt.year}';
}

/// Shared dialog shell (header + scrollable body) for skill/plugin/mcp
/// server/agent detail content.
class DetailShell extends StatelessWidget {
  const DetailShell({
    super.key,
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
                if (badge != null) ...[const SizedBox(width: 10), badge!],
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

/// Reusable section container shared by every claude-tool detail content
/// widget.
class DetailSection extends StatelessWidget {
  const DetailSection({
    super.key,
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

/// Status badge (Aktiv / Inaktiv), used by plugin and MCP server details.
class DetailStatusBadge extends StatelessWidget {
  const DetailStatusBadge({
    super.key,
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

/// Info row (Label: Value), used across skill/plugin/mcp/agent details.
class DetailInfoRow extends StatelessWidget {
  const DetailInfoRow({
    super.key,
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
              style: TextStyle(color: colors.textDim, fontSize: 13),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: colors.textPri, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Action chip (link-style button), used across skill/plugin/mcp/agent
/// details.
class DetailActionChip extends StatelessWidget {
  const DetailActionChip({
    super.key,
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
