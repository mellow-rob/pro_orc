import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/automation_data.dart';
import 'package:pro_orc/data/models/learning_data.dart';
import 'package:pro_orc/features/shell/glass_card.dart';
import 'package:pro_orc/providers/automation_provider.dart';
import 'package:pro_orc/providers/learning_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Learning tab — read-only view of the a1 self-learning loop: retro entries
/// per skill, pattern clusters awaiting synthesis, and per-project inline
/// observations. Surfaces when an `a1-evolve` synthesis run is due.
///
/// Accent color: emerald. The app never writes into the vault (AD-1..AD-3).
class LearningTab extends ConsumerWidget {
  const LearningTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final async = ref.watch(learningProvider);

    return async.when(
      loading: () =>
          Center(child: CircularProgressIndicator(color: colors.emerald)),
      error: (_, _) => Center(
        child: Text(
          'Learning-Daten nicht lesbar',
          style: TextStyle(color: colors.textSec),
        ),
      ),
      data: (data) => _buildContent(colors, data),
    );
  }

  Widget _buildContent(AppColors colors, LearningData data) {
    final accent = colors.emerald;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (data.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Text(
                'Keine Learnings gefunden.\n'
                'Erwartet unter dem Obsidian-Vault (pattern/a1-learnings/) '
                'und in .a1/phases/*/observations.jsonl der Projekte.\n'
                'Vault-Pfad in den Einstellungen konfigurierbar.',
                style: TextStyle(color: colors.textSec, fontSize: 14),
              ),
            ),
          if (!data.isEmpty) ...[
            if (data.evolveDue)
              _EvolveBanner(
                colors: colors,
                count: data.totalSinceLastSynthesis,
              ),
            if (data.evolveDue) const SizedBox(height: 20),

            // --- Retros per skill ---
            _LearningSection(
              colors: colors,
              accent: accent,
              icon: LucideIcons.brain100,
              title: 'Retros pro Skill',
              count: data.retrosPerSkill.length,
              emptyText: 'Keine Retro-Dateien im Vault gefunden',
              revealPath: data.learningsRootPath,
              children: [
                for (final r in data.retrosPerSkill)
                  _SkillRetroRow(colors: colors, accent: accent, retro: r),
              ],
            ),
            const SizedBox(height: 24),

            // --- Pattern clusters ---
            _LearningSection(
              colors: colors,
              accent: accent,
              icon: LucideIcons.gitBranch100,
              title: 'Pattern-Cluster',
              count: data.patternClusters.length,
              emptyText: 'Keine Pattern-Cluster in patterns.md',
              revealPath: data.patternsFilePath,
              children: [
                for (final cluster in data.patternClusters)
                  _ClusterRow(colors: colors, title: cluster),
              ],
            ),
            const SizedBox(height: 24),

            // --- Observations per project ---
            _LearningSection(
              colors: colors,
              accent: accent,
              icon: LucideIcons.listChecks100,
              title: 'Beobachtungen pro Projekt',
              count: data.observations.length,
              emptyText: 'Keine .a1-Beobachtungen gefunden',
              children: [
                for (final o in data.observations)
                  _ObservationRow(colors: colors, accent: accent, obs: o),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // --- Automatisierungen (best-effort, AD-3) — always shown ---
          _AutomationsSection(colors: colors),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // System actions (runInShell per project convention)
  // ---------------------------------------------------------------------------

  /// Reveals [path] in Finder (`open -R`).
  static void revealInFinder(String path) {
    Process.run('open', ['-R', path], runInShell: true);
  }

  /// Opens [absolutePath] in Obsidian via an `obsidian://open` URI, deriving the
  /// vault name from the vault root that contains the file. Falls back to
  /// revealing in Finder when the path is not inside a recognisable vault.
  static void openInObsidian(String absolutePath) {
    final uri = _obsidianUri(absolutePath);
    if (uri == null) {
      revealInFinder(absolutePath);
      return;
    }
    Process.run('open', [uri], runInShell: true);
  }

  /// Builds an `obsidian://open?vault=<name>&file=<relative>` URI. The vault
  /// name is the directory whose child is `pattern/a1-learnings` — i.e. we walk
  /// up from the file until we find the vault root. Returns null if not found.
  static String? _obsidianUri(String absolutePath) {
    // Walk up looking for the vault root (contains `pattern/a1-learnings`).
    var dir = p.dirname(absolutePath);
    while (dir != p.dirname(dir)) {
      final marker = Directory(p.join(dir, 'pattern', 'a1-learnings'));
      if (marker.existsSync()) {
        final vaultName = p.basename(dir);
        final relative = p.relative(absolutePath, from: dir);
        final vaultEnc = Uri.encodeComponent(vaultName);
        final fileEnc = Uri.encodeComponent(relative);
        return 'obsidian://open?vault=$vaultEnc&file=$fileEnc';
      }
      dir = p.dirname(dir);
    }
    return null;
  }

  /// Formats a date as `dd.MM.yyyy` (German), manually to avoid an intl dep.
  static String formatDate(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd.$mm.${d.year}';
  }
}

/// Prominent banner shown when a1-evolve is due (>= threshold retros since the
/// last synthesis).
class _EvolveBanner extends StatelessWidget {
  const _EvolveBanner({required this.colors, required this.count});

  final AppColors colors;
  final int count;

  @override
  Widget build(BuildContext context) {
    final accent = colors.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent.withValues(alpha: 0.30), width: 1),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.sparkles100, color: accent, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'a1-evolve fällig',
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$count neue Learnings seit der letzten Synthese. '
                  'Zeit für einen a1-evolve-Lauf.',
                  style: TextStyle(color: colors.textSec, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A titled glass card wrapping a list of rows, with a header count and an
/// optional "Im Finder zeigen" for the section source.
class _LearningSection extends StatelessWidget {
  const _LearningSection({
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
                  _IconAction(
                    colors: colors,
                    icon: LucideIcons.folderOpen100,
                    tooltip: 'Im Finder zeigen',
                    onTap: () => LearningTab.revealInFinder(revealPath!),
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

/// One skill's retro stats: name, entry count, last-modified date, and
/// Finder / Obsidian quick-actions.
class _SkillRetroRow extends StatelessWidget {
  const _SkillRetroRow({
    required this.colors,
    required this.accent,
    required this.retro,
  });

  final AppColors colors;
  final Color accent;
  final SkillRetro retro;

  @override
  Widget build(BuildContext context) {
    final modified = retro.lastModified;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _CountBadge(colors: colors, accent: accent, count: retro.retroCount),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  retro.skill,
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  modified == null
                      ? '${retro.retroCount} Einträge'
                      : '${retro.retroCount} Einträge · zuletzt ${LearningTab.formatDate(modified)}',
                  style: TextStyle(color: colors.textDim, fontSize: 11),
                ),
              ],
            ),
          ),
          _IconAction(
            colors: colors,
            icon: LucideIcons.folderOpen100,
            tooltip: 'Im Finder zeigen',
            onTap: () => LearningTab.revealInFinder(retro.absolutePath),
          ),
          const SizedBox(width: 8),
          _IconAction(
            colors: colors,
            icon: LucideIcons.externalLink100,
            tooltip: 'In Obsidian öffnen',
            onTap: () => LearningTab.openInObsidian(retro.absolutePath),
          ),
        ],
      ),
    );
  }
}

class _ClusterRow extends StatelessWidget {
  const _ClusterRow({required this.colors, required this.title});

  final AppColors colors;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Icon(LucideIcons.dot, color: colors.emerald, size: 12),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                color: colors.textSec,
                fontSize: 12,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ObservationRow extends StatelessWidget {
  const _ObservationRow({
    required this.colors,
    required this.accent,
    required this.obs,
  });

  final AppColors colors;
  final Color accent;
  final ProjectObservations obs;

  @override
  Widget build(BuildContext context) {
    final last = obs.lastObservation;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          _CountBadge(
            colors: colors,
            accent: accent,
            count: obs.observationCount,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  obs.project,
                  style: TextStyle(
                    color: colors.textPri,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  last == null
                      ? '${obs.observationCount} Beobachtungen'
                      : '${obs.observationCount} Beobachtungen · zuletzt ${LearningTab.formatDate(last)}',
                  style: TextStyle(color: colors.textDim, fontSize: 11),
                ),
              ],
            ),
          ),
          _IconAction(
            colors: colors,
            icon: LucideIcons.folderOpen100,
            tooltip: 'Im Finder zeigen',
            onTap: () => LearningTab.revealInFinder(obs.projectPath),
          ),
        ],
      ),
    );
  }
}

