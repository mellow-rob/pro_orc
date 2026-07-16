import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';
import 'package:pro_orc/features/shared/roadmap/roadmap_id_chip.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Tappable milestone accordion row (FR-003, mockup v2 `#roadmap .m-row`): a
/// small status dot, a mono id-chip (e.g. `m8`), the milestone title, a
/// right-aligned mono meta label ("`<n> Features`", with a `✓` suffix when
/// the milestone is done), and a chevron that rotates to reflect
/// [expanded]. Tapping toggles the accordion open/closed via [onTap].
class MilestoneLane extends StatefulWidget {
  const MilestoneLane({
    super.key,
    required this.milestone,
    required this.colors,
    required this.accent,
    required this.selected,
    required this.expanded,
    required this.onTap,
  });

  final RoadmapMilestone milestone;
  final AppColors colors;
  final Color accent;

  /// Kept for the selected-row accent border contract used by
  /// `MilestoneLanesView` — an accordion row is "selected" while its body is
  /// expanded, so callers typically pass the same value as [expanded].
  final bool selected;

  /// Whether this milestone's feature-row body is currently expanded
  /// (mockup `.m-item.open`). Drives the rotating chevron.
  final bool expanded;

  final VoidCallback onTap;

  /// Status-dot color (mockup `.st.done`/`.st.active`/`.st.planned`) — reuses
  /// the shared status vocabulary, no parallel color mapping.
  static Color statusDotColor(String rawStatus, AppColors colors) {
    return switch (deriveDisplayStatus(rawStatus)) {
      DisplayStatus.done => colors.emerald,
      DisplayStatus.building => colors.cyan,
      DisplayStatus.research => colors.fuch,
      DisplayStatus.paused => colors.amber,
      DisplayStatus.archived => colors.textDis,
      DisplayStatus.planning || null => colors.textDim,
    };
  }

  /// Mockup `.mmeta` label: "`<n> Features`" for a milestone with features,
  /// with a trailing `✓` when the milestone itself is done; "—" for a
  /// milestone with zero features (matching the mockup's `m10` placeholder
  /// row).
  static String metaLabel(RoadmapMilestone milestone) {
    if (milestone.phases.isEmpty) return '—';
    final count = milestone.phases.length;
    final noun = count == 1 ? 'Feature' : 'Features';
    final suffix = deriveDisplayStatus(milestone.status) == DisplayStatus.done
        ? ' ✓'
        : '';
    return '$count $noun$suffix';
  }

  @override
  State<MilestoneLane> createState() => _MilestoneLaneState();
}

class _MilestoneLaneState extends State<MilestoneLane> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors;
    final milestone = widget.milestone;
    final chip = extractRoadmapIdChip(milestone.name);
    final dotColor = MilestoneLane.statusDotColor(milestone.status, colors);

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: widget.onTap,
          borderRadius: BorderRadius.circular(10),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: _hovered ? colors.bgElev : Colors.transparent,
              border: Border.all(
                color: widget.selected
                    ? widget.accent.withValues(alpha: 0.6)
                    : (_hovered
                          ? colors.textPri.withValues(alpha: 0.08)
                          : Colors.transparent),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: dotColor,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 12),
                if (chip != null) ...[
                  _MonoIdChip(label: chip, colors: colors),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    milestone.name,
                    style: TextStyle(
                      color: colors.textPri,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  MilestoneLane.metaLabel(milestone),
                  style: TextStyle(
                    fontFamily: 'monospace',
                    color: colors.textDim,
                    fontSize: 11,
                  ),
                ),
                const SizedBox(width: 8),
                AnimatedRotation(
                  turns: widget.expanded ? 0.25 : 0,
                  duration: const Duration(milliseconds: 180),
                  child: Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: widget.expanded ? widget.accent : colors.textDim,
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

/// Mono id-chip (mockup `.mchip`, e.g. `m8`) shown left of the milestone
/// title.
class _MonoIdChip extends StatelessWidget {
  const _MonoIdChip({required this.label, required this.colors});

  final String label;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: colors.bgSurf,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: colors.textPri.withValues(alpha: 0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'monospace',
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: colors.cyanLo,
        ),
      ),
    );
  }
}
