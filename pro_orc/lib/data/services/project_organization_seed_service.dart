import 'dart:async';

import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';

/// One-time, idempotent seed of the three example project groups (FR-014).
///
/// "Archiv" is not created here — it already exists via `ensureSystemGroups`
/// (Wave 1) independently of this seed's flag.
class ProjectOrganizationSeedService {
  ProjectOrganizationSeedService(this._db);

  final AppDatabase _db;

  // Serializes overlapping applyIfNeeded() calls (e.g. two rapid watcher
  // events both racing the initial scan) — without this, both could read
  // the seed-applied flag as false before either writes it, producing
  // duplicate "Vodafone"/"Neural AI Produkte"/"Kundenprojekte" groups.
  static Future<bool>? _inFlight;

  static const kundenprojekteFolderIds = [
    'autohaus-elflein',
    'bungertshof',
    'feldfrisch',
    'gemeinschaftspraxis-grossmann-kaarst',
    'httpstim-korosecde',
    'koenigswinter-gaststaetten',
    'logopaedie-letmathe',
    'maison-muelhens',
    'maler-brungsde',
    'mm-hairlocationde',
    'pflegedienst-juma-kaarst',
    'sc08_website_gsd',
    'steuerberater-scheinemann',
    'tierarztpraxis-dr-nicole-kowalsky',
    'digitaltwingermany',
    'wtv',
  ];

  /// Returns `true` if this call actually performed the seed (so the caller
  /// can invalidate provider state that already loaded before the seed
  /// wrote to the DB), `false` if it was a no-op (already applied, or an
  /// overlapping call was already in flight).
  Future<bool> applyIfNeeded(List<ProjectModel> scannedProjects) async {
    // If a call is already running, wait for it instead of starting a
    // second one — closes the race where two overlapping calls both read
    // the flag as false before either writes it.
    final existing = _inFlight;
    if (existing != null) {
      await existing;
      return false;
    }

    final future = _applyIfNeeded(scannedProjects);
    _inFlight = future;
    try {
      return await future;
    } finally {
      _inFlight = null;
    }
  }

  Future<bool> _applyIfNeeded(List<ProjectModel> scannedProjects) async {
    if (await _db.isProjectOrganizationSeedApplied()) return false;

    final existing = await _db.getGroups();
    await _ensureGroup(existing, 'Vodafone');
    await _ensureGroup(existing, 'Neural AI Produkte');
    final kundenprojekteId = await _ensureGroup(existing, 'Kundenprojekte');

    final scannedByFolderId = {
      for (final project in scannedProjects) project.folderId: project,
    };
    for (final folderId in kundenprojekteFolderIds) {
      if (!scannedByFolderId.containsKey(folderId)) continue;
      await _db.setProjectGroup(folderId, kundenprojekteId);
    }

    await _db.markProjectOrganizationSeedApplied();
    return true;
  }

  Future<String> _ensureGroup(
    List<ProjectGroupsTableData> existing,
    String name,
  ) async {
    final match = existing.where((g) => g.name == name).firstOrNull;
    if (match != null) return match.id;
    return _db.createGroup(name);
  }
}
