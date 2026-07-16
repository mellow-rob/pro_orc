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

/// One product link, parsed from a `## Links` bullet of the form
/// `- [<title>](<target>)`.
class VisionLink {
  /// The link's display title, e.g. `GitHub Repo`.
  final String title;

  /// The link target — either a URL or a local filesystem path.
  final String target;

  /// True when [target] starts with `http://` or `https://`; false for
  /// local filesystem paths.
  final bool isWeb;

  const VisionLink({
    required this.title,
    required this.target,
    required this.isWeb,
  });
}

/// Parsed content of `docs/product/VISION.md`.
class VisionData {
  /// The `# <Title>` heading, e.g. `Pro Orc — Vision`, or null if the file
  /// has no top-level heading.
  final String? title;

  /// The product version, parsed from the frontmatter `version:` key
  /// (e.g. `version: "2026.06 — Closed Beta"`), or null if absent or the
  /// frontmatter block itself is missing/malformed.
  final String? version;

  /// The lead paragraph — the first non-heading paragraph in the file
  /// (blockquote markers `>` are stripped), e.g. the one-paragraph vision
  /// statement.
  final String lead;

  /// Pillars listed under `## Pillars`, in file order.
  final List<VisionPillar> pillars;

  /// Links listed under `## Links`, in file order. Empty when the section
  /// is absent or has zero entries.
  final List<VisionLink> links;

  const VisionData({
    this.title,
    this.version,
    required this.lead,
    this.pillars = const [],
    this.links = const [],
  });
}