/// Small pill showing a count, tinted with the section accent.
class _CountBadge extends StatelessWidget {
  const _CountBadge({
    required this.colors,
    required this.accent,
    required this.count,
  });

  final AppColors colors;
  final Color accent;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: accent.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Best-effort automations section (AD-3): launchd agents, crontab lines and
/// harness hooks that reference Claude. Loads independently of the learnings so
/// hooks show even without a vault. Honest empty state when nothing is found.
class _AutomationsSection extends ConsumerWidget {
  const _AutomationsSection({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(automationProvider);
    final accent = colors.violet;

    final rows = async.maybeWhen(
      data: (data) => [
        for (final a in data.automations)
          _AutomationRow(colors: colors, automation: a),
      ],
      orElse: () => <Widget>[],
    );

    return _LearningSection(
      colors: colors,
      accent: accent,
      icon: LucideIcons.workflow100,
      title: 'Automatisierungen',
      count: rows.length,
      emptyText: async.isLoading
          ? 'Wird gesucht…'
          : 'Keine geplanten Workflows gefunden',
      children: rows,
    );
  }
}

class _AutomationRow extends StatelessWidget {
  const _AutomationRow({required this.colors, required this.automation});

  final AppColors colors;
  final Automation automation;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SourceBadge(colors: colors, source: automation.source),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  automation.schedule.isEmpty
                      ? automation.name
                      : '${automation.name} · ${automation.schedule}',
                  style: TextStyle(color: colors.textPri, fontSize: 13),
                ),
                if (automation.command.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    automation.command,
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
        ],
      ),
    );
  }
}

class _SourceBadge extends StatelessWidget {
  const _SourceBadge({required this.colors, required this.source});

  final AppColors colors;
  final AutomationSource source;

  @override
  Widget build(BuildContext context) {
    final color = switch (source) {
      AutomationSource.launchd => colors.cyan,
      AutomationSource.cron => colors.amber,
      AutomationSource.hook => colors.violet,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: color.withValues(alpha: 0.25), width: 0.5),
      ),
      child: Text(
        source.label,
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.colors,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final AppColors colors;
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Tooltip(
          message: tooltip,
          child: Icon(icon, color: colors.textDim, size: 15),
        ),
      ),
    );
  }
}
