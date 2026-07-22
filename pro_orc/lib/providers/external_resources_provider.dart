import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:pro_orc/data/models/external_resource.dart';
import 'package:pro_orc/data/models/project_model.dart';
import 'package:pro_orc/data/services/resource_detector.dart';

/// Auto-detects external resources (GitHub, Vercel, Figma, Firebase, Claude
/// Memory) for a single project, for display in the Links tab
/// (`_LinksTabBody` in `project_detail_panel.dart`).
///
/// Wraps `detectExternalResources()` — the same detector already used by the
/// delete-project dialog (`delete_project_dialog.dart`) — behind a
/// `FutureProvider.family`, mirroring `visionProvider`'s shape so
/// `_LinksTabBody` can `ref.watch(...).when(...)` both sources the same way
/// instead of the delete dialog's ad-hoc `initState` load.
final externalResourcesProvider =
    FutureProvider.family<List<ExternalResource>, ProjectModel>((
      ref,
      project,
    ) async {
      return detectExternalResources(project);
    });
