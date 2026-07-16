import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/models/vision_data.dart';
import 'package:pro_orc/data/services/vision_reader.dart';

/// Shared [VisionReader] instance (stateless, safe to reuse across all
/// projects).
final visionReaderProvider = Provider<VisionReader>((ref) => VisionReader());

/// Resolves `docs/product/VISION.md` for a single project (FR-003).
///
/// `null` means "no vision data" — [ProjectDetailPanel] uses this to decide
/// whether the Vision tab is shown at all, not just what it renders.
final visionProvider = FutureProvider.family<VisionData?, ProjectModel>((
  ref,
  project,
) async {
  final reader = ref.read(visionReaderProvider);
  return reader.read(project.path);
});
