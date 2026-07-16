/// Extracts the mono-id chip text (e.g. `m8`, `m9`) from a milestone/feature
/// name, matching the mockup's `.mchip`/`.fid` convention (e.g. mockup
/// `<span class="mchip">m8</span> Project Organization`).
///
/// Milestone/feature names in this project follow the `M<n> — Title` or
/// `M<n>-slug-title` convention (see `docs/product/index.json` fixtures).
/// Returns null when no leading `M<n>` token is found — callers must render
/// no chip at all rather than an empty one, so titles without the
/// convention (e.g. legacy tiers) degrade gracefully instead of showing a
/// blank pill.
///
/// The title text itself is rendered unchanged (full `name`, prefix
/// included) alongside the chip rather than stripped — several existing
/// widget tests assert on the full milestone/feature name as a single Text
/// match (e.g. `find.text('M9 — Detail Roadmap Redesign')`), and duplicating
/// the id as a small chip in front of the unchanged title is visually
/// equivalent to the mockup without breaking that contract.
String? extractRoadmapIdChip(String name) {
  final match = RegExp(r'^\s*(M\d+)\b').firstMatch(name);
  if (match == null) return null;
  return match.group(1)!.toLowerCase();
}
