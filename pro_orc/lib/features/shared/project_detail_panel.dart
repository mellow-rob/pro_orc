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
/// Content sections:
/// - Header: project name + version, close button
/// - Status section: GsdStatusBadge + current phase + progress bar
/// - Next step (full text, not truncated)
/// - Description (full text)
/// - Progress overview: plans completed/total
/// - Phases list (Roadmap-Uebersicht) from GsdData.phases
/// - Decisions list from GsdData.decisions
/// - Git info: last commit, GitHub link
/// - Notion link
/// - Quick actions row (Terminal, Finder, GitHub, Notion)
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
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 600,
          maxHeight: screenSize.height * 0.80,
        ),
        child: GlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header (not scrollable)
              _buildHeader(context, colors, accent),
              const Divider(height: 1, color: Color(0x20FFFFFF)),
              // Scrollable content
              Flexible(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                  child: _buildBody(context, ref, colors, accent),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppColors colors, Color accent) {
    final gsd = project.gsd;
    final version = gsd?.version;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Row(
        children: [
          Icon(
            project.projectType == 'research' ? Icons.science : Icons.code,
            color: accent,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    project.displayName,
                    style: TextStyle(
                      color: colors.textPri,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (version != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    version,
                    style: TextStyle(color: colors.textSec, fontSize: 13),
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
        // --- Status + phase ---
        if (gsd != null && !gsd.isEmpty) ...[
          Row(
            children: [
              GsdStatusBadge(status: gsd.status),
              if (gsd.currentPhase != null) ...[
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Phase ${gsd.currentPhase}',
                    style: TextStyle(color: colors.textSec, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
        ],

        // --- Progress bar (phaseProgress) ---
        if (gsd?.phaseProgress != null) ...[
          _buildProgressBar(colors, accent, gsd!.phaseProgress!),
          const SizedBox(height: 16),
        ],

        // --- Plans completed/total ---
        if (gsd?.plansCompleted != null && gsd?.plansTotal != null) ...[
          _SectionLabel(label: 'Fortschritt:', colors: colors),
          const SizedBox(height: 4),
          Text(
            'Plans: ${gsd!.plansCompleted} / ${gsd.plansTotal} abgeschlossen',
            style: TextStyle(color: colors.textPri, fontSize: 14),
          ),
          const SizedBox(height: 16),
        ],

        // --- Next step ---
        if (gsd?.nextStep != null) ...[
          _SectionLabel(label: 'Naechster Schritt:', colors: colors),
          const SizedBox(height: 4),
          Text(
            gsd!.nextStep!,
            style: TextStyle(color: colors.textPri, fontSize: 14),
          ),
          const SizedBox(height: 16),
        ],

        // --- Description ---
        if (project.description != null) ...[
          _SectionLabel(label: 'Beschreibung:', colors: colors),
          const SizedBox(height: 4),
          Text(
            project.description!,
            style: TextStyle(color: colors.textPri, fontSize: 14),
          ),
          const SizedBox(height: 16),
        ],

        // --- Phases list (Roadmap-Uebersicht) ---
        if (gsd?.phases != null && gsd!.phases!.isNotEmpty) ...[
          _SectionLabel(label: 'Phasen:', colors: colors),
          const SizedBox(height: 8),
          ...gsd.phases!.map((phase) => _buildPhaseRow(colors, phase)),
          const SizedBox(height: 16),
        ],

        // --- Decisions list ---
        if (gsd?.decisions != null && gsd!.decisions!.isNotEmpty) ...[
          _SectionLabel(label: 'Decisions:', colors: colors),
          const SizedBox(height: 8),
          ...gsd.decisions!.map((d) => _buildDecisionItem(colors, d)),
          const SizedBox(height: 16),
        ],

        // --- Git info ---
        if (git != null) ...[
          _SectionLabel(label: 'Git:', colors: colors),
          const SizedBox(height: 4),
          if (git.lastCommitHash != null)
            Text(
              '${git.lastCommitHash!} — ${_formatDate(git.lastCommitDate)}',
              style: TextStyle(
                color: colors.textSec,
                fontSize: 13,
                fontFamily: 'monospace',
              ),
            ),
          if (git.githubUrl != null) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () => qa.openUrl(git.githubUrl!),
              child: Text(
                git.githubUrl!,
                style: TextStyle(
                  color: accent,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: accent,
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
        ],

        // --- Notion link ---
        if (gsd != null && gsd.notionUrl != null) ...[
          _SectionLabel(label: 'Notion:', colors: colors),
          const SizedBox(height: 4),
          GestureDetector(
            onTap: () => qa.openUrl(gsd.notionUrl!),
            child: Text(
              gsd.notionUrl!,
              style: TextStyle(
                color: accent,
                fontSize: 13,
                decoration: TextDecoration.underline,
                decorationColor: accent,
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],

        // --- Quick actions row ---
        const Divider(height: 1, color: Color(0x20FFFFFF)),
        const SizedBox(height: 12),
        _buildQuickActions(colors, accent, qa),
      ],
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
              color: colors.bgElev,
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
        const SizedBox(width: 8),
        Text(
          '$clamped%',
          style: TextStyle(color: colors.textSec, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPhaseRow(AppColors colors, PhaseInfo phase) {
    final (icon, iconColor) = switch (phase.status) {
      'complete' => (Icons.check_circle_outline, const Color(0xFF22C55E)),
      'in_progress' => (Icons.arrow_circle_right_outlined, colors.cyan),
      _ => (Icons.radio_button_unchecked, colors.textDim),
    };

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Phase ${phase.number}: ${phase.name}',
              style: TextStyle(color: colors.textPri, fontSize: 13),
            ),
          ),
          if (phase.plansTotal > 0)
            Text(
              '${phase.plansCompleted}/${phase.plansTotal} Plans',
              style: TextStyle(color: colors.textDim, fontSize: 12),
            ),
        ],
      ),
    );
  }

  Widget _buildDecisionItem(AppColors colors, String decision) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: colors.textDim,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              decision,
              style: TextStyle(color: colors.textPri, fontSize: 12),
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
      children: actions
          .map(
            (a) => SizedBox(
              width: 40,
              height: 40,
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 24,
                icon: Icon(a.icon, color: colors.textDim),
                tooltip: a.tooltip,
                onPressed: a.onPressed,
              ),
            ),
          )
          .toList(),
    );
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}

/// Small label text for detail panel sections.
class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        color: colors.textSec,
        fontSize: 12,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}

/// Internal action definition for the quick action button row.
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
