import 'package:flutter/material.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// Read-only list of specs for a selected [RoadmapPhase] (FR-004/FR-005).
///
/// Always renders as a list — even for exactly one spec — and shows an
/// explicit German empty-list message when the phase has zero specs, rather
/// than a blank pane.
class SpecList extends StatelessWidget {
  const SpecList({
    super.key,
    required this.phase,
    required this.colors,
    required this.accent,
    required this.onSpecSelected,
  });

  final RoadmapPhase phase;
  final AppColors colors;
  final Color accent;
  final ValueChanged<RoadmapSpecRef> onSpecSelected;

  @override
  Widget build(BuildContext context) {
    if (phase.specs.isEmpty) {
      return Center(
        child: Text(
          'Keine Specs fuer diese Phase vorhanden',
          style: TextStyle(color: colors.textDim, fontSize: 12),
          textAlign: TextAlign.center,
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: 4),
      itemCount: phase.specs.length,
      itemBuilder: (context, index) {
        final spec = phase.specs[index];
        return InkWell(
          onTap: () => onSpecSelected(spec),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
            child: Row(
              children: [
                Icon(Icons.description_outlined, size: 14, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    spec.title,
                    style: TextStyle(color: colors.textPri, fontSize: 12),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
