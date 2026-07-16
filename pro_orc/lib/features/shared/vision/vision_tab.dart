import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/features/shared/vision/vision_hero.dart';
import 'package:pro_orc/features/shared/vision/vision_scorecard.dart';
import 'package:pro_orc/features/shared/vision/vision_scorecard_data.dart';
import 'package:pro_orc/features/shared/vision/vision_section.dart';
import 'package:pro_orc/providers/roadmap_provider.dart';
import 'package:pro_orc/providers/vision_provider.dart';
import 'package:pro_orc/theme/n3_colors.dart';

/// The "Vision" tab (mockup pane `#vision`, FR-004): hero + scorecard +
/// vision section, built from the project's `VISION.md` (via
/// [visionProvider]) plus live milestone/feature counts (via
/// [roadmapProvider]).
///
/// [ProjectDetailPanel] only shows this tab's button when [visionProvider]
/// resolves non-null (FR-003) — this widget assumes it is only ever built
/// once that data is available, so it renders a loading/empty fallback
/// defensively rather than asserting.
class VisionTab extends ConsumerWidget {
  const VisionTab({super.key, required this.project});

  final ProjectModel project;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final visionAsync = ref.watch(visionProvider(project));
    final roadmapAsync = ref.watch(roadmapProvider(project));

    return visionAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: colors.cyan, strokeWidth: 2),
      ),
      error: (_, _) => _EmptyVisionState(colors: colors),
      data: (vision) {
        if (vision == null) return _EmptyVisionState(colors: colors);

        final roadmapData = roadmapAsync.maybeWhen(
          data: (result) => result.data,
          orElse: () => RoadmapData.empty,
        );
        final scorecard = VisionScorecardData.fromRoadmapData(roadmapData);

        return SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              VisionHero(
                vision: vision,
                projectName: project.displayName,
                scorecard: scorecard,
                totalMilestones: roadmapData.milestones.length,
                colors: colors,
              ),
              const SizedBox(height: 30),
              VisionScorecard(data: scorecard, colors: colors),
              const SizedBox(height: 44),
              Container(
                height: 1,
                color: colors.textPri.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 44),
              VisionSection(vision: vision, colors: colors),
            ],
          ),
        );
      },
    );
  }
}

/// Defensive fallback — [ProjectDetailPanel] gates the Vision tab button on
/// [visionProvider] already resolving non-null data, so this should be
/// unreachable in practice, but never renders a raw error/crash if it is.
class _EmptyVisionState extends StatelessWidget {
  const _EmptyVisionState({required this.colors});

  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Keine Vision-Daten vorhanden',
        style: TextStyle(color: colors.textSec, fontSize: 14),
      ),
    );
  }
}
