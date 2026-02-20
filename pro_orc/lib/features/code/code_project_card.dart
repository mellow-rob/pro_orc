import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/shared/status_badge.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/providers/hidden_projects_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Card widget for a single code project.
///
/// Renders: name + version, status badge, progress bar, next step,
/// description, and quick action buttons (Terminal, Finder, GitHub, Notion).
///
/// Hover adds a subtle cyan glow. Right-click shows Ausblenden/Einblenden
/// context menu (locked decision). Eye icon in title row does the same toggle.
class CodeProjectCard extends ConsumerStatefulWidget {
  const CodeProjectCard({
    super.key,
    required this.project,
    this.onTap,
    this.isHiddenCard = false,
  });

  final ProjectModel project;

  /// Optional tap callback — wired in Plan 03 (project detail panel).
  final VoidCallback? onTap;

  /// When true, the card is rendered with reduced opacity to indicate it's hidden.
  final bool isHiddenCard;

  @override
  ConsumerState<CodeProjectCard> createState() => _CodeProjectCardState();
}

class _CodeProjectCardState extends ConsumerState<CodeProjectCard> {
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
        onSecondaryTapUp: (details) => _showContextMenu(context, details, isHidden),
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
                        color: colors.cyan.withValues(alpha: 0.15),
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
        const SizedBox(height: 8),

        // --- Status badge row ---
        _buildStatusRow(colors),
        const SizedBox(height: 10),

        // --- Progress bar (conditional) ---
        if (widget.project.gsd?.phaseProgress != null) ...[
          _buildProgressBar(colors, widget.project.gsd!.phaseProgress!),
          const SizedBox(height: 10),
        ],

        // --- Next step (conditional) ---
        if (widget.project.gsd?.nextStep != null) ...[
          _buildNextStep(colors, widget.project.gsd!.nextStep!),
          const SizedBox(height: 8),
        ],

        // --- Description (conditional) ---
        if (widget.project.description != null) ...[
          Text(
            widget.project.description!,
            style: TextStyle(color: colors.textSec, fontSize: 12),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
        ],

        const Spacer(),

        // --- Quick action buttons ---
        _buildQuickActions(colors),
      ],
    );
  }

  Widget _buildTitleRow(AppColors colors, bool isHidden) {
    final version = widget.project.gsd?.version;
    return Row(
      children: [
        Icon(Icons.code, color: colors.cyan, size: 16),
        const SizedBox(width: 6),
        Expanded(
          child: Row(
            children: [
              Flexible(
                child: Text(
                  widget.project.displayName,
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (version != null) ...[
                const SizedBox(width: 6),
                Text(
                  version,
                  style: TextStyle(color: colors.textSec, fontSize: 11),
                ),
              ],
            ],
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
              isHidden ? Icons.visibility_off : Icons.visibility,
              color: colors.textDim,
            ),
            tooltip: isHidden ? 'Einblenden' : 'Ausblenden',
            onPressed: () {
              ref.read(hiddenProjectsProvider.notifier).toggle(widget.project.folderId);
            },
          ),
        ),
      ],
    );
  }

  Widget _buildStatusRow(AppColors colors) {
    return Row(
      children: [
        GsdStatusBadge(status: widget.project.gsd?.status),
        if (widget.project.hasParseError) ...[
          const SizedBox(width: 8),
          Tooltip(
            message: 'Parse error',
            child: Icon(Icons.warning_amber, color: const Color(0xFFF59E0B), size: 14),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressBar(AppColors colors, int progress) {
    final clampedProgress = progress.clamp(0, 100);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              color: colors.bgElev,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: clampedProgress / 100.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.cyan,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          '$clampedProgress%',
          style: TextStyle(color: colors.textSec, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildNextStep(AppColors colors, String nextStep) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Next:',
          style: TextStyle(color: colors.textSec, fontSize: 11),
        ),
        const SizedBox(height: 2),
        Text(
          nextStep,
          style: TextStyle(color: colors.textPri, fontSize: 13),
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  Widget _buildQuickActions(AppColors colors) {
    final qa = ref.read(quickActionsProvider);
    final project = widget.project;

    // Action definitions — extensible list pattern
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.terminal,
        tooltip: 'Terminal',
        onPressed: () => qa.openInTerminal(project.path),
      ),
      _QuickAction(
        icon: Icons.folder_open,
        tooltip: 'Finder',
        onPressed: () => qa.openInFinder(project.path),
      ),
      if (project.git?.githubUrl != null)
        _QuickAction(
          icon: Icons.open_in_new,
          tooltip: 'GitHub',
          onPressed: () => qa.openUrl(project.git!.githubUrl!),
        ),
      if (project.gsd?.notionUrl != null)
        _QuickAction(
          icon: Icons.description_outlined,
          tooltip: 'Notion',
          onPressed: () => qa.openUrl(project.gsd!.notionUrl!),
        ),
    ];

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: actions
          .map(
            (a) => SizedBox(
              width: 32,
              height: 32,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                icon: Icon(a.icon, color: colors.textDim),
                tooltip: a.tooltip,
                splashRadius: 16,
                onPressed: a.onPressed,
              ),
            ),
          )
          .toList(),
    );
  }

  void _showContextMenu(
    BuildContext context,
    TapUpDetails details,
    bool isHidden,
  ) {
    final overlay = Overlay.of(context).context.findRenderObject() as RenderBox;
    showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        details.globalPosition.dx,
        details.globalPosition.dy,
        overlay.size.width - details.globalPosition.dx,
        overlay.size.height - details.globalPosition.dy,
      ),
      items: [
        PopupMenuItem(
          value: 'toggle_hidden',
          child: Text(isHidden ? 'Einblenden' : 'Ausblenden'),
        ),
      ],
    ).then((value) {
      if (value == 'toggle_hidden') {
        ref.read(hiddenProjectsProvider.notifier).toggle(widget.project.folderId);
      }
    });
  }
}

/// Internal action definition for the quick action button list.
class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;
}
