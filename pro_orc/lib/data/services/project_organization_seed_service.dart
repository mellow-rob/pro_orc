import 'package:pro_orc/data/db/app_database.dart';
import 'package:pro_orc/data/models/project_model.dart';

/// One-time, idempotent seed of the three example project groups (FR-014).
///
/// "Archiv" is not created here — it already exists via `ensureSystemGroups`
/// (Wave 1) independently of this seed's flag.
class ProjectOrganizationSeedService {
  ProjectOrganizationSeedService(this._db);

  final AppDatabase _db;

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

  Future<void> applyIfNeeded(List<ProjectModel> scannedProjects) async {
    if (await _db.isProjectOrganizationSeedApplied()) return;

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
