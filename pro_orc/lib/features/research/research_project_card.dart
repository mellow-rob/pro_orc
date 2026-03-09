import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/shared/memory_indicator.dart';
import 'package:pro_orc/features/shared/project_context_menu.dart';
import 'package:pro_orc/features/shared/quick_actions.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Card widget for a single research project.
///
/// Renders: name + description with fuchsia accent.
/// No progress bar, no status badge, no next step, no version (locked decision).
///
/// Hover adds a subtle fuchsia glow. Right-click shows Ausblenden/Einblenden
/// context menu (locked decision). Eye icon in title row does the same toggle.
class ResearchProjectCard extends ConsumerStatefulWidget {
  const ResearchProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.isHiddenCard = false,
  });

  final ProjectModel project;

  /// Optional tap callback — opens project detail panel.
  final VoidCallback? onTap;

  /// When true, the card is rendered with reduced opacity to indicate it's hidden.
  final bool isHiddenCard;

  @override
  ConsumerState<ResearchProjectCard> createState() =>
      _ResearchProjectCardState();
}

class _ResearchProjectCardState extends ConsumerState<ResearchProjectCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final hiddenSet = ref.watch(hiddenProjectsProvider);
    final isHidden = hiddenSet.contains(widget.project.folderId);

    return Opacity(
      opacity: widget.isHiddenCard ? 0.45 : 1.0,
      child: GestureDetector(
        onTap: widget.onTap,
        onSecondaryTapUp: (details) => showProjectContextMenu(
          context: context,
          details: details,
          isHidden: isHidden,
          ref: ref,
          project: widget.project,
          moveTarget: ProjectType.code,
        ),
        child: MouseRegion(
          onEnter: (_) => setState(() => _isHovered = true),
          onExit: (_) => setState(() => _isHovered = false),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              boxShadow: _isHovered
                  ? [
                      BoxShadow(
                        color: colors.fuch.withValues(alpha: 0.15),
                        blurRadius: 16,
                        spreadRadius: 2,
                      ),
                    ]
                  : [],
            ),
            child: GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _buildContent(context, colors, isHidden),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, AppColors colors, bool isHidden) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Title row ---
        _buildTitleRow(colors, isHidden),
        const SizedBox(height: 12),

        // --- Description (more prominent — no progress bar or next step to compete) ---
        if (widget.project.description != null) ...[
          Text(
            widget.project.description!,
            style: TextStyle(color: colors.textSec, fontSize: 13),
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],

        // --- Memory indicator (below description) ---
        const SizedBox(height: 6),
        MemoryIndicator(
          memory: widget.project.memory,
          colors: colors,
          onTap: () => ref.read(quickActionsProvider).openRemSleep(widget.project.path),
        ),

        const Spacer(),

        // --- Claude button (primary action) ---
        _buildClaudeButton(colors),
        const SizedBox(height: 8),

        // --- Quick action buttons (secondary) ---
        buildQuickActionRow(
          buildProjectQuickActions(widget.project, ref.read(quickActionsProvider)),
          colors,
        ),
      ],
    );
  }

  Widget _buildClaudeButton(AppColors colors) {
    return SizedBox(
      height: 32,
      child: TextButton.icon(
        onPressed: () => ref.read(quickActionsProvider).openClaude(widget.project.path),
        icon: Icon(LucideIcons.sparkles100, size: 16, color: colors.cyan),
        label: Text(
          'Claude',
          style: TextStyle(
            color: colors.cyan,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        style: TextButton.styleFrom(
          backgroundColor: colors.cyan.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 0),
        ),
      ),
    );
  }

  Widget _buildTitleRow(AppColors colors, bool isHidden) {
    return Row(
      children: [
        Icon(LucideIcons.beaker100, color: colors.fuch, size: 15),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            widget.project.displayName,
            style: TextStyle(
              color: colors.textPri,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        // Eye icon for hide/show toggle
        SizedBox(
          width: 28,
          height: 28,
          child: IconButton(
            padding: EdgeInsets.zero,
            iconSize: 16,
            icon: Icon(
              isHidden ? LucideIcons.eyeOff100 : LucideIcons.eye100,
              color: colors.textDim,
            ),
            tooltip: isHidden ? 'Oeffentlich' : 'Privat',
            onPressed: () {
              ref
                  .read(hiddenProjectsProvider.notifier)
                  .toggle(widget.project.folderId);
            },
          ),
        ),
      ],
    );
  }

}
