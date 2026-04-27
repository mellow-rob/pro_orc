import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;
import 'package:pro_orc/data/models/phase_info.dart';
import 'package:pro_orc/data/models/phase_status.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/project_type.dart';
import 'package:pro_orc/features/agents/agent_card.dart';
import 'package:pro_orc/features/shared/claude_tool_detail_panel.dart';
import 'package:pro_orc/data/services/quick_actions_service.dart';
import 'package:pro_orc/features/shared/quick_actions.dart';
import 'package:pro_orc/features/shared/rename_project_dialog.dart';
import 'package:pro_orc/features/shared/status_badge.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/claude_tools_provider.dart';
import 'package:pro_orc/providers/database_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Opens a [ProjectDetailPanel] as a modal dialog with slide-up + fade animation.
///
/// Call this from any card's onTap callback:
/// ```dart
/// onTap: () => showProjectDetail(context, project),
/// ```
Future<void> showProjectDetail(BuildContext context, ProjectModel project) async {
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
    pageBuilder: (context, animation, secondaryAnimation) =>
        ProjectDetailPanel(project: project),
  );
}

/// Modal detail panel for a project, showing all available GSD data.
///
/// Accent color follows project type: cyan for code, fuchsia for research.
class ProjectDetailPanel extends ConsumerWidget {
  const ProjectDetailPanel({super.key, required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final screenSize = MediaQuery.of(context).size;
    final accent = project.projectType == ProjectType.research ? colors.fuch : colors.cyan;

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
              maxWidth: 700,
              maxHeight: screenSize.height * 0.85,
            ),
            child: GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _buildHeader(context, colors, accent),
                  // Scrollable content
                  Flexible(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                      child: _buildBody(context, ref, colors, accent),
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

  Widget _buildHeader(BuildContext context, AppColors colors, Color accent) {
    final gsd = project.gsd;
    final version = gsd?.version;

    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 12, 16),
      child: Row(
        children: [
          // Accent left border strip
          Container(
            width: 2,
            height: 44,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
          const SizedBox(width: 16),
          // Type icon in accent circle
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              project.projectType == ProjectType.research
                  ? LucideIcons.beaker100
                  : LucideIcons.codeXml100,
              color: accent,
              size: 16,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    project.displayName,
                    style: TextStyle(
                      color: colors.textPri,
                      fontSize: 19,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 28,
                  height: 28,
                  child: IconButton(
                    padding: EdgeInsets.zero,
                    iconSize: 14,
                    icon: Icon(LucideIcons.pencil100,
                        color: colors.textDim, size: 14),
                    tooltip: 'Umbenennen',
                    onPressed: () => showDialog<bool>(
                      context: context,
                      barrierDismissible: false,
                      builder: (_) => RenameProjectDialog(project: project),
                    ),
                  ),
                ),
                if (version != null) ...[
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      version,
                      style: TextStyle(
                        color: accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
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
              icon: Icon(LucideIcons.x100, color: colors.textDim, size: 16),
              tooltip: 'Schliessen',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    WidgetRef ref,
    AppColors colors,
    Color accent,
  ) {
    final gsd = project.gsd;
    final git = project.git;
    final qa = ref.read(quickActionsProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // --- Hero: Status + Progress ---
        if (gsd != null && !gsd.isEmpty) ...[
          _buildHeroSection(colors, accent, gsd),
          const SizedBox(height: 20),
        ],

        // --- Naechster Schritt ---
        if (gsd?.nextStep != null)
          _SectionCard(
            colors: colors,
            accent: accent,
            title: 'NAECHSTER SCHRITT',
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(LucideIcons.arrowRight100, color: accent, size: 14),
                const SizedBox(width: 8),
                Expanded(
                  child: SelectableText(
                    gsd!.nextStep!,
                    style: TextStyle(color: colors.textPri, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // --- Beschreibung ---
        if (project.description != null)
          _DescriptionSection(
            colors: colors,
            accent: accent,
            description: project.description!,
          ),

        // --- Dateien (.md Hierarchie) ---
        if (project.mdFiles != null && project.mdFiles!.isNotEmpty)
          _SectionCard(
            colors: colors,
            accent: accent,
            title: 'DATEIEN',
            child: _buildFilesSection(colors, accent),
          ),

        // --- Phasen (Roadmap) ---
        if (gsd?.phases != null && gsd!.phases!.isNotEmpty)
          _SectionCard(
            colors: colors,
            accent: accent,
            title: 'PHASEN',
            child: Column(
              children: [
                for (int i = 0; i < gsd.phases!.length; i++) ...[
                  _buildPhaseRow(colors, accent, gsd.phases![i]),
                  if (i < gsd.phases!.length - 1)
                    Divider(
                      height: 1,
                      color: colors.bgElev.withValues(alpha: 0.8),
                    ),
                ],
              ],
            ),
          ),

        // --- Agents ---
        if (project.usedAgents != null && project.usedAgents!.isNotEmpty)
          _buildAgentsSection(context, ref, colors, accent),

        // --- Decisions (collapsed by default) ---
        if (gsd?.decisions != null && gsd!.decisions!.isNotEmpty)
          _DecisionsSection(
            colors: colors,
            accent: accent,
            decisions: gsd.decisions!,
          ),

        // --- Git & Links ---
        if (git != null || (gsd != null && gsd.notionUrl != null))
          _SectionCard(
            colors: colors,
            accent: accent,
            title: 'LINKS',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (git?.lastCommitHash != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Icon(LucideIcons.gitCommitHorizontal100, color: colors.textDim, size: 14),
                        const SizedBox(width: 8),
                        Text(
                          git!.lastCommitHash!,
                          style: TextStyle(
                            color: colors.textSec,
                            fontSize: 13,
                            fontFamily: 'monospace',
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDate(git.lastCommitDate),
                          style: TextStyle(color: colors.textDim, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (git?.githubUrl != null)
                      _LinkChip(
                        icon: LucideIcons.externalLink100,
                        label: 'GitHub',
                        accent: accent,
                        colors: colors,
                        onTap: () => qa.openUrl(git!.githubUrl!),
                      ),
                    if (gsd?.notionUrl != null)
                      _LinkChip(
                        icon: LucideIcons.fileText100,
                        label: 'Notion',
                        accent: accent,
                        colors: colors,
                        onTap: () => qa.openUrl(gsd!.notionUrl!),
                      ),
                  ],
                ),
              ],
            ),
          ),

        // --- Quick Actions ---
        const SizedBox(height: 8),
        _buildQuickActions(colors, accent, qa),
      ],
    );
  }

  Widget _buildHeroSection(AppColors colors, Color accent, dynamic gsd) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.bgElev.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status badge + phase text
          Row(
            children: [
              GsdStatusBadge(status: gsd.status),
              if (gsd.currentPhase != null) ...[
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Phase ${gsd.currentPhase}',
                    style: TextStyle(color: colors.textSec, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
              // Plans counter
              if (gsd.plansCompleted != null && gsd.plansTotal != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${gsd.plansCompleted}/${gsd.plansTotal} Plans',
                    style: TextStyle(
                      color: accent,
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
          // Progress bar
          if (gsd.phaseProgress != null) ...[
            const SizedBox(height: 14),
            _buildProgressBar(colors, accent, gsd.phaseProgress!),
          ],
        ],
      ),
    );
  }

  Widget _buildProgressBar(AppColors colors, Color accent, int progress) {
    final clamped = progress.clamp(0, 100);
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: Container(
              height: 4,
              color: colors.bgSurf,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: clamped / 100.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '$clamped%',
          style: TextStyle(
            color: accent,
            fontSize: 12,
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseRow(AppColors colors, Color accent, PhaseInfo phase) {
    final (icon, iconColor) = switch (phase.status) {
      PhaseStatus.complete => (LucideIcons.circleCheck100, const Color(0xFF22C55E)),
      PhaseStatus.inProgress => (LucideIcons.circlePlay100, accent),
      PhaseStatus.notStarted => (LucideIcons.circle100, colors.textDim),
    };

    final isCurrent = phase.status == PhaseStatus.inProgress;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
      decoration: isCurrent
          ? BoxDecoration(
              color: accent.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(6),
            )
          : null,
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 15),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Phase ${phase.number}: ${phase.name}',
              style: TextStyle(
                color: isCurrent ? colors.textPri : colors.textSec,
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w500 : FontWeight.w300,
              ),
            ),
          ),
          if (phase.plansTotal > 0)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: colors.bgElev,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${phase.plansCompleted}/${phase.plansTotal}',
                style: TextStyle(color: colors.textDim, fontSize: 11),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAgentsSection(BuildContext context, WidgetRef ref, AppColors colors, Color accent) {
    final toolsAsync = ref.read(claudeToolsProvider);
    final allAgents = toolsAsync.value?.agents ?? [];

    return _SectionCard(
      colors: colors,
      accent: accent,
      title: 'AGENTS',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: project.usedAgents!.map((name) {
          final agentData = allAgents
              .where((a) => a.name == name)
              .firstOrNull;
          final chipColor = agentData != null
              ? agentAccentColor(agentData.color, colors)
              : colors.textSec;

          return GestureDetector(
            onTap: agentData != null
                ? () => showAgentDetail(context, agentData)
                : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: chipColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: chipColor.withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: chipColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    name,
                    style: TextStyle(
                      color: chipColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildFilesSection(AppColors colors, Color accent) {
    final tree = _buildFileTree(project.mdFiles!);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Root-level files (no folder wrapper)
        for (final file in tree.files)
          _MdFileRow(file: file, depth: 0, colors: colors, accent: accent),
        // Root-level subdirectories
        for (final child in tree.children.entries)
          _FolderNode(
            name: child.key,
            node: child.value,
            depth: 0,
            colors: colors,
            accent: accent,
          ),
      ],
    );
  }

  Widget _buildQuickActions(AppColors colors, Color accent, QuickActionsService qa) {
    final actions = buildProjectQuickActions(project, qa);

    return Row(
      mainAxisAlignment: MainAxisAlignment.start,
      children: actions
          .map((a) => _QuickActionButton(
                action: a,
                accent: accent,
                colors: colors,
              ))
          .toList(),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Section card wrapper — subtle container with accent top border.
class _SectionCard extends StatelessWidget {
  const _SectionCard({
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
            top: BorderSide(color: accent.withValues(alpha: 0.2), width: 0.5),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                color: accent.withValues(alpha: 0.6),
                fontSize: 10,
                fontWeight: FontWeight.w400,
                letterSpacing: 1.5,
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

/// Expandable decisions section — collapsed by default.
class _DecisionsSection extends StatefulWidget {
  const _DecisionsSection({
    required this.colors,
    required this.accent,
    required this.decisions,
  });

  final AppColors colors;
  final Color accent;
  final List<String> decisions;

  @override
  State<_DecisionsSection> createState() => _DecisionsSectionState();
}

class _DecisionsSectionState extends State<_DecisionsSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          color: widget.colors.bgSurf.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border(
            top: BorderSide(
              color: widget.accent.withValues(alpha: 0.2),
              width: 0.5,
            ),
          ),
        ),
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => setState(() => _expanded = !_expanded),
              child: Row(
                children: [
                  Text(
                    'DECISIONS',
                    style: TextStyle(
                      color: widget.accent.withValues(alpha: 0.6),
                      fontSize: 10,
                      fontWeight: FontWeight.w400,
                      letterSpacing: 1.5,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '(${widget.decisions.length})',
                    style: TextStyle(
                      color: widget.colors.textDim,
                      fontSize: 11,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    _expanded
                        ? LucideIcons.chevronUp100
                        : LucideIcons.chevronDown100,
                    color: widget.colors.textDim,
                    size: 14,
                  ),
                ],
              ),
            ),
            if (_expanded) ...[
              const SizedBox(height: 10),
              ...widget.decisions.map(
                (d) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Container(
                          width: 4,
                          height: 4,
                          decoration: BoxDecoration(
                            color: widget.colors.textDim,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          d,
                          style: TextStyle(
                            color: widget.colors.textSec,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Expandable description section — short texts always selectable,
/// long texts (>5 lines) collapsed by default with expand/collapse toggle.
class _DescriptionSection extends StatefulWidget {
  const _DescriptionSection({
    required this.colors,
    required this.accent,
    required this.description,
  });

  final AppColors colors;
  final Color accent;
  final String description;

  @override
  State<_DescriptionSection> createState() => _DescriptionSectionState();
}

class _DescriptionSectionState extends State<_DescriptionSection> {
  bool _expanded = false;

  TextStyle get _textStyle => TextStyle(
        color: widget.colors.textSec,
        fontSize: 14,
        height: 1.6,
      );

  bool _needsExpansion(double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: widget.description, style: _textStyle),
      maxLines: 5,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
    final exceeded = painter.didExceedMaxLines;
    painter.dispose();
    return exceeded;
  }

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      colors: widget.colors,
      accent: widget.accent,
      title: 'BESCHREIBUNG',
      child: LayoutBuilder(
        builder: (context, constraints) {
          final needsToggle = _needsExpansion(constraints.maxWidth);

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!needsToggle || _expanded)
                SelectableText(
                  widget.description,
                  style: _textStyle,
                )
              else
                Text(
                  widget.description,
                  style: _textStyle,
                  maxLines: 5,
                  overflow: TextOverflow.ellipsis,
                ),
              if (needsToggle)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: _ExpandToggleButton(
                    expanded: _expanded,
                    colors: widget.colors,
                    accent: widget.accent,
                    onTap: () => setState(() => _expanded = !_expanded),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}

/// Toggle button with hover effect for expand/collapse sections.
class _ExpandToggleButton extends StatefulWidget {
  const _ExpandToggleButton({
    required this.expanded,
    required this.colors,
    required this.accent,
    required this.onTap,
  });

  final bool expanded;
  final AppColors colors;
  final Color accent;
  final VoidCallback onTap;

  @override
  State<_ExpandToggleButton> createState() => _ExpandToggleButtonState();
}

class _ExpandToggleButtonState extends State<_ExpandToggleButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = _hovered ? widget.accent : widget.colors.textDim;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              widget.expanded
                  ? LucideIcons.chevronDown100
                  : LucideIcons.chevronRight100,
              color: color,
              size: 14,
            ),
            const SizedBox(width: 4),
            Text(
              widget.expanded ? 'Weniger anzeigen' : 'Mehr anzeigen',
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Styled link chip with icon.
class _LinkChip extends StatelessWidget {
  const _LinkChip({
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
          color: accent.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: accent.withValues(alpha: 0.15), width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: accent, size: 13),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: accent,
                fontSize: 12,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Quick action button with icon + label.
class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({
    required this.action,
    required this.accent,
    required this.colors,
  });

  final QuickAction action;
  final Color accent;
  final AppColors colors;

  @override
  State<_QuickActionButton> createState() => _QuickActionButtonState();
}

class _QuickActionButtonState extends State<_QuickActionButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: widget.action.onPressed,
          child: Container(
            width: 64,
            height: 52,
            decoration: BoxDecoration(
              color: _hovered
                  ? widget.accent.withValues(alpha: 0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  widget.action.icon,
                  color: _hovered ? widget.accent : widget.colors.textDim,
                  size: 18,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.action.tooltip,
                  style: TextStyle(
                    color: _hovered ? widget.accent : widget.colors.textDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w300,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tree node holding files at this directory level and child directories.
class _FileTreeNode {
  final List<MdFileInfo> files = [];
  final Map<String, _FileTreeNode> children = {};
}

/// Builds a nested tree from a flat list of [MdFileInfo].
_FileTreeNode _buildFileTree(List<MdFileInfo> files) {
  final root = _FileTreeNode();
  for (final file in files) {
    final dir = p.dirname(file.relativePath);
    if (dir == '.') {
      root.files.add(file);
    } else {
      final segments = p.split(dir);
      var node = root;
      for (final seg in segments) {
        node = node.children.putIfAbsent(seg, _FileTreeNode.new);
      }
      node.files.add(file);
    }
  }
  return root;
}

/// Collapsible folder node that renders its files and nested subfolders.
class _FolderNode extends StatefulWidget {
  const _FolderNode({
    required this.name,
    required this.node,
    required this.depth,
    required this.colors,
    required this.accent,
  });

  final String name;
  final _FileTreeNode node;
  final int depth;
  final AppColors colors;
  final Color accent;

  @override
  State<_FolderNode> createState() => _FolderNodeState();
}

class _FolderNodeState extends State<_FolderNode> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 16.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Folder header (clickable to toggle)
        GestureDetector(
          onTap: () => setState(() => _expanded = !_expanded),
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Padding(
              padding: EdgeInsets.only(left: indent),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    Icon(
                      _expanded
                          ? LucideIcons.chevronDown100
                          : LucideIcons.chevronRight100,
                      color: widget.colors.textDim,
                      size: 13,
                    ),
                    const SizedBox(width: 2),
                    Icon(
                      _expanded
                          ? LucideIcons.folderOpen100
                          : LucideIcons.folder100,
                      color: widget.colors.textDim,
                      size: 13,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      widget.name,
                      style: TextStyle(
                        color: widget.colors.textDim,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Expanded content: files then child folders
        if (_expanded) ...[
          for (final file in widget.node.files)
            _MdFileRow(
              file: file,
              depth: widget.depth + 1,
              colors: widget.colors,
              accent: widget.accent,
            ),
          for (final child in widget.node.children.entries)
            _FolderNode(
              name: child.key,
              node: child.value,
              depth: widget.depth + 1,
              colors: widget.colors,
              accent: widget.accent,
            ),
        ],
      ],
    );
  }
}

/// Clickable .md file row with hover accent and optional role label.
class _MdFileRow extends StatefulWidget {
  const _MdFileRow({
    required this.file,
    required this.depth,
    required this.colors,
    required this.accent,
  });

  final MdFileInfo file;
  final int depth;
  final AppColors colors;
  final Color accent;

  @override
  State<_MdFileRow> createState() => _MdFileRowState();
}

class _MdFileRowState extends State<_MdFileRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final indent = widget.depth * 16.0;

    return Padding(
      padding: EdgeInsets.only(left: indent + 18),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => Process.run('open', [widget.file.path], runInShell: true),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                Icon(
                  LucideIcons.fileText100,
                  color: _hovered ? widget.accent : widget.colors.textDim,
                  size: 13,
                ),
                const SizedBox(width: 6),
                Flexible(
                  child: Text(
                    widget.file.name,
                    style: TextStyle(
                      color: _hovered ? widget.accent : widget.colors.textPri,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (widget.file.role != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    widget.file.role!,
                    style: TextStyle(
                      color: widget.colors.textDim,
                      fontSize: 11,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

