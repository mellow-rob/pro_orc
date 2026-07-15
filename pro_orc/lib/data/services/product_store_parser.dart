import 'dart:convert';
import 'dart:developer' as developer;
import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:pro_orc/data/models/product_store_data.dart';

/// Reads a project's `docs/product/` schema-v1 layout (as scaffolded by
/// a1-specforge), strictly read-only.
///
/// No Flutter imports — pure Dart, unit-testable and isolate-safe.
/// Defensive throughout, per project convention (see `A1Reader`): missing
/// files/dirs yield [ProductStoreData.empty], malformed JSON is caught and
/// treated as empty rather than thrown — this is what lets
/// `ProductStoreRoadmapRepository` fall through to the legacy tier chain
/// (FR-009) without the caller needing to catch anything.
class ProductStoreParser {
  /// Reads `docs/product/index.json` (+ optional `NEXT.md` +
  /// `features/<id>/feature.md` existence) for [projectPath].
  ///
  /// Returns [ProductStoreData.empty] when `docs/product/` is absent, when
  /// `index.json` is missing/malformed/missing required fields, or when any
  /// other unexpected error occurs while reading.
  Future<ProductStoreData> parse(String projectPath) async {
    try {
      final productDir = Directory(p.join(projectPath, 'docs', 'product'));
      if (!await productDir.exists()) return ProductStoreData.empty;

      final indexFile = File(p.join(productDir.path, 'index.json'));
      if (!await indexFile.exists()) return ProductStoreData.empty;

      final raw = await indexFile.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return ProductStoreData.empty;

      final milestonesJson = decoded['milestones'];
      if (milestonesJson is! List) return ProductStoreData.empty;

      final milestones = <ProductStoreMilestone>[];
      for (final entry in milestonesJson) {
        final milestone = _parseMilestone(entry);
        if (milestone != null) milestones.add(milestone);
      }
      if (milestones.isEmpty) return ProductStoreData.empty;

      final featuresJson = decoded['features'];
      final features = <ProductStoreFeature>[];
      if (featuresJson is List) {
        for (final entry in featuresJson) {
          final feature = await _parseFeature(entry, productDir.path);
          if (feature != null) features.add(feature);
        }
      }

      final next = decoded['next'];

      final nextMdContent = await _readNextMd(productDir.path);

      return ProductStoreData(
        milestones: milestones,
        features: features,
        next: next is String ? next : null,
        nextMdContent: nextMdContent,
      );
    } catch (e) {
      developer.log(
        'Failed to parse product store for $projectPath: $e',
        name: 'product_store_parser',
      );
      return ProductStoreData.empty;
    }
  }

  ProductStoreMilestone? _parseMilestone(dynamic entry) {
    if (entry is! Map<String, dynamic>) return null;
    final id = entry['id'];
    final title = entry['title'];
    final status = entry['status'];
    if (id is! String || title is! String || status is! String) return null;

    return ProductStoreMilestone(
      id: id,
      title: title,
      status: status,
      target: _parseYearMonth(entry['target']),
    );
  }

  Future<ProductStoreFeature?> _parseFeature(
    dynamic entry,
    String productDirPath,
  ) async {
    if (entry is! Map<String, dynamic>) return null;
    final id = entry['id'];
    final milestoneId = entry['milestone'];
    final title = entry['title'];
    final status = entry['status'];
    if (id is! String ||
        milestoneId is! String ||
        title is! String ||
        status is! String) {
      return null;
    }

    final dependsOnJson = entry['depends_on'];
    final dependsOn = <String>[
      if (dependsOnJson is List)
        for (final d in dependsOnJson)
          if (d is String) d,
    ];

    String? featureMdPath;
    try {
      final candidate = File(
        p.join(productDirPath, 'features', id, 'feature.md'),
      );
      if (await candidate.exists()) featureMdPath = candidate.path;
    } catch (e) {
      developer.log(
        'Failed to check feature.md for $id: $e',
        name: 'product_store_parser',
      );
    }

    return ProductStoreFeature(
      id: id,
      milestoneId: milestoneId,
      title: title,
      status: status,
      stage: entry['stage'] is String ? entry['stage'] as String : null,
      dependsOn: dependsOn,
      started: _parseDate(entry['started']),
      finished: _parseDate(entry['finished']),
      specPath: entry['spec_path'] is String
          ? entry['spec_path'] as String
          : null,
      planPath: entry['plan_path'] is String
          ? entry['plan_path'] as String
          : null,
      featureMdPath: featureMdPath,
    );
  }

  Future<String?> _readNextMd(String productDirPath) async {
    try {
      final file = File(p.join(productDirPath, 'NEXT.md'));
      if (!await file.exists()) return null;
      return await file.readAsString();
    } catch (e) {
      developer.log('Failed to read NEXT.md: $e', name: 'product_store_parser');
      return null;
    }
  }

  /// Parses a `YYYY-MM-DD` date string. Returns null for null/non-string/
  /// unparseable input — never throws.
  DateTime? _parseDate(dynamic value) {
    if (value is! String) return null;
    return DateTime.tryParse(value);
  }

  /// Parses a `YYYY-MM` month string into the first day of that month.
  /// Returns null for null/non-string/unparseable input.
  static final _yearMonthPattern = RegExp(r'^(\d{4})-(\d{2})$');

  DateTime? _parseYearMonth(dynamic value) {
    if (value is! String) return null;
    final match = _yearMonthPattern.firstMatch(value);
    if (match == null) return null;
    final year = int.tryParse(match.group(1)!);
    final month = int.tryParse(match.group(2)!);
    if (year == null || month == null) return null;
    return DateTime(year, month);
  }
}
