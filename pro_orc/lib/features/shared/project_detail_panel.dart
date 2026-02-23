import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_orc/data/models/phase_info.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/features/shared/status_badge.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
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
    barrierDismissible: true,
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
    final accent = project.projectType == 'research' ? colors.fuch : colors.cyan;

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
            width: 4,
            height: 48,
            decoration: BoxDecoration(
              color: accent,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 16),
          // Type icon in accent circle
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              project.projectType == 'research' ? Icons.science : Icons.code,
              color: accent,
              size: 18,
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
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
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
              icon: Icon(Icons.close, color: colors.textDim),
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
                Icon(Icons.arrow_forward_rounded, color: accent, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    gsd!.nextStep!,
                    style: TextStyle(color: colors.textPri, fontSize: 14),
                  ),
                ),
              ],
            ),
          ),

        // --- Beschreibung ---
        if (project.description != null)
          _SectionCard(
            colors: colors,
            accent: accent,
            title: 'BESCHREIBUNG',
            child: Text(
              project.description!,
              style: TextStyle(color: colors.textSec, fontSize: 14, height: 1.5),
            ),
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
                        Icon(Icons.commit, color: colors.textDim, size: 16),
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
                        icon: Icons.open_in_new,
                        label: 'GitHub',
                        accent: accent,
                        colors: colors,
                        onTap: () => qa.openUrl(git!.githubUrl!),
                      ),
                    if (gsd?.notionUrl != null)
                      _LinkChip(
                        icon: Icons.description_outlined,
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
            borderRadius: BorderRadius.circular(4),
            child: Container(
              height: 6,
              color: colors.bgSurf,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: clamped / 100.0,
                child: Container(
                  decoration: BoxDecoration(
                    color: accent,
                    borderRadius: BorderRadius.circular(4),
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
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  Widget _buildPhaseRow(AppColors colors, Color accent, PhaseInfo phase) {
    final (icon, iconColor) = switch (phase.status) {
      'complete' => (Icons.check_circle_outline, const Color(0xFF22C55E)),
      'in_progress' => (Icons.arrow_circle_right_outlined, accent),
      _ => (Icons.radio_button_unchecked, colors.textDim),
    };

    final isCurrent = phase.status == 'in_progress';

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
          Icon(icon, color: iconColor, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Phase ${phase.number}: ${phase.name}',
              style: TextStyle(
                color: isCurrent ? colors.textPri : colors.textSec,
                fontSize: 13,
                fontWeight: isCurrent ? FontWeight.w600 : FontWeight.normal,
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

  Widget _buildQuickActions(AppColors colors, Color accent, dynamic qa) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: Icons.terminal,
        label: 'Terminal',
        onPressed: () => qa.openInTerminal(project.path),
      ),
      _QuickAction(
        icon: Icons.folder_open,
        label: 'Finder',
        onPressed: () => qa.openInFinder(project.path),
      ),
      if (project.git?.githubUrl != null)
        _QuickAction(
          icon: Icons.open_in_new,
          label: 'GitHub',
          onPressed: () => qa.openUrl(project.git!.githubUrl!),
        ),
      if (project.gsd?.notionUrl != null)
        _QuickAction(
          icon: Icons.description_outlined,
          label: 'Notion',
          onPressed: () => qa.openUrl(project.gsd!.notionUrl!),
        ),
    ];

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
              color: widget.accent.withValues(alpha: 0.3),
              width: 1,
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
                      color: widget.accent.withValues(alpha: 0.7),
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
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
                        ? Icons.keyboard_arrow_up
                        : Icons.keyboard_arrow_down,
                    color: widget.colors.textDim,
                    size: 18,
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

/// Quick action button with icon + label.
class _QuickActionButton extends StatefulWidget {
  const _QuickActionButton({
    required this.action,
    required this.accent,
    required this.colors,
  });

  final _QuickAction action;
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
                  size: 20,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.action.label,
                  style: TextStyle(
                    color: _hovered ? widget.accent : widget.colors.textDim,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
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

/// Internal action definition for the quick action button row.
class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
}
