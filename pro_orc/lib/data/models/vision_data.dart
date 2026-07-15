/// Immutable model for a project's `docs/product/VISION.md` (FR-003/FR-010),
/// the optional vision-statement file proposed by the specforge handoff doc
/// `docs/product/HANDOFF-vision-and-gate-extension.md` (Proposal 1).
///
/// Produced only by `VisionReader`, which never throws — an absent or
/// malformed file yields `null` from the reader rather than an empty
/// [VisionData], since "no vision data" and "vision tab hidden entirely"
/// are the same outcome (FR-003).
library;

/// One vision pillar: a short, bolded name plus a one-line description,
/// parsed from a `## Pillars` bullet of the form
/// `- **<name>** — <description>.`
class VisionPillar {
  /// The bolded pillar name, e.g. `Status at a glance`.
  final String name;

  /// The description following the em-dash separator.
  final String description;

  const VisionPillar({required this.name, required this.description});
}

/// Parsed content of `docs/product/VISION.md`.
class VisionData {
  /// The `# <Title>` heading, e.g. `Pro Orc — Vision`, or null if the file
  /// has no top-level heading.
  final String? title;

  /// The lead paragraph — the first non-heading paragraph in the file
  /// (blockquote markers `>` are stripped), e.g. the one-paragraph vision
  /// statement.
  final String lead;

  /// Pillars listed under `## Pillars`, in file order.
  final List<VisionPillar> pillars;

  const VisionData({this.title, required this.lead, this.pillars = const []});
}
