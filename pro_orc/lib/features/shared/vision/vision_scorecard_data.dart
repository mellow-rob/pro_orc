import 'package:pro_orc/data/models/roadmap_data.dart';
import 'package:pro_orc/data/services/status_normalizer.dart';

/// The four real counts the Vision tab's scorecard renders (FR-004):
/// milestones done, milestones active, features total, features done.
///
/// Derived from the already-loaded [RoadmapData] (tier-0 `docs/product/`
/// milestones + nested phases/features) rather than re-reading
/// `index.json` — the Wave 1 brief prefers computing in the widget layer
/// since the counts are fully derivable from data the Roadmap tab already
/// loads.
class VisionScorecardData {
  final int milestonesDone;
  final int milestonesActive;
  final int featuresTotal;
  final int featuresDone;

  const VisionScorecardData({
    required this.milestonesDone,
    required this.milestonesActive,
    required this.featuresTotal,
    required this.featuresDone,
  });

  /// Computes counts from [data]'s milestones (each [RoadmapMilestone]'s
  /// nested `phases` list represents that milestone's features, per
  /// `ProductStoreRoadmapRepository`'s milestone->phase adaptation).
  factory VisionScorecardData.fromRoadmapData(RoadmapData data) {
    var milestonesDone = 0;
    var milestonesActive = 0;
    var featuresTotal = 0;
    var featuresDone = 0;

    for (final milestone in data.milestones) {
      final status = deriveDisplayStatus(milestone.status);
      if (status == DisplayStatus.done) {
        milestonesDone++;
      } else if (status == DisplayStatus.building) {
        milestonesActive++;
      }

      for (final feature in milestone.phases) {
        featuresTotal++;
        if (deriveDisplayStatus(feature.status) == DisplayStatus.done) {
          featuresDone++;
        }
      }
    }

    return VisionScorecardData(
      milestonesDone: milestonesDone,
      milestonesActive: milestonesActive,
      featuresTotal: featuresTotal,
      featuresDone: featuresDone,
    );
  }
}
