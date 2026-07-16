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
import 'package:pro_orc/theme/n3_typography.dart';

/// The "Vision" tab (mockup pane `#vision`, FR-001/FR-003/FR-004): now the
/// first and always-present tab, absorbing the former "Übersicht" content.
///
/// When [visionProvider] resolves a non-null [VisionData] (FR-003), renders
/// in order: product version badge → hero → pillars → scorecard → the
/// former-Übersicht content ([legacyContent], reused verbatim). When it
/// resolves `null` (no `docs/product/VISION.md`, FR-006), renders ONLY
/// [legacyContent] — the same legacy-guard behavior the old "Übersicht" tab
/// provided, just under the new tab name/position. The links section moved
/// to its own top-level "Links" tab (feature 005) and is no longer rendered
/// here.
class VisionTab extends ConsumerWidget {
  const VisionTab({
    super.key,
    required this.project,
    required this.legacyContent,
  });

  final ProjectModel project;

  /// The former "Übersicht" tab body — project description, files, token
  /// scorecard, git links, quick actions. Built by [ProjectDetailPanel] and
  /// passed in so this widget never reimplements it (FR-003).
  final Widget legacyContent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = Theme.of(context).extension<AppColors>()!;
    final visionAsync = ref.watch(visionProvider(project));
    final roadmapAsync = ref.watch(roadmapProvider(project));

    return visionAsync.when(
      loading: () => Center(
        child: CircularProgressIndicator(color: colors.cyan, strokeWidth: 2),
      ),
      error: (_, _) => SingleChildScrollView(child: legacyContent),
      data: (vision) {
        if (vision == null) {
          // FR-006: no vision data — legacy guard, former-Übersicht content
          // only, no hero/pillars/scorecard/links.
          return SingleChildScrollView(child: legacyContent);
        }

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
              if (vision.version != null) ...[
                _VersionBadge(version: vision.version!, colors: colors),
                const SizedBox(height: 18),
              ],
              VisionHero(
                vision: vision,
                projectName: project.displayName,
                scorecard: scorecard,
                totalMilestones: roadmapData.milestones.length,
                colors: colors,
              ),
              const SizedBox(height: 44),
              VisionSection(vision: vision, colors: colors),
              const SizedBox(height: 30),
              VisionScorecard(data: scorecard, colors: colors),
              const SizedBox(height: 44),
              Container(
                height: 1,
                color: colors.textPri.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 32),
              legacyContent,
            ],
          ),
        );
      },
    );
  }
}

/// The compact product-version badge rendered above the hero headline
/// (FR-002), e.g. "2026.06 — Closed Beta".
class _VersionBadge extends StatelessWidget {
  const _VersionBadge({required this.version, required this.colors});

  final String version;
  final AppColors colors;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: colors.cyan.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: colors.cyan.withValues(alpha: 0.25)),
      ),
      child: Text(
        version,
        style: N3Typography.eyebrow(colors: colors, color: colors.cyan),
      ),
    );
  }
}
