import '../models/gsd_data.dart';

export '../models/gsd_data.dart';

class GsdParseResult {
  final GsdData gsd;
  final String? displayName;
  final String? description;
  final bool hasParseError;

  const GsdParseResult({
    required this.gsd,
    this.displayName,
    this.description,
    this.hasParseError = false,
  });
}

/// Stub — RED phase. Not yet implemented.
Future<GsdParseResult> parseGsdData(String projectPath) async {
  throw UnimplementedError('parseGsdData not yet implemented');
}
