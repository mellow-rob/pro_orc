import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'package:pro_orc/data/models/session_data.dart';
import 'package:pro_orc/features/shared/detail/section_card.dart';
import 'package:pro_orc/providers/session_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Renders the "TOKEN-NUTZUNG" scorecard for [ProjectDetailPanel]'s
/// Übersicht tab (FR-004, FR-005, FR-007) — replaces the removed raw
/// sessions list with a compact, always-visible summary.
///
/// Reuses the existing all-time token aggregation already computed by
/// [ProjectSessionData.estimatedTotalTokens] (`session_data.dart:166-170`) —
/// no token math is reimplemented here. Aggregation covers ALL sessions of
/// the project (all-time, no time-window filter, per FR-007), so this reads
/// [projectSessionsProvider] directly rather than the `recentFive`-scoped
/// `projectTokenEstimateProvider`.
class TokenScorecardSection extends ConsumerWidget {
  const TokenScorecardSection({
    super.key,
    required this.projectPath,
    required this.colors,
    required this.accent,
  });

  final String projectPath;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionsAsync = ref.watch(projectSessionsProvider(projectPath));

    return SectionCard(
      colors: colors,
      accent: accent,
      title: 'TOKEN-NUTZUNG',
      child: sessionsAsync.when(
        data: (sessionData) => _buildContent(sessionData),
        loading: () => _LoadingState(colors: colors),
        error: (_, _) => _EmptyState(colors: colors),
      ),
    );
  }

  Widget _buildContent(ProjectSessionData sessionData) {
    final total = sessionData.estimatedTotalTokens;

    // FR-005: no session carried any usage data at all → explicit "keine
    // Daten" state, never zero values and never a collapsed SizedBox.
    if (total == null) {
      return _EmptyState(colors: colors);
    }

    final inputTotal = _sumField(sessionData.sessions, (s) => s.inputTokens);
    final outputTotal = _sumField(sessionData.sessions, (s) => s.outputTokens);
    final cacheTotal = _sumField(sessionData.sessions, (s) => s.cacheTokens);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _StatTile(
              icon: LucideIcons.arrowDownToLine100,
              label: 'Input',
              value: formatTokenCount(inputTotal),
              colors: colors,
              accent: accent,
            ),
            _StatTile(
              icon: LucideIcons.arrowUpFromLine100,
              label: 'Output',
              value: formatTokenCount(outputTotal),
              colors: colors,
              accent: accent,
            ),
            _StatTile(
              icon: LucideIcons.database100,
              label: 'Cache',
              value: formatTokenCount(cacheTotal),
              colors: colors,
              accent: accent,
            ),
            _StatTile(
              icon: LucideIcons.messageSquare100,
              label: 'Sessions',
              value: '${sessionData.sessions.length}',
              colors: colors,
              accent: accent,
            ),
          ],
        ),
        const SizedBox(height: 10),
        _LastActivityRow(sessionData: sessionData, colors: colors),
      ],
    );
  }

  /// Sums a nullable-int field across sessions that have any token estimate
  /// at all (treating a missing individual field as 0) — mirrors
  /// [SessionInfo.totalTokens]'s null-as-zero convention.
  int _sumField(
    List<SessionInfo> sessions,
    int? Function(SessionInfo) selector,
  ) {
    return sessions
        .where((s) => s.hasTokenEstimate)
        .fold<int>(0, (sum, s) => sum + (selector(s) ?? 0));
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.colors,
    required this.accent,
  });

  final IconData icon;
  final String label;
  final String value;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minWidth: 88),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: accent.withValues(alpha: 0.15), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(icon, color: accent, size: 12),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  color: colors.textDim,
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: colors.textPri,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _LastActivityRow extends StatelessWidget {
  const _LastActivityRow({required this.sessionData, required this.colors});

  final ProjectSessionData sessionData;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    final lastActivity = sessionData.sessions.isEmpty
        ? null
        : sessionData.sessions.first.lastActivity;

    return Row(
      children: [
        Icon(LucideIcons.clock100, color: colors.textDim, size: 12),
        const SizedBox(width: 6),
        Text(
          lastActivity == null
              ? 'Letzte Aktivitaet: —'
              : 'Letzte Aktivitaet: ${_formatDateTime(lastActivity)}',
          style: TextStyle(color: colors.textDim, fontSize: 12),
        ),
      ],
    );
  }

  String _formatDateTime(DateTime date) {
    final y = date.year.toString();
    final m = date.month.toString().padLeft(2, '0');
    final d = date.day.toString().padLeft(2, '0');
    final hh = date.hour.toString().padLeft(2, '0');
    final mm = date.minute.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm';
  }
}

/// FR-005: explicit "keine Daten" state — shown when no session in the
/// project carries any recorded token usage (`hasTokenEstimate == false` for
/// every session, i.e. `estimatedTotalTokens == null`). Deliberately NOT a
/// `SizedBox.shrink()` — the absence of data must be visible, not silent.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(LucideIcons.circleSlash100, color: colors.textDim, size: 14),
        const SizedBox(width: 8),
        Text(
          'Keine Daten zur Token-Nutzung vorhanden.',
          style: TextStyle(color: colors.textDim, fontSize: 13),
        ),
      ],
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Text(
      'Lade Token-Nutzung …',
      style: TextStyle(color: colors.textDim, fontSize: 13),
    );
  }
}
