/// Project type classification for tab routing.
enum ProjectType {
  code,
  research;

  /// Parses a string to [ProjectType], returning null for unknown values.
  static ProjectType? fromString(String? value) {
    if (value == null) return null;
    return switch (value) {
      'code' => ProjectType.code,
      'research' => ProjectType.research,
      _ => null,
    };
  }
}
