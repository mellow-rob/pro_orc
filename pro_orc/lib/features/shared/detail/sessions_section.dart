import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pro_orc/data/models/session_data.dart';
import 'package:pro_orc/features/shared/detail/section_card.dart';
import 'package:pro_orc/providers/session_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Renders the "SESSIONS" section for [ProjectDetailPanel] — a token
/// summary plus the five most recent sessions, each expandable in place.
/// Renders nothing while loading, on error, or when there are no sessions.
class SessionsSection extends ConsumerWidget {
  const SessionsSection({
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

    return sessionsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (data) {
        if (data.sessions.isEmpty) return const SizedBox.shrink();

        return SectionCard(
          colors: colors,
          accent: accent,
          title: 'SESSIONS',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SessionsTokenSummary(
                projectPath: projectPath,
                colors: colors,
                accent: accent,
              ),
              for (int i = 0; i < data.recentFive.length; i++) ...[
                _SessionRow(
                  session: data.recentFive[i],
                  colors: colors,
                  accent: accent,
                ),
                if (i < data.recentFive.length - 1)
                  Divider(
                    height: 1,
                    color: colors.bgElev.withValues(alpha: 0.8),
                  ),
              ],
            ],
          ),
        );
      },
    );
  }
}

/// Expandable row showing a single session: active/inactive dot, id, and
/// last-activity timestamp. Tapping expands to a deep-dive (model, invoked
/// skills, spawned subagents, last-activity preview), which is parsed lazily
/// via [sessionDetailProvider] only on first expand (AD-1). Read-only.
class _SessionRow extends ConsumerStatefulWidget {
  const _SessionRow({
    required this.session,
    required this.colors,
    required this.accent,
  });

  final SessionInfo session;
  final AppColors colors;
  final Color accent;

  @override
  ConsumerState<_SessionRow> createState() => _SessionRowState();
}

class _SessionRowState extends ConsumerState<_SessionRow> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final colors = widget.colors;
    final statusColor = session.isActive ? colors.emerald : colors.textDim;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: statusColor,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      session.id,
                      style: TextStyle(
                        color: colors.textPri,
                        fontSize: 12,
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    session.isActive
                        ? 'Aktiv'
                        : _formatSessionTime(session.lastActivity),
                    style: TextStyle(
                      color: session.isActive ? colors.emerald : colors.textDim,
                      fontSize: 11,
                      fontWeight: session.isActive
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _expanded
                        ? LucideIcons.chevronUp100
                        : LucideIcons.chevronDown100,
                    color: colors.textDim,
                    size: 14,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (_expanded) _buildDetail(),
      ],
    );
  }

  Widget _buildDetail() {
    final detailAsync = ref.watch(sessionDetailProvider(widget.session));
    final colors = widget.colors;

    return Padding(
      padding: const EdgeInsets.only(left: 17, bottom: 8),
      child: detailAsync.when(
        loading: () => _detailHint('Lade Details…'),
        error: (_, _) => _detailHint('Nicht lesbar'),
        data: (detail) => _SessionDetailBody(
          detail: detail,
          colors: colors,
          accent: widget.accent,
        ),
      ),
    );
  }

  Widget _detailHint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Text(
        text,
        style: TextStyle(color: widget.colors.textDim, fontSize: 11),
      ),
    );
  }

  String _formatSessionTime(DateTime dt) {
    final d = dt.day.toString().padLeft(2, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    return '$d.$m. $hh:$mm';
  }
}

/// Compact per-project token estimate summed over the recent sessions shown
/// (M7 AD-4). Explicitly labelled "ca." — it is an estimate parsed from the
/// session logs' `usage` fields, not a billed figure, and carries no euro
/// amount. Renders nothing while loading, on error, or when no estimate
/// exists.
class _SessionsTokenSummary extends ConsumerWidget {
  const _SessionsTokenSummary({
    required this.projectPath,
    required this.colors,
    required this.accent,
  });

  final String projectPath;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final estimateAsync = ref.watch(projectTokenEstimateProvider(projectPath));

    return estimateAsync.maybeWhen(
      data: (total) {
        if (total == null || total <= 0) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              Icon(LucideIcons.coins100, color: colors.textDim, size: 13),
              const SizedBox(width: 8),
              Text(
                'ca. ${formatTokenCount(total)} Tokens',
                style: TextStyle(color: colors.textSec, fontSize: 12),
              ),
              const SizedBox(width: 6),
              Text(
                '(Schätzung, letzte 5 Sessions)',
                style: TextStyle(color: colors.textDim, fontSize: 11),
              ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

/// Body of an expanded session row: model, skills, subagents, last activity.
class _SessionDetailBody extends StatelessWidget {
  const _SessionDetailBody({
    required this.detail,
    required this.colors,
    required this.accent,
  });

  final SessionInfo detail;
  final AppColors colors;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[];

    if (detail.model != null) {
      rows.add(_metaRow('Modell', detail.model!));
    }
    if (detail.messageCount != null) {
      rows.add(_metaRow('Nachrichten', '${detail.messageCount}'));
    }
    if (detail.hasTokenEstimate) {
      rows.add(
        _metaRow(
          'Tokens (ca.)',
          'ca. ${formatTokenCount(detail.totalTokens)} '
              '(${formatTokenCount(detail.inputTokens ?? 0)} in / '
              '${formatTokenCount(detail.outputTokens ?? 0)} out)',
        ),
      );
    }
    if (detail.skills.isNotEmpty) {
      rows.add(_chipRow('Skills', detail.skills, LucideIcons.sparkles100));
    }
    if (detail.subagents.isNotEmpty) {
      rows.add(_chipRow('Subagents', detail.subagents, LucideIcons.bot100));
    }
    if (detail.lastActivityText != null) {
      rows.add(_metaRow('Letzte Aktivität', detail.lastActivityText!));
    }

    if (rows.isEmpty) {
      return Text(
        'Keine Details verfügbar',
        style: TextStyle(color: colors.textDim, fontSize: 11),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (int i = 0; i < rows.length; i++) ...[
          rows[i],
          if (i < rows.length - 1) const SizedBox(height: 6),
        ],
      ],
    );
  }

  Widget _metaRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: colors.textDim, fontSize: 11),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(color: colors.textPri, fontSize: 11),
          ),
        ),
      ],
    );
  }

  Widget _chipRow(String label, List<String> items, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 96,
          child: Text(
            label,
            style: TextStyle(color: colors.textDim, fontSize: 11),
          ),
        ),
        Expanded(
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final item in items)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: accent.withValues(alpha: 0.15),
                      width: 0.5,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, color: accent, size: 11),
                      const SizedBox(width: 5),
                      Text(item, style: TextStyle(color: accent, fontSize: 11)),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
